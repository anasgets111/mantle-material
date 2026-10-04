-- M3 Expressive common button. Buttons morph their corners on press.
local core = require("m3.core")
local internal = require("m3.internal.button")

local merge = core.merge
local click_of, build = internal.click_of, internal.button

local M = {}

-- Common button. opts: kind ("filled"|"tonal"|"elevated"|"outlined"|"text"), size ("xs".."xl"), shape
-- ("round"|"square"|"toggle"), label, icon, value (boolean state: makes it a toggle), width,
-- icon_props, props (extra node props), radius, held, on_click.
function M.button(id, opts)
    return build(id, merge(merge({}, opts), {
        kind = opts.kind or "filled",
        selected = opts.value,
        shape = opts.shape or opts.value and "toggle" or nil,
        on_click = click_of(opts),
    }))
end

return M
