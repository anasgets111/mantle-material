-- M3 navigation bar: three to five destinations along the bottom edge.
-- Items are selected by `item.name or index`; every `opts.value` is a state holding that key.
local theme = require("m3.theme")
local core = require("m3.core")
local nav = require("m3.internal.navigation")

local c, pick, motion = theme.c, theme.pick, theme.motion
local FADE = motion.fade
local text = core.text
local key_of, selected_of, indicator = nav.key_of, nav.selected_of, nav.indicator

local M = {}

-- Three to five destinations along the bottom edge.
-- opts: items { label, icon, badge? }, value (state), labels (default true; false is icons only).
function M.navigation_bar(id, opts)
    local short = opts.labels == false
    local value, items = opts.value, {}
    for i, item in ipairs(opts.items) do
        local key = key_of(item, i)
        local active = selected_of(value, key)
        local fg = pick(active, "on_secondary_container", "on_surface_variant")
        local kids = { indicator(("navbar_%s_%d"):format(id, i), item, active, fg, 56) }
        if not short then
            kids[2] = text(item.label, pick(active, "secondary", "on_surface_variant"), "label_medium", { align_h = "center" })
        end
        items[i] = column {
            width = "fill",
            spacing = 4,
            align_h = "center",
            on_click = function() value:set(key) end,
            accessible_name = item.label,
            children = kids,
        }
    end
    return row {
        width = "fill",
        height = short and 64 or 80,
        padding = { top = short and 16 or 12 },
        background = c.surface_container,
        animate = { background = FADE },
        children = items,
    }
end

return M
