-- M3 navigation rail: a side rail of destinations, collapsed or expanded.
-- Items are selected by `item.name or index`; every `opts.value` is a state holding that key.
local theme = require("m3.theme")
local core = require("m3.core")
local nav = require("m3.internal.navigation")
local inert = require("m3.internal.common").inert
local icon_button = require("m3.actions.icon_button").icon_button
local fab_button = require("m3.actions.fab").fab

local c, pick, motion = theme.c, theme.pick, theme.motion
local FADE, CLEAR = motion.fade, theme.CLEAR
local text, icon, interactive = core.text, core.icon, core.interactive
local key_of, selected_of, indicator = nav.key_of, nav.selected_of, nav.indicator
local pill_item, scrim = nav.pill_item, nav.scrim

local M = {}

-- A side rail for three to seven destinations: an optional menu button and FAB, then the
-- destinations. Collapsed (96px) each is a pill with its label below; `expanded` turns the rail
-- into a 220px container of horizontal pill items and an extended FAB, the width on a spring.
---@class m3.NavFab
---@field icon string
---@field label? string Accessible name; the extended FAB of an expanded rail shows it.
---@field on_click? fun()

---@class m3.NavigationRailOpts
---@field destinations m3.NavItem[]
---@field value StateSignal<m3.NavKey> The selected destination's `name` or index.
---@field fab? m3.NavFab
---@field expanded? boolean|StateSignal<boolean> Default false.
---@field menu? boolean A button that toggles `expanded`, which must then be a state.
---@field modal? boolean A scrim over the space beside the expanded rail; pressing it collapses the rail.
---@field [string] "no such property"

---@param id string
---@param opts m3.NavigationRailOpts
---@return Node
function M.navigation_rail(id, opts)
    local expanded = opts.expanded
    if expanded == nil or type(expanded) == "boolean" then
        expanded = state("m3_rail_" .. id, expanded or false)
    end
    local fab = opts.fab
    local function build(wide)
        local kids = {}
        if opts.menu then
            kids[1] = icon_button(id .. "_menu", {
                kind = "standard",
                icon = wide and "menu_open" or "menu",
                on_click = function() expanded:set(not wide) end,
                props = wide and { margin = { left = 8 } } or { align_h = "center" },
            })
        end
        if fab and wide then
            kids[#kids + 1] = interactive(id .. "_fab", {
                height = 56,
                radius = 16,
                margin = { bottom = 36 },
                background = c.primary_container,
                on_click = fab.on_click,
                accessible_name = fab.label,
            }, c.on_primary_container, row {
                height = "fill",
                spacing = 8,
                padding = { left = 16, right = 20 },
                children = { icon(fab.icon, c.on_primary_container, 24), text(fab.label, c.on_primary_container, "label_large") },
            })
        elseif fab then
            kids[#kids + 1] = fab_button(id .. "_fab", {
                icon = fab.icon,
                on_click = fab.on_click,
                props = { align_h = "center", margin = { bottom = 36 }, accessible_name = fab.label },
            })
        end
        for i, item in ipairs(opts.destinations) do
            local key = key_of(item, i)
            local label = item.label or item.name ---@cast label string
            local active = selected_of(opts.value, key)
            local function select() opts.value:set(key) end
            if wide then
                kids[#kids + 1] = pill_item(("%s_%d"):format(id, i), item, active, select, 8)
            else
                local fg = pick(active, "on_secondary_container", "on_surface_variant")
                kids[#kids + 1] = column {
                    width = 96,
                    padding = { top = 6, bottom = 6 },
                    spacing = 4,
                    align_h = "center",
                    on_click = select,
                    accessible_name = label,
                    children = { indicator(("%s_%d"):format(id, i), item, active, fg, 56), text(label, fg, "label_medium", { align_h = "center" }) },
                }
            end
        end
        return kids
    end
    -- Both layouts are built once: a map only picks one, so it never creates nodes or signals.
    local built = { collapsed = build(false), expanded = build(true) }
    local rail = {
        width = expanded:map(function(w) return w and 220 or 96 end),
        height = "fill",
        padding = expanded:map(function(w) return w and { top = 44, left = 12, right = 12 } or { top = 44 } end),
        spacing = 4,
        background = computed({ expanded, theme.scheme }, function(w, s) return w and s.surface_container or CLEAR end),
        radius = expanded:map(function(w) return w and { top_right = 16, bottom_right = 16 } or 0 end),
        animate = { width = motion.spatial, background = FADE },
        children = expanded:map(function(w) return w and built.expanded or built.collapsed end),
    }
    if not opts.modal then
        return column(rail)
    end
    return rect { width = "fill", height = "fill", children = { scrim(expanded), column(inert(rail)) } }
end

return M
