-- M3 Expressive loading indicator and the morphing shape.
local theme = require("m3.theme")
local core = require("m3.core")
local shapes = require("m3.shapes")

local c, FADE = theme.c, theme.motion.fade
local SPRING = theme.motion.spatial_fast
local merge = core.merge

local M = {}

local SEQUENCE = { "soft_burst", "cookie_9", "pentagon", "pill", "sunny", "cookie_4", "oval" }
local MORPH_MS = 650
local MORPH_SPRING = { stiffness = 200, damping = 0.6 * 2 * math.sqrt(200) }
local CYCLES = 4

-- M3 Expressive loading indicator: a 38px shape that morphs to the next every 650 ms on a
-- spring (ratio 0.6, stiffness 200), turning 90 degrees with each morph while the whole turns
-- once per 4.666 s.
---@class m3.LoadingIndicatorOpts
---@field contained? boolean Sits it on a 48px primary container circle.
---@field [string] "no such property"

---@param _ string
---@param opts? m3.LoadingIndicatorOpts
---@return Node
function M.loading_indicator(_, opts)
    local contained = opts and opts.contained
    local shapes_ = {}
    for i, name in ipairs(SEQUENCE) do
        shapes_[i] = shapes.commands(name, 38)
    end
    ---@type any[], any[]
    local morph, turn = { shapes_[1] }, { 0 }
    for i = 1, #SEQUENCE * CYCLES do
        morph[i + 1] = { value = shapes_[i % #SEQUENCE + 1], duration = MORPH_MS, spring = MORPH_SPRING }
        turn[i + 1] = { value = 90 * i, duration = MORPH_MS, spring = MORPH_SPRING }
    end
    return rect {
        width = 48,
        height = 48,
        radius = 24,
        background = contained and c.primary_container or theme.CLEAR,
        animate = { background = FADE },
        children = {
            rect {
                width = 48,
                height = 48,
                rotate = 0,
                animate = { rotate = { duration = 4666, easing = "linear", keyframes = { 0, 360 }, loops = "infinite" } },
                children = {
                    path {
                        width = 38,
                        height = 38,
                        align_h = "center",
                        align_v = "center",
                        fill = contained and c.on_primary_container or c.primary,
                        commands = morph[1],
                        rotate = 0,
                        animate = {
                            commands = { duration = MORPH_MS, easing = "linear", keyframes = morph, loops = "infinite" },
                            rotate = { duration = MORPH_MS, easing = "linear", keyframes = turn, loops = "infinite" },
                            fill = FADE,
                        },
                    },
                },
            },
        },
    }
end

-- A morphing M3 Expressive shape (see m3.shapes.NAMES). Changing `name` morphs on a spring.
---@class m3.ShapeOpts
---@field name? string|Signal<string> One of `m3.shapes.NAMES`. Default "circle".
---@field size? number Default 48.
---@field color? string|Signal<string> Default `c.primary`.
---@field props? table Extra node props.
---@field [string] "no such property"

---@param id string
---@param opts m3.ShapeOpts
---@return Node
function M.shape(id, opts)
    local size, named = opts.size or 48, opts.name
    ---@type Signal<string>
    local name
    if type(named) == "string" or named == nil then
        name = state("m3_" .. id, named or "circle")
    else
        name = named
    end
    return path(merge({
        width = size,
        height = size,
        fill = opts.color or c.primary,
        commands = name:map(function(n) return shapes.commands(n, size) end),
        animate = { commands = SPRING, fill = FADE },
    }, opts.props))
end

return M
