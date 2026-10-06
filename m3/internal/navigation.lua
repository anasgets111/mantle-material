-- Helpers shared across the navigation components. Not public API.
local theme = require("m3.theme")
local core = require("m3.core")
local badge = require("m3.communication.badge").badge

local c, pick, motion = theme.c, theme.pick, theme.motion
local FADE, CLEAR = motion.fade, theme.CLEAR
local text, icon, interactive = core.text, core.icon, core.interactive

---A destination. It is selected by `name`, or by its position when it has none.
---@class m3.NavItem
---@field name? string Selection key and default label.
---@field label? string
---@field icon string Material Symbols name.
---@field badge? integer|Signal<integer> Count badge on the icon.
---@field count? string|Signal<string> Trailing count (pill items).

---@alias m3.NavKey string|integer

local M = {}

---@param item m3.NavItem
---@param i integer
---@return m3.NavKey
function M.key_of(item, i) return item.name or i end

---@param value StateSignal<m3.NavKey>
---@param key m3.NavKey
---@return Signal<boolean>
function M.selected_of(value, key)
    return value:map(function(v) return v == key end)
end

-- A destination's count badge, inside its pill's top-end quarter.
local function count_badge(id, count)
    return rect {
        align_h = "center",
        align_v = "start",
        margin = { top = 2 },
        translate = { x = 14 },
        hittable = false,
        children = { badge(id, { count = count }) },
    }
end

-- The 32px pill under a destination's icon: its indicator springs open from the centre, the
-- active icon fills and a badge counts.
---@param id string
---@param item m3.NavItem
---@param active Signal<boolean>
---@param fg Signal<string>
---@param width number
---@return Node
function M.indicator(id, item, active, fg, width)
    return interactive(id, { width = width, height = 32, radius = 16, align_h = "center" }, c.on_surface, rect {
        width = "fill",
        height = "fill",
        children = {
            rect {
                width = "fill",
                height = "fill",
                radius = 16,
                background = c.secondary_container,
                scale = active:map(function(on) return { x = on and 1 or 0.3, y = 1 } end),
                opacity = active:map(function(on) return on and 1 or 0 end),
                animate = { scale = motion.spatial, opacity = { duration = 120 }, background = FADE },
            },
            icon(item.icon, fg, 24, { align_h = "center", filled = active }),
            item.badge and count_badge(id .. "_badge", item.badge) or nil,
        },
    })
end

-- A horizontal item on a 56px pill: the drawer's and the expanded rail's destination.
---@param id string
---@param item m3.NavItem
---@param active Signal<boolean>
---@param on_click fun()
---@param gap number
---@return Node
function M.pill_item(id, item, active, on_click, gap)
    local fg = pick(active, "on_secondary_container", "on_surface_variant")
    local label = item.label or item.name ---@cast label string
    local kids = {
        icon(item.icon, fg, 24, { filled = active }),
        text(label, fg, "label_large", { width = "fill", wrap = "none", elide = "end" }),
    }
    -- A horizontal item shows its `badge` as the trailing count, as M3's drawer and expanded rail do.
    local count = item.count
    if not count and item.badge then
        local function show(n) return n and n > 0 and tostring(n) or "" end
        count = type(item.badge) == "userdata" and (item.badge --[[@as Signal<integer>]]):map(show) or show(item.badge)
    end
    if count then
        kids[3] = text(count, fg, "label_large")
    end
    return interactive(id, {
        width = "fill",
        height = 56,
        radius = 28,
        on_click = on_click,
        accessible_name = label,
        background = computed({ active, theme.scheme }, function(on, s) return on and s.secondary_container or CLEAR end),
    }, c.on_surface, row {
        width = "fill",
        height = "fill",
        align_v = "center",
        spacing = gap,
        padding = { left = 16, right = 24 },
        children = kids,
    })
end

-- A 32% scrim that sets the state `open` to false when pressed.
---@param open StateSignal<boolean>
---@return Node
function M.scrim(open)
    return rect {
        width = "fill",
        height = "fill",
        background = c.scrim,
        opacity = open:map(function(o) return o and 0.32 or 0 end),
        hittable = open,
        on_click = function() open:set(false) end,
        cursor = "default",
        focus_ring = false,
        animate = { opacity = { duration = 250 } },
    }
end

return M
