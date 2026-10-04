-- M3 Expressive button group: standard (press squish) and connected (single selection).
local core = require("m3.core")
local theme = require("m3.theme")
local internal = require("m3.internal.button")

local merge = core.merge
local SPRING = theme.motion.spatial_fast
local button = internal.button

local M = {}

local function standard_group(id, opts, items)
    local held = {}
    for i = 1, #items do
        held[i] = state("m3_held_" .. id .. i, false)
    end
    local kids = {}
    for i, it in ipairs(items) do
        local mine = held[i]
        -- A missing neighbour reads as this item's own held, which is false whenever one is squished.
        local squish = computed({ held[i - 1] or mine, mine, held[i + 1] or mine }, function(l, m, r)
            if m then
                return { scale = { x = 1.08, y = 1 }, origin = { x = 0.5, y = 0.5 } }
            elseif l or r then
                return { scale = { x = 0.94, y = 1 }, origin = { x = l and 1 or 0, y = 0.5 } }
            end
            return { scale = { x = 1, y = 1 }, origin = { x = 0.5, y = 0.5 } }
        end)
        kids[i] = button(id .. i, {
            kind = opts.button_kind,
            size = "m",
            label = it.label,
            icon = it.icon,
            width = 120,
            held = mine,
            on_click = it.on_click,
            props = {
                scale = squish:map(function(v) return v.scale end),
                origin = squish:map(function(v) return v.origin end),
                animate = { scale = SPRING, origin = SPRING },
            },
        })
    end
    return row { spacing = 8, children = kids }
end

local function connected_group(id, opts, items)
    local value, n, kids = opts.value or state("m3_" .. id, 1), #items, {}
    for i, it in ipairs(items) do
        kids[i] = button(id .. i, {
            kind = opts.button_kind,
            size = "m",
            label = it.label,
            icon = it.icon,
            width = 112,
            selected = value:map(function(v) return v == i end),
            on_click = function()
                value:set(i)
                if it.on_click then
                    it.on_click()
                end
            end,
            radius = function(held, sel)
                return computed({ held, sel }, function(down, on)
                    local outer, inner = 28, 8
                    if on and not down then
                        return { top_left = 28, top_right = 28, bottom_right = 28, bottom_left = 28 }
                    end
                    return {
                        top_left = i == 1 and outer or inner,
                        bottom_left = i == 1 and outer or inner,
                        top_right = i == n and outer or inner,
                        bottom_right = i == n and outer or inner,
                    }
                end)
            end,
        })
    end
    return row { spacing = 2, children = kids }
end

-- Button group. opts: kind ("standard": pressing one grows it while its neighbours squish;
-- "connected": one selection, inner corners small, the selected item fully round), button_kind
-- (the buttons' kind, default "tonal"), items ({ label, icon?, on_click? }), value (connected only:
-- state holding the selected index).
function M.button_group(id, opts)
    local o = merge({ button_kind = "tonal" }, opts)
    return (opts.kind == "connected" and connected_group or standard_group)(id, o, opts.items)
end

return M
