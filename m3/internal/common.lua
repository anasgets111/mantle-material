-- Helpers shared across component families. Not public API.
local theme = require("m3.theme")
local core = require("m3.core")

local M = {}

-- A leading check that springs in when `selected` turns on, then `label`.
function M.check(selected, fg, label)
    return selected:map(function(on)
        local kids = {}
        if on then
            kids[1] = core.icon("check", fg, 18, {
                id = "check",
                scale = 1,
                opacity = 1,
                animate = {
                    scale = core.merge({ from = 0 }, theme.motion.spatial_fast),
                    opacity = { duration = 150, from = 0 },
                    foreground = theme.motion.fade,
                },
            })
        end
        kids[#kids + 1] = label
        return kids
    end)
end

-- A number as a signal; signals pass through.
function M.signal(id, v)
    if v == nil or type(v) == "number" then
        return state("m3_" .. id, v or 0)
    end
    return v
end

-- A cover-fit image that loads off the main thread.
function M.photo(source, props)
    return image(core.merge({ source = source, async = true, fit = "cover" }, props))
end

-- Swallows clicks so only the scrim dismisses.
function M.inert(props)
    props.on_click = function() end
    props.cursor = "default"
    props.focus_ring = false
    return props
end

return M
