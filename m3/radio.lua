-- M3 radio: a 20px ring whose 10px dot grows on a spring.
local theme = require("m3.theme")
local core = require("m3.core")
local sel = require("m3.internal.selection")

local c, pick, motion = theme.c, theme.pick, theme.motion
local interactive = core.interactive
local QUICK, get, labelled, opacity_of = sel.QUICK, sel.get, sel.labelled, sel.opacity_of
local disabled_look, enabled = sel.disabled_look, sel.enabled

local M = {}

-- opts: options (labels), value (state of the chosen label), disabled, on_change(label).
function M.radio_group(id, opts)
    local value = opts.value or state("m3_radio_" .. id, opts.options[1])
    local kids = {}
    for i, option in ipairs(opts.options) do
        local on = value:map(function(v) return v == option end)
        local ring = rect {
            width = 20,
            height = 20,
            radius = 10,
            align_h = "center",
            align_v = "center",
            border_width = 2,
            border_color = pick(on, "primary", "on_surface_variant"),
            animate = { border_color = QUICK },
            children = {
                rect {
                    width = 10,
                    height = 10,
                    radius = 5,
                    align_h = "center",
                    align_v = "center",
                    background = c.primary,
                    scale = opacity_of(on),
                    animate = { scale = motion.spatial_fast },
                },
            },
        }
        kids[i] = labelled(interactive("radio_" .. id .. i, {
            width = 40,
            height = 40,
            radius = 20,
            opacity = disabled_look(opts.disabled),
            hittable = enabled(opts.disabled),
            accessible_name = option,
            on_click = function()
                if not get(opts.disabled) then
                    value:set(option)
                    if opts.on_change then
                        opts.on_change(option)
                    end
                end
            end,
        }, pick(on, "primary", "on_surface"), ring), option)
    end
    return column { children = kids }
end

return M
