-- Helpers shared across selection components. Not public API.
local theme = require("m3.theme")
local core = require("m3.core")

local c, CLEAR = theme.c, theme.CLEAR
local text = core.text

local M = {}

M.DISABLED = 0.38
M.QUICK = { duration = 100 }
M.ZERO = { x = 0, y = 0, width = 0, height = 0 }

-- A plain value or a signal: `live(x, fn)` maps a signal or applies `fn` to a plain value.
local function live(x, fn)
    if type(x) == "userdata" then
        return x:map(fn)
    end
    return fn(x)
end
function M.get(x)
    if type(x) == "userdata" then
        return x:get()
    end
    return x
end

-- `role` while `flag` is on, transparent otherwise.
function M.tint(flag, role)
    return computed({ flag, theme.scheme }, function(on, s) return on and s[role] or CLEAR end)
end

function M.opacity_of(flag) return flag:map(function(v) return v and 1 or 0 end) end

function M.labelled(control, label)
    return row { spacing = 4, children = { control, text(label, c.on_surface, "body_large") } }
end

function M.disabled_look(disabled) return live(disabled, function(d) return d and M.DISABLED or 1 end) end
function M.enabled(disabled) return live(disabled, function(d) return not d end) end

return M
