-- M3 Expressive common button. Buttons morph their corners on press.
local core = require("m3.core")
local internal = require("m3.internal.button")

local merge = core.merge
local click_of, build = internal.click_of, internal.button

local M = {}

---@alias m3.ButtonKind "primary"|"secondary"|"plain"|"destructive"|"tinted"|"elevated"|"outlined"

-- Common button; seven kinds (`tinted` looks as `secondary`), five Expressive sizes, optional toggle.
---@class m3.ButtonOpts
---@field kind? m3.ButtonKind Default "secondary".
---@field size? m3.Size Default "s".
---@field shape? "round"|"square"|"toggle" Default "round"; "toggle" squares while selected, implied by `value`.
---@field label? string|Signal<string>
---@field icon? string|Signal<string> A shared icon name or a Material Symbols name.
---@field name? string Accessible name; default the label, else the icon.
---@field value? StateSignal<boolean> Makes it a toggle; a click flips it.
---@field width? number Fixed width, content centred.
---@field padding? number|table Overrides the size's horizontal padding.
---@field icon_size? number Overrides the size's icon size.
---@field icon_props? table Extra node props for the icon.
---@field props? table Extra node props for the container.
---@field radius? fun(held: Signal<boolean>, selected: Signal<boolean>?): Signal<number|table> Overrides the shape.
---@field disabled? boolean|Signal<boolean> Dimmed to 38% and inert.
---@field held? StateSignal<boolean> The pressed state; default the button's own.
---@field on_click? fun() Called after the toggle flips.
---@field [string] "no such property"

---@param id string
---@param opts m3.ButtonOpts
---@return Node
function M.button(id, opts)
    return build(id, merge(merge({}, opts), {
        kind = opts.kind or "secondary",
        selected = opts.value,
        shape = opts.shape or opts.value and "toggle" or nil,
        on_click = click_of(opts),
    }))
end

return M
