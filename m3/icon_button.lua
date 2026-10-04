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

local M = {}

-- Icon button, square container of the size's height. opts: kind ("standard"|"filled"|"tonal"|
-- "outlined"), size, shape, icon, value (boolean state: toggle, filled glyph while selected),
-- props, on_click.
function M.icon_button(id, opts)
    local sz = SIZES[opts.size or "s"]
    local kind, selected = opts.kind or "standard", opts.value
    local held = state("m3_held_" .. id, false)
    local bg, fg, border = paint(ICON_TONES, kind, selected)
    return pressable(id, merge({
        width = sz.h,
        height = sz.h,
        radius = radius_of(sz, opts.shape or selected and "toggle" or nil, held, selected),
        background = bg,
        border_width = ICON_TONES[kind].border and sz.outline or 0,
        border_color = border,
        on_click = click_of(opts),
    }, opts.props), fg, icon(opts.icon, fg, sz.ib or sz.icon, { align_h = "center", filled = selected or kind == "filled" or kind == "tonal" }), held)
end

return M
