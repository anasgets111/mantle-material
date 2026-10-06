-- M3 radio: a 20px ring whose 10px dot grows on a spring.
local theme = require("m3.theme")
local core = require("m3.core")
local sel = require("m3.internal.selection")
local keys = require("m3.internal.keys")

local c, pick, motion = theme.c, theme.pick, theme.motion
local interactive = core.interactive
local QUICK, get, labelled, opacity_of = sel.QUICK, sel.get, sel.labelled, sel.opacity_of
local disabled_look, enabled = sel.disabled_look, sel.enabled

local M = {}

-- A column of radio buttons; one label is chosen.
---@class m3.RadioGroupOpts
---@field options string[] Labels. Required.
---@field value? StateSignal<string> The chosen label; default own, the first option.
---@field disabled? boolean|Signal<boolean>
---@field on_change? fun(label: string)
---@field [string] "no such property"

---@param id string
---@param opts m3.RadioGroupOpts
---@return Node
function M.radio_group(id, opts)
    local value = opts.value or state("m3_radio_" .. id, opts.options[1])
    local function choose(option)
        if not get(opts.disabled) then
            value:set(option)
            if opts.on_change then
                opts.on_change(option)
            end
        end
    end
    -- The arrows move focus and choose, as a native radio group.
    local bind = keys.roving("radio_" .. id, #opts.options, { axis = "vertical", on_move = function(i) choose(opts.options[i]) end })
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
        kids[i] = labelled(interactive("radio_" .. id .. i, bind(i, {
            width = 40,
            height = 40,
            radius = 20,
            opacity = disabled_look(opts.disabled),
            hittable = enabled(opts.disabled),
            accessible_name = option,
            on_click = function() choose(option) end,
        }), pick(on, "primary", "on_surface"), ring), option)
    end
    return column { children = kids }
end

return M
