-- Dividers: 1px outline_variant, full width, inset 16 at the start or middle-inset 16 at both ends.
local theme = require("m3.theme")

local c, FADE = theme.c, theme.motion.fade

local M = {}

-- `opts`: kind ("full"|"inset"|"middle"), vertical.
function M.divider(id, opts)
    opts = opts or {}
    local inset, middle = opts.kind == "inset", opts.kind == "middle"
    local rule = { id = id, background = c.outline_variant, animate = { background = FADE } }
    if opts.vertical then
        rule.width, rule.height, rule.margin = 1, "fill", { top = (inset or middle) and 16 or 0, bottom = (inset or middle) and 16 or 0 }
    else
        rule.width, rule.height, rule.margin = "fill", 1, { left = (inset or middle) and 16 or 0, right = middle and 16 or 0 }
    end
    return rect(rule)
end

return M
