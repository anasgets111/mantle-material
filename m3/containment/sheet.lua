-- Layers. One of each at a time; the opener keeps its `opts` for the builder, since named state
-- holds only plain data. Bottom sheet, side sheet and full-window dialog share the scrim and sheet action;
-- the popover is an anchored card over a transparent scrim.
local core = require("m3.core")
local theme = require("m3.theme")
local overlay = require("m3.overlay")
local button = require("m3.actions.button").button
local divider = require("m3.containment.divider").divider
local icon_button = require("m3.actions.icon_button").icon_button
local inert = require("m3.internal.common").inert

local text, icon, interactive = core.text, core.icon, core.interactive
local c, easing = theme.c, theme.easing

local M = {}

-- A node, a table of nodes, or a function of `close` that builds either at layer-open time; always a table of nodes.
local function build(content, close)
    local made = type(content) == "function" and content(close) or content or {}
    return next(made) == nil and {} or #made > 0 and made or { made }
end

local function scrim(id, on_click, children)
    return rect {
        id = id,
        width = "fill",
        height = "fill",
        background = theme.scheme:map(function(s) return theme.alpha(s.scrim, 0.32) end),
        opacity = 1,
        on_click = on_click,
        animate = { opacity = { duration = 200, from = 0 }, exit = { duration = 200, opacity = 0 } },
        children = children,
    }
end

-- A modal layer is a scrim that closes on a tap around the sheet; a standard one (`modal = false`) is
-- the sheet alone, so the pointer reaches the content beside it. `make(id)` builds the sheet node.
local function layer_root(id, modal, on_click, make)
    if modal then
        return scrim(id, on_click, { make() })
    end
    return make(id)
end

local sheets = {}
local popover_box = geometry("m3_popover_box")
local ZERO = { x = 0, y = 0, width = 0, height = 0 }
-- not in the spec: the gap between a popover and its anchor, and the least room left to the host's edge.
local POP_GAP, POP_EDGE = 4, 8

-- Dragging the handle area moves the sheet by the pointer's offset from the press, since the
-- pointer is read in the box's own (translated) space. Release closes it past DISMISS px or on a
-- fling; a shorter release springs it back: `settle` rebuilds the sheet entering from where it was let go.
-- not in the spec: DISMISS and FLING. Lua has no event clock, so the velocity is sampled by a timer.
local DISMISS, FLING, SAMPLE_MS = 100, 0.6, 40
local sheet_dy = state("m3_sheet_dy", 0)
local settle = state("m3_sheet_settle", { n = 0, y = 0 })
local lift = sheet_dy:map(function(dy) return { y = dy or 0 } end)

local function sheet_action(item)
    return interactive("sheet_" .. item.label, { width = "fill", height = 56, on_click = function()
        overlay.close("bottom_sheet")
        if item.on_click then
            item.on_click()
        end
    end }, c.on_surface, row {
        width = "fill",
        height = "fill",
        align_v = "center",
        spacing = 16,
        padding = { left = 24, right = 24 },
        children = { icon(item.icon, c.on_surface_variant, 24), text(item.label, c.on_surface, "body_large") },
    })
end

