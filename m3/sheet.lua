-- Layers. One of each at a time; the opener keeps its `opts` for the builder, since named state
-- holds only plain data. Bottom sheet, side sheet and full-window dialog share the scrim and sheet action.
local core = require("m3.core")
local theme = require("m3.theme")
local overlay = require("m3.overlay")
local button = require("m3.button").button
local divider = require("m3.divider").divider
local icon_button = require("m3.icon_button").icon_button
local inert = require("m3.internal.common").inert

local text, icon, interactive = core.text, core.icon, core.interactive
local c, easing = theme.c, theme.easing

local M = {}

-- A table of nodes, or a function that builds one at layer-open time.
local function build(content)
    return type(content) == "function" and content() or content or {}
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

local sheets = {}

-- Dragging the handle area moves the sheet by the pointer's offset from the press, since the
-- pointer is read in the box's own (translated) space; past 100px, release dismisses it.
local sheet_dy = state("m3_sheet_dy", 0)

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
    local start_y = 0
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
                if phase == "start" then
                    start_y = pointer.y
                elseif phase == "move" then
                    sheet_dy:set(math.max(0, (sheet_dy:get() or 0) + pointer.y - start_y))
                elseif (sheet_dy:get() or 0) > 100 then
                    overlay.close("bottom_sheet")
                else
                    sheet_dy:set(0)
                end
            end,
            children = handle,
        },
    }
    for _, item in ipairs(opts.items or {}) do
        kids[#kids + 1] = sheet_action(item)
    end
    for _, node in ipairs(build(opts.content)) do
        kids[#kids + 1] = node
    end
    return scrim("bottom_sheet", function() overlay.close("bottom_sheet") end, {
        column {
            width = 640,
            align_h = "center",
            align_v = "end",
            translate = { y = 0 },
            animate = {
                translate = { duration = 500, easing = easing.emphasized_decelerate, from = { y = 520 } },
                exit = { duration = 250, easing = easing.emphasized_accelerate, translate = { y = 520 } },
            },
            children = {
                column(inert {
                    width = "fill",
                    radius = { top_left = 28, top_right = 28 },
                    background = c.surface_container_low,
                    translate = sheet_dy:map(function(dy) return { y = dy or 0 } end),
                    shadows = { { color = "#0000004D", blur = 3, offset = { y = -1 } } },
                    padding = { bottom = 16 },
                    children = kids,
                }),
            },
        },
    })
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
                icon_button("side_close", { kind = "standard", icon = "close", on_click = close }),
            },
        },
    }
    for _, node in ipairs(build(opts.content)) do
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
                kind = "filled",
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
    return scrim("side_sheet", close, {
        column(inert {
            width = 400,
            height = "fill",
            align_h = "end",
            radius = { top_left = 16, bottom_left = 16 },
            background = c.surface_container_low,
            padding = { left = 24, right = 24, top = 16, bottom = 24 },
            spacing = 16,
            translate = { x = 0 },
            shadows = { { color = "#0000004D", blur = 3, offset = { x = -1 } } },
            animate = {
                translate = { duration = 500, easing = easing.emphasized_decelerate, from = { x = 420 } },
                exit = { duration = 250, easing = easing.emphasized_accelerate, translate = { x = 420 } },
            },
            children = kids,
        }),
    })
end

local function fullscreen_dialog()
    local opts = sheets.full
    local function close() overlay.close("fullscreen_dialog") end
    local body = build(opts.content)
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
                    icon_button("fs_close", { kind = "standard", icon = "close", on_click = close }),
                    text(opts.title or "", c.on_surface, "title_large", { width = "fill" }),
                    button("fs_confirm", {
                        kind = "filled",
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

-- `opts`: title, items ({ icon, label, on_click } rows that close the sheet), content (nodes, or a function returning them).
function M.open_bottom_sheet(opts)
    sheets.bottom = opts or {}
    sheet_dy:set(0)
    overlay.open("bottom_sheet")
end

-- `opts`: title, content, confirm ("Save"), cancel ("Cancel"), on_confirm.
function M.open_side_sheet(opts)
    sheets.side = opts or {}
    overlay.open("side_sheet")
end

-- `opts`: title, content, confirm ("Save"), on_confirm.
function M.open_fullscreen_dialog(opts)
    sheets.full = opts or {}
    overlay.open("fullscreen_dialog")
end

return M
