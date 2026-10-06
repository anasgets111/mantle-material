-- M3 navigation bar: three to five destinations along the bottom edge.
-- Items are selected by `item.name or index`; every `opts.value` is a state holding that key.
local theme = require("m3.theme")
local core = require("m3.core")
local nav = require("m3.internal.navigation")
local keys = require("m3.internal.keys")

local c, pick, motion = theme.c, theme.pick, theme.motion
local CLEAR = theme.CLEAR
local FADE = motion.fade
local text, icon, interactive = core.text, core.icon, core.interactive
local key_of, selected_of, indicator = nav.key_of, nav.selected_of, nav.indicator

local M = {}

-- Three to five destinations along the bottom edge.
---@class m3.NavigationBarOpts
---@field items m3.NavItem[]
---@field value StateSignal<m3.NavKey> The selected item's `name` or index.
---@field labels? boolean Default true; false is icons only.
---@field short? boolean The Expressive short bar: 64px, each destination a pill with its icon and label side by side.
---@field [string] "no such property"

---@param id string
---@param opts m3.NavigationBarOpts
---@return Node
function M.navigation_bar(id, opts)
    local short = opts.labels == false
    local value, items = opts.value, {}
    local bind = keys.roving("navbar_" .. id, #opts.items)
    for i, item in ipairs(opts.items) do
        local key = key_of(item, i)
        local active = selected_of(value, key)
        local fg = pick(active, "on_secondary_container", "on_surface_variant")
        if opts.short then
            items[i] = interactive(("navbar_%s_%d"):format(id, i), bind(i, {
                width = "fill",
                height = 56,
                radius = 28,
                background = computed({ active, theme.scheme }, function(on, s) return on and s.secondary_container or CLEAR end),
                accessible_name = item.label,
                on_click = function() value:set(key) end,
            }), c.on_surface, row {
                width = "fill",
                height = "fill",
                align_h = "center",
                align_v = "center",
                spacing = 8,
                children = { icon(item.icon, fg, 24, { filled = active }), text(item.label, fg, "label_large") },
            })
            goto continue
        end
        local kids = { indicator(("navbar_%s_%d"):format(id, i), item, active, fg, 56) }
        if not short then
            kids[2] = text(item.label, pick(active, "secondary", "on_surface_variant"), "label_medium", { align_h = "center" })
        end
        items[i] = column(bind(i, {
            width = "fill",
            spacing = 4,
            align_h = "center",
            on_click = function() value:set(key) end,
            accessible_name = item.label,
            children = kids,
        }))
        ::continue::
    end
    return row {
        width = "fill",
        height = (short or opts.short) and 64 or 80,
        spacing = opts.short and 4 or nil,
        padding = opts.short and { left = 8, right = 8, top = 4 } or { top = short and 16 or 12 },
        background = c.surface_container,
        animate = { background = FADE },
        children = items,
    }
end

return M
