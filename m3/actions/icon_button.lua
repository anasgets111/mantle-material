-- M3 Expressive icon button. Buttons morph their corners on press.
local core = require("m3.core")
local internal = require("m3.internal.button")

local merge, icon = core.merge, core.icon
local SIZES, pressable, paint, radius_of, click_of = internal.SIZES, internal.pressable, internal.paint, internal.radius_of, internal.click_of

local ICON_TONES = {
    standard = { fg = "on_surface_variant", on = { fg = "primary" } },
    filled = { bg = "primary", fg = "on_primary", off = { bg = "surface_container_highest", fg = "primary" } },
    tonal = { bg = "secondary_container", fg = "on_secondary_container", on = { bg = "secondary", fg = "on_secondary" } },
    outlined = { fg = "on_surface_variant", border = "outline_variant", on = { bg = "inverse_surface", fg = "inverse_on_surface" } },
}

-- Container widths per size, as narrow, default and wide.
local WIDTHS = {
    xs = { narrow = 28, default = 32, wide = 40 },
    s = { narrow = 32, default = 40, wide = 52 },
    m = { narrow = 48, default = 56, wide = 72 },
    l = { narrow = 64, default = 96, wide = 128 },
    xl = { narrow = 104, default = 136, wide = 184 },
}

local M = {}

-- Icon button, a square container of the size's height.
---@class m3.IconButtonOpts
---@field kind? "standard"|"filled"|"tonal"|"outlined" Default "standard".
---@field size? m3.Size Default "s".
---@field shape? "round"|"square"|"toggle" Default "round"; "toggle" squares while selected, implied by `value`.
---@field width? "narrow"|"default"|"wide" Container width; default "default", the square.
---@field icon string|Signal<string> Material Symbols name.
---@field name? string Accessible name; default the icon, when it is a plain name.
---@field value? StateSignal<boolean> Makes it a toggle; the glyph fills while selected.
---@field disabled? boolean|Signal<boolean> Dimmed to 38% and inert.
---@field props? table Extra node props for the container.
---@field on_click? fun() Called after the toggle flips.
---@field [string] "no such property"

---@param id string
---@param opts m3.IconButtonOpts
---@return Node
function M.icon_button(id, opts)
    local sz = SIZES[opts.size or "s"]
    local kind, selected = opts.kind or "standard", opts.value
    local held = state("m3_held_" .. id, false)
    local bg, fg, border = paint(ICON_TONES, kind, selected)
    return pressable(id, merge({
        width = WIDTHS[opts.size or "s"][opts.width or "default"],
        height = sz.h,
        accessible_name = opts.name or (type(opts.icon) == "string" and opts.icon:gsub("_", " ") or nil),
        radius = radius_of(sz, opts.shape or selected and "toggle" or nil, held, selected),
        background = bg,
        border_width = ICON_TONES[kind].border and sz.outline or 0,
        border_color = border,
        on_click = click_of(opts),
        disabled = opts.disabled,
    }, opts.props), fg, icon(opts.icon, fg, sz.ib or sz.icon, { align_h = "center", filled = selected or kind == "filled" or kind == "tonal" }), held)
end

return M
