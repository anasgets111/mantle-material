-- Arrow-key roving across a group of controls (radio groups, segmented buttons, tabs, chips,
-- navigation items): the arrows move keyboard focus to the next item, Home and End to the ends.
-- Not public API.
local M = {}

local STEPS = {
    horizontal = { Left = -1, Right = 1 },
    vertical = { Up = -1, Down = 1 },
    both = { Left = -1, Right = 1, Up = -1, Down = 1 },
}

-- A group of `count` items named `name`. Returns `bind(i, props)`, which gives item `i`'s props a
-- `focus_target` and an `on_key` that moves focus, keeping any `on_key` the props already have.
-- opts: axis ("horizontal" default, "vertical", "both"), wrap (default true), on_move(i) (runs
-- after focus moves to item i, e.g. to select it as a radio group does).
---@param name string
---@param count integer
---@param opts? { axis?: "horizontal"|"vertical"|"both", wrap?: boolean, on_move?: fun(i: integer) }
---@return fun(i: integer, props: table): table
function M.roving(name, count, opts)
    opts = opts or {}
    local steps = STEPS[opts.axis or "horizontal"]
    local wrap = opts.wrap ~= false
    local targets = {}
    for i = 1, count do
        targets[i] = focus_target("m3_rove_" .. name .. "_" .. i)
    end
    local function go(i)
        targets[i]:request()
        if opts.on_move then
            opts.on_move(i)
        end
    end
    return function(i, props)
        local own = props.on_key
        props.focus_target = targets[i]
        props.on_key = function(key)
            local step = steps[key.name]
            if step then
                local j = i + step
                if j < 1 or j > count then
                    if not wrap then
                        return true
                    end
                    j = (j - 1) % count + 1
                end
                go(j)
                return true
            elseif key.name == "Home" or key.name == "End" then
                go(key.name == "Home" and 1 or count)
                return true
            end
            return own and own(key) or false
        end
        return props
    end
end

return M
