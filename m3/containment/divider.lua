-- Dividers: 1px outline_variant, full width, inset 16 at the start or middle-inset 16 at both ends.
local theme = require("m3.theme")
local core = require("m3.core")

local c, FADE = theme.c, theme.motion.fade

local M = {}

---@class m3.DividerOpts
---@field kind? "full"|"inset"|"middle" Default "full". Inset leaves 16px at the start, middle at both ends.
---@field inset? number Pixels trimmed from both ends; overrides `kind`.
---@field vertical? boolean A vertical rule filling its row.
---@field props? table Extra node props.
---@field [string] "no such property"

---@param id? string|m3.DividerOpts
---@param opts? m3.DividerOpts
---@return Node
function M.divider(id, opts)
    if type(id) == "table" then
        id, opts = nil, id
    end
    opts = opts or {}
    local inset, middle = opts.kind == "inset", opts.kind == "middle"
    local rule = { id = id, background = c.outline_variant, animate = { background = FADE } }
    if opts.vertical then
        rule.width, rule.height, rule.margin = 1, "fill", { top = (inset or middle) and 16 or 0, bottom = (inset or middle) and 16 or 0 }
    else
        rule.width, rule.height, rule.margin = "fill", 1, { left = (inset or middle) and 16 or 0, right = middle and 16 or 0 }
    end
    if opts.inset then
        rule.margin = opts.vertical and { top = opts.inset, bottom = opts.inset } or { left = opts.inset, right = opts.inset }
    end
    return rect(core.merge(rule, opts.props))
end

return M
