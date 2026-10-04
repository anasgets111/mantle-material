-- M3 menu: one layer under its anchor over a transparent scrim that closes it on any click outside.
-- A selected item shows a check on a tinted row. Overlay callbacks and anchors cannot live in named
-- state, so the open spec stays in a Lua local that the layer builder reads.
local theme = require("m3.theme")
local core = require("m3.core")
local overlay = require("m3.overlay")
local sel = require("m3.internal.selection")
local text_field = require("m3.text_field").text_field

local c, motion = theme.c, theme.motion
local text, icon, interactive = core.text, core.icon, core.interactive
local FADE = motion.fade
local QUICK, ZERO, tint, opacity_of = sel.QUICK, sel.ZERO, sel.tint, sel.opacity_of

local M = {}

---@type table
local menu_spec = {}
local menu_owner = state("m3_menu_owner", "")

local menu_shown = overlay.is_open("menu")


local function menu_item(i, item)
    if item.divider then
        return rect { width = "fill", height = 1, margin = { top = 8, bottom = 8 }, background = c.outline_variant }
    end
    local kids = {}
    if item.icon then
        kids[1] = icon(item.icon, c.on_surface_variant, 24)
    end
    kids[#kids + 1] = text(item.label, c.on_surface, "body_large", { width = "fill" })
    if item.selected then
        kids[#kids + 1] = icon("check", c.on_secondary_container, 24, { opacity = opacity_of(item.selected), animate = { opacity = QUICK, foreground = FADE } })
    end
    return interactive("menu_item" .. i, {
        width = "fill",
        height = 48,
        background = item.selected and tint(item.selected, "secondary_container") or nil,
        accessible_name = item.label,
        on_click = function()
            overlay.close("menu")
            if item.on_click then
                item.on_click()
            end
        end,
    }, c.on_surface, row {
        width = "fill",
        height = "fill",
        align_v = "center",
        padding = { left = 12, right = 12 },
        spacing = 12,
        children = kids,
    })
end

overlay.layer("menu", function()
    local o = menu_spec
    local width = o.width or 224
    local end_aligned = o.align == "end"
    local items = {}
    for i, item in ipairs(o.items) do
        items[i] = menu_item(i, item)
    end
    return rect {
        id = "menu",
        width = "fill",
        height = "fill",
        cursor = "default",
        focus_ring = false,
        on_click = function() overlay.close("menu") end,
        animate = { exit = { duration = 100, opacity = 0 } },
        children = {
            column {
                width = width == "anchor" and o.anchor:map(function(r) return (r or ZERO).width end) or width,
                padding = { top = 8, bottom = 8 },
                radius = 4,
                background = c.surface_container,
                shadows = theme.shadows[2],
                -- Placed by margin, not `translate`: pointer coordinates follow the laid-out box.
                margin = o.anchor:map(function(r)
                    r = r or ZERO
                    return { left = end_aligned and r.x + r.width - width or r.x, top = r.y + r.height + 2 }
                end),
                origin = { x = end_aligned and 1 or 0.5, y = 0 },
                scale = 1,
                opacity = 1,
                on_click = function() end,
                cursor = "default",
                focus_ring = false,
                animate = {
                    scale = { duration = 300, easing = theme.easing.emphasized_decelerate, from = { x = 0.9, y = 0.6 } },
                    opacity = { duration = 150, from = 0 },
                },
                children = items,
            },
        },
    }
end)

-- opts: anchor (a `geometry(name)` signal: the menu opens under it), items ({ label, icon,
-- selected (signal), on_click } or { divider = true }), width (px, or "anchor" for the anchor's
-- width; default 224), align ("start" or "end": which edge of the anchor it lines up with; "end"
-- needs a px width), id (names the opener, for `menu_open`).
function M.open_menu(opts)
    menu_spec = opts
    menu_owner:set(opts.id or "")
    overlay.open("menu")
end

-- A signal: true while the menu opened with `id` is showing.
function M.menu_open(id)
    return computed({ menu_shown, menu_owner }, function(open, owner) return open and owner == id end)
end

---------------------------------------------------------------------------------------------------
-- Exposed dropdown: a read-only text field that opens a menu of options right under it.

-- opts: label, options (strings), value (state of the chosen option), kind ("outlined" or
-- "filled"), container (colour behind an outlined field), width (default 280), on_change(option).
function M.dropdown(id, opts)
    local value = opts.value or state("m3_dd_" .. id, opts.options[1])
    local anchor = geometry("m3_dd_" .. id)
    local items = {}
    for i, option in ipairs(opts.options) do
        items[i] = {
            label = option,
            selected = value:map(function(v) return v == option end),
            on_click = function()
                value:set(option)
                if opts.on_change then
                    opts.on_change(option)
                end
            end,
        }
    end
    local owner = "dd_" .. id
    return (text_field(id, {
        kind = opts.kind,
        label = opts.label,
        container = opts.container,
        width = opts.width or 280,
        display = value,
        trailing = "arrow_drop_down",
        spin = true,
        geometry = anchor,
        active = M.menu_open(owner),
        on_click = function() M.open_menu({ id = owner, anchor = anchor, items = items, width = "anchor" }) end,
    }))
end

return M