local function bottom_sheet()
    local opts = sheets.bottom
    local start_y, speed, last, dragging = 0, 0, 0, false
    local function sample()
        if dragging then
            local dy = sheet_dy:get() or 0
            speed, last = (dy - last) / SAMPLE_MS, dy
            timer(SAMPLE_MS, sample)
        end
    end
    local handle = {
        rect { width = 32, height = 4, radius = 2, align_h = "center", margin = { top = 22, bottom = 22 }, background = c.on_surface_variant, opacity = 0.4 },
    }
    if opts.title then
        handle[2] = text(opts.title, c.on_surface, "title_large", { margin = { left = 24, bottom = 8 } })
    end
    local kids = {
        column {
            width = "fill",
            cursor = "grab",
            on_drag = function(_, pointer, phase)
                local dy = sheet_dy:get() or 0
                if phase == "start" then
                    start_y, speed, last, dragging = pointer.y, 0, dy, true
                    timer(SAMPLE_MS, sample)
                elseif phase == "move" then
                    sheet_dy:set(math.max(0, dy + pointer.y - start_y))
                else
                    dragging = false
                    if dy > DISMISS or dy > 0 and speed > FLING then
                        overlay.close("bottom_sheet")
                    elseif dy > 0 then
                        settle:set({ n = settle:get().n + 1, y = dy })
                        sheet_dy:set(0)
                    end
                end
            end,
            children = handle,
        },
    }
    for _, item in ipairs(opts.items or {}) do
        kids[#kids + 1] = sheet_action(item)
    end
    for _, node in ipairs(build(opts.content, function() overlay.close("bottom_sheet") end)) do
        kids[#kids + 1] = node
    end
    local modal = opts.modal ~= false
    return layer_root("bottom_sheet", modal, function() overlay.close("bottom_sheet") end, function(id)
        return column {
            id = id,
            width = opts.width or 640,
            align_h = "center",
            align_v = "end",
            translate = { y = 0 },
            animate = {
                translate = { duration = 500, easing = easing.emphasized_decelerate, from = { y = 520 } },
                exit = { duration = 250, easing = easing.emphasized_accelerate, translate = { y = 520 } },
            },
            children = settle:map(function(s)
                return {
                    column(inert {
                        id = "sheet_body" .. s.n,
                        width = "fill",
                        radius = { top_left = 28, top_right = 28 },
                        background = c.surface_container_low,
                        translate = lift,
                        animate = s.y > 0 and { translate = core.merge({ from = { y = s.y } }, theme.motion.spatial_fast) } or nil,
                        shadows = { { color = "#0000004D", blur = 3, offset = { y = -1 } } },
                        padding = { bottom = 16 },
                        children = kids,
                    }),
                }
            end),
        }
    end)
end

local function side_sheet()
    local opts = sheets.side
    local function close() overlay.close("side_sheet") end
    local kids = {
        row {
            width = "fill",
            align_v = "center",
            children = {
                text(opts.title or "", c.on_surface_variant, "title_large", { width = "fill" }),
                icon_button("side_close", { kind = "plain", icon = "close", on_click = close }),
            },
        },
    }
    for _, node in ipairs(build(opts.content, close)) do
        kids[#kids + 1] = node
    end
    kids[#kids + 1] = rect { width = "fill", height = "fill" }
    kids[#kids + 1] = row {
        width = "fill",
        align_h = "end",
        spacing = 8,
        children = {
            button("side_cancel", { kind = "outlined", label = opts.cancel or "Cancel", on_click = close }),
            button("side_confirm", {
                kind = "primary",
                label = opts.confirm or "Save",
                on_click = function()
                    close()
                    if opts.on_confirm then
                        opts.on_confirm()
                    end
                end,
            }),
        },
    }
    return layer_root("side_sheet", opts.modal ~= false, close, function(id)
        return column(inert {
            id = id,
            width = opts.width or 400,
            height = "fill",
            align_h = "end",
            radius = { top_left = 16, bottom_left = 16 },
            background = c.surface_container_low,
            padding = { left = 24, right = 24, top = 16, bottom = 24 },
            spacing = 16,
            translate = { x = 0 },
            shadows = { { color = "#0000004D", blur = 3, offset = { x = -1 } } },
            animate = {
                translate = { duration = 500, easing = easing.emphasized_decelerate, from = { x = (opts.width or 400) + 20 } },
                exit = { duration = 250, easing = easing.emphasized_accelerate, translate = { x = (opts.width or 400) + 20 } },
            },
            children = kids,
        })
    end)
end

local function fullscreen_dialog()
    local opts = sheets.full
    local function close() overlay.close("fullscreen_dialog") end
    local body = build(opts.content, close)
    return column(inert {
        id = "fullscreen_dialog",
        width = "fill",
        height = "fill",
        background = c.surface,
        opacity = 1,
        translate = { y = 0 },
        animate = {
            opacity = { duration = 250, from = 0 },
            translate = { duration = 400, easing = easing.emphasized_decelerate, from = { y = 48 } },
            exit = { duration = 200, easing = easing.emphasized_accelerate, opacity = 0, translate = { y = 48 } },
        },
        children = {
            row {
                width = "fill",
                height = 56,
                align_v = "center",
                spacing = 16,
                padding = { left = 8, right = 16 },
                children = {
                    icon_button("fs_close", { kind = "plain", icon = "close", on_click = close }),
                    text(opts.title or "", c.on_surface, "title_large", { width = "fill" }),
                    button("fs_confirm", {
                        kind = "primary",
                        label = opts.confirm or "Save",
                        on_click = function()
                            close()
                            if opts.on_confirm then
                                opts.on_confirm()
                            end
                        end,
                    }),
                },
            },
            divider("fs_rule"),
            column { width = 560, align_h = "center", padding = { top = 32 }, spacing = 24, children = body },
        },
    })
end

overlay.layer("bottom_sheet", bottom_sheet)
overlay.layer("side_sheet", side_sheet)
overlay.layer("fullscreen_dialog", fullscreen_dialog)

local function popover()
    local opts = sheets.popover
    if not opts or not opts.content then
        return rect { hittable = false } -- a reload cleared the open popover
    end
    local anchor, bounds, edge = opts.anchor, overlay.bounds(opts.window), opts.edge or "bottom"
    local function clamp(x, size, lo, hi) return math.max(lo + POP_EDGE, math.min(x, hi - POP_EDGE - size)) end
    return rect {
        id = "popover",
        width = "fill",
        height = "fill",
        cursor = "default",
        focus_ring = false,
        on_click = function() overlay.close("popover") end,
        animate = { exit = { duration = 100, opacity = 0 } },
        children = {
            column(core.merge({
                width = opts.width or 280,
                padding = 16,
                radius = 12,
                background = c.surface_container,
                geometry = popover_box,
                -- Placed by margin, not `translate`: pointer coordinates follow the laid-out box. It flips to the
                -- opposite side when only that has room, and slides to stay inside the host.
                margin = computed({ anchor, bounds, popover_box }, function(r, b, t)
                    r = r or ZERO
                    local w, h = t and t.width or 0, t and t.height or 0
                    local vertical = edge == "bottom" or edge == "top"
                    local before = edge == "top" or edge == "left"
                    -- The start of a span `len` long on the anchor's `before` or after side, else the other when only that fits.
                    local function place(len, from, size, lo, hi)
                        local function at(back) return back and from - POP_GAP - len or from + size + POP_GAP end
                        local first = at(before)
                        if first < lo + POP_EDGE or first + len > hi - POP_EDGE then
                            local other = at(not before)
                            if other >= lo + POP_EDGE and other + len <= hi - POP_EDGE then
                                return other
                            end
                        end
                        return first
                    end
                    if b then
                        local left, top = r.x, r.y
                        if vertical then
                            top = place(h, r.y, r.height, b.y, b.y + b.height)
                        else
                            left = place(w, r.x, r.width, b.x, b.x + b.width)
                        end
                        return { left = clamp(left, w, b.x, b.x + b.width), top = clamp(top, h, b.y, b.y + b.height) }
                    end
                    return { left = r.x, top = r.y + r.height + POP_GAP }
                end),
                on_click = function() end,
                scale = 1,
                opacity = 1,
                origin = { x = 0.5, y = 0 },
                animate = {
                    scale = { duration = 200, easing = easing.emphasized_decelerate, from = 0.9 },
                    opacity = { duration = 100, from = 0 },
                },
                children = { type(opts.content) == "function" and opts.content() or opts.content },
            }, theme.elevation[2])),
        },
    }
end
overlay.layer("popover", popover)

---@alias m3.SheetContent Node|Node[]|fun(close: fun()): Node|Node[]

---@class m3.SheetItem
---@field icon? string
---@field label string
---@field on_click? fun()
---@field [string] "no such property"

---@class m3.BottomSheetOpts
---@field title? string
---@field modal? boolean Default true: a scrim, and a tap outside closes it. `false`: a standard sheet, no scrim, the content beside it stays live (Escape or the drag handle closes it).
---@field width? number Default 640.
---@field items? m3.SheetItem[] Rows that close the sheet, then run.
---@field content? m3.SheetContent
---@field window? string The window or panel it opens over; default `core.window`.
---@field [string] "no such property"

---@param opts? m3.BottomSheetOpts
function M.open_bottom_sheet(opts)
    opts = opts or {}
    sheets.bottom = opts
    sheet_dy:set(0)
    settle:set({ n = 0, y = 0 })
    overlay.open("bottom_sheet", nil, opts.window)
end

---@class m3.PopoverOpts
---@field anchor? Signal<Rect> A `geometry(name)` signal; the popover opens beside it.
---@field at? { x: number, y: number } A point in the host's coordinates instead of `anchor`.
---@field content Node|fun(): Node A node, or a function that builds one at each opening.
---@field edge? "bottom"|"top"|"left"|"right" The side of the anchor it opens on, default "bottom"; it flips to the opposite side when only that has room, and slides to stay inside the host.
---@field width? number Default 280.
---@field window? string The window or panel it opens over; default `core.window`.
---@field [string] "no such property"

---@param opts m3.PopoverOpts
function M.open_popover(opts)
    local point = opts.at and { x = opts.at.x, y = opts.at.y, width = 0, height = 0 }
    sheets.popover = core.merge(core.merge({}, opts), { anchor = opts.anchor or (point and computed({ theme.scheme }, function() return point end)) })
    overlay.open("popover", nil, opts.window)
end

---@class m3.SideSheetOpts
---@field title? string
---@field modal? boolean Default true: a scrim, and a tap outside closes it. `false`: a standard sheet, no scrim, the content beside it stays live.
---@field content? m3.SheetContent
---@field width? number Default 400.
---@field confirm? string Default "Save".
---@field cancel? string Default "Cancel".
---@field on_confirm? fun() Runs after the sheet closes.
---@field window? string The window or panel it opens over; default `core.window`.
---@field [string] "no such property"

---@param opts? m3.SideSheetOpts
function M.open_side_sheet(opts)
    opts = opts or {}
    sheets.side = opts
    overlay.open("side_sheet", nil, opts.window)
end

---@class m3.SheetOpts
---@field content? m3.SheetContent
---@field title? string
---@field width? number Side sheet width, default 400; a bottom sheet is 640.
---@field side? "bottom"|"side" Default "bottom".
---@field window? string The window or panel it opens over; default `core.window`.
---@field [string] "no such property"

-- A bottom sheet, or with `side = "side"` a side sheet; `open_bottom_sheet` and `open_side_sheet` take the rest of each one's fields.
---@param opts m3.SheetOpts
function M.open_sheet(opts)
    if opts.side == "side" then
        M.open_side_sheet({ title = opts.title, content = opts.content, width = opts.width, window = opts.window })
    else
        M.open_bottom_sheet({ title = opts.title, content = opts.content, width = opts.width, window = opts.window })
    end
end

---@class m3.FullscreenDialogOpts
---@field title? string
---@field content? m3.SheetContent
---@field confirm? string Default "Save".
---@field on_confirm? fun() Runs after the dialog closes.
---@field window? string The window or panel it opens over; default `core.window`.
---@field [string] "no such property"

---@param opts? m3.FullscreenDialogOpts
function M.open_fullscreen_dialog(opts)
    opts = opts or {}
    sheets.full = opts
    overlay.open("fullscreen_dialog", nil, opts.window)
end

return M
