-- M3 Expressive segmented button: one outlined pill split into equal segments.
local theme = require("m3.theme")
local core = require("m3.core")
local check = require("m3.internal.common").check

local c, FADE, CLEAR = theme.c, theme.motion.fade, theme.CLEAR
local text = core.text

local M = {}

-- One outlined pill split into equal segments; the selected one is tinted and checked. opts:
-- options (list of strings), value (state holding the selected option), width (per segment).
function M.segmented_button(id, opts)
    local value = opts.value or state("m3_" .. id, opts.options[1])
    local segments = {}
    for i, option in ipairs(opts.options) do
        local selected = value:map(function(v) return v == option end)
        local fg = theme.pick(selected, "on_secondary_container", "on_surface")
        segments[i] = core.interactive(id .. i, {
            width = opts.width,
            height = "fill",
            background = computed({ selected, theme.scheme }, function(on, scheme) return on and scheme.secondary_container or CLEAR end),
            border_width = i > 1 and { left = 1 } or 0,
            border_color = c.outline,
            on_click = function() value:set(option) end,
        }, fg, row {
            width = "fill",
            height = "fill",
            align_h = "center",
            align_v = "center",
            spacing = 8,
            children = check(selected, fg, text(option, fg, "label_large", { id = "label" })),
        })
    end
    return rect {
        height = 40,
        radius = 20,
        clip = "rounded",
        children = {
            row { height = "fill", children = segments },
            rect { width = "fill", height = "fill", radius = 20, border_width = 1, border_color = c.outline, hittable = false, animate = { border_color = FADE } },
        },
    }
end

return M
