-- M3 badges: a dot or a count pill, and a wrapper placing one on a child's top-end corner.
local theme = require("m3.theme")
local core = require("m3.core")
local signal = require("m3.internal.common").signal

local c, FADE = theme.c, theme.motion.fade
local SPRING = theme.motion.spatial_fast
local text = core.text

local M = {}

-- A badge: a 6px dot without `count`, else a 16px pill showing the count ("999+" past 999,
-- hidden at 0). Each new count springs in from larger.
---@class m3.BadgeOpts
---@field count? number|Signal<number> Omit for the dot.
---@field [string] "no such property"

---@param id string
---@param opts? m3.BadgeOpts
---@return Node
function M.badge(id, opts)
    local count = opts and opts.count
    if not count then
        return rect {
            width = 6,
            height = 6,
            radius = 3,
            background = c.error,
            animate = { background = FADE },
        }
    end
    count = signal(id, count)
    return row {
        children = count:map(function(n)
            if n <= 0 then
                return {}
            end
            return {
                row {
                    id = id .. n,
                    height = 16,
                    min_width = 16,
                    radius = 8,
                    padding = { left = 4, right = 4 },
                    background = c.error,
                    scale = 1,
                    animate = { scale = { spring = SPRING.spring, from = 1.7 }, background = FADE },
                    children = { text(n > 999 and "999+" or tostring(n), c.on_error, "label_small", { align_h = "center" }) },
                },
            }
        end),
    }
end

-- `child` with a badge on its top-end corner, placed as M3 specifies (Material Components'
-- Widget.Material3.Badge, edge alignment) against the child's icon box: a 6px dot whose top sits on
-- the box's top and whose end meets its end; a 16px count pill 4px above the box, its start edge
-- at the box's centre. The badge is laid out, not translated, so the box holds it and no clipping
-- ancestor cuts it.
---@class m3.BadgedOpts
---@field child Node What the badge sits on, usually an `m3.icon`.
---@field count? number|Signal<number> Omit for the dot.
---@field size? number The icon box the badge is placed against. Default 24.
---@field box_top? number Where that box starts inside `child`: an `m3.icon` line box sits it at 10% of its size.
---@field [string] "no such property"

---@param id string
---@param opts m3.BadgedOpts
---@return Node
function M.badged(id, opts)
    local size = opts.size or 24
    local box_top = opts.box_top or size * 0.1
    local x, y
    if opts.count ~= nil then
        x, y = size / 2, box_top - 4
    else
        x, y = size - 6, box_top
    end
    -- Room above the child when the badge rises past its top; offsets are padding, since a
    -- stacking cell sizes to its children's boxes, not their margins.
    local room = math.max(0, -y)
    return rect {
        children = {
            rect { padding = { top = room }, children = { opts.child } },
            rect {
                padding = { left = x, top = y + room },
                hittable = false,
                children = { M.badge(id, { count = opts.count }) },
            },
        },
    }
end

return M
