-- M3 switch: track 52x32; the thumb grows 16 -> 24 and slides on a spring, with an optional check
-- (on) and close (off) glyph; with `icons` the off thumb is 24px too.
local theme = require("m3.theme")
local core = require("m3.core")
local sel = require("m3.internal.selection")

local c, pick, motion = theme.c, theme.pick, theme.motion
local text, icon = core.text, core.icon
local FADE = motion.fade
local get, disabled_look, enabled = sel.get, sel.disabled_look, sel.enabled

local M = {}

-- Switch; with a `label` a settings row, the text leading and the switch trailing.
---@class m3.SwitchOpts
---@field value? StateSignal<boolean> Default own, false.
---@field icons? boolean Check on the thumb when on, close when off.
---@field disabled? boolean|Signal<boolean>
---@field label? string|Signal<string> The row's title.
---@field name? string Accessible name; default the label.
---@field detail? string|Signal<string> Second line under the label.
---@field on_change? fun(on: boolean)
---@field [string] "no such property"

---@param id string
---@param opts? m3.SwitchOpts
---@return Node
function M.switch(id, opts)
    opts = opts or {}
    local value = opts.value or state("m3_sw_" .. id, false)
    local over = hover("m3_sw_" .. id)
    ---@type StateSignal<boolean>
    local pressed = state("m3_sw_press_" .. id, false)
    local function on(yes, no) return value:map(function(v) return v and yes or no end) end
    local off = opts.icons and 24 or 16
    local size = computed({ value, pressed }, function(v, p) return p and 28 or v and 24 or off end)
    local spring = motion.spatial_fast
    local function glyph(name, role, shown)
        return icon(name, c[role], 16, {
            align_h = "center",
            opacity = shown,
            scale = shown:map(function(v) return v == 1 and 1 or 0.3 end),
            animate = { opacity = FADE, scale = spring, foreground = FADE },
        })
    end
    local node = rect {
        width = 52,
        height = 32,
        radius = 16,
        hover = over,
        opacity = disabled_look(opts.disabled),
        hittable = enabled(opts.disabled),
        accessible_name = opts.name or type(opts.label) == "string" and opts.label or id,
        background = pick(value, "primary", "surface_container_highest"),
        on_drag = function(_, _, phase) pressed:set(phase ~= "end") end,
        border_width = on(0, 2),
        border_color = c.outline,
        animate = { background = FADE, border_width = FADE, border_color = FADE },
        on_click = function()
            if not get(opts.disabled) then
                value:set(not value:get())
                if opts.on_change then
                    opts.on_change(value:get())
                end
            end
        end,
        children = {
            rect {
                width = 40,
                height = 40,
                radius = 20,
                align_v = "center",
                background = pick(value, "primary", "on_surface"),
                opacity = computed({ over, pressed }, function(h, p) return p and 0.1 or h and 0.08 or 0 end),
                translate = on({ x = 16 }, { x = -4 }),
                animate = { translate = spring, opacity = { duration = 150 } },
            },
            rect {
                align_v = "center",
                width = size,
                height = size,
                radius = 14,
                background = computed({ value, over, pressed, theme.scheme }, function(v, h, p, s)
                    if h or p then
                        return v and s.primary_container or s.on_surface_variant
                    end
                    return v and s.on_primary or s.outline
                end),
                translate = computed({ value, size }, function(v, z) return { x = (v and 36 or 16) - z / 2 } end),
                animate = { width = spring, height = spring, translate = spring, background = FADE },
                children = opts.icons and {
                    glyph("check", "on_primary_container", on(1, 0)),
                    glyph("close", "surface_container_highest", on(0, 1)),
                } or {},
            },
        },
    }
    if not opts.label then
        return node
    end
    return row {
        width = "fill",
        spacing = 16,
        children = {
            column {
                width = "fill",
                spacing = 2,
                align_v = "center",
                children = { text(opts.label, c.on_surface, "body_large"), opts.detail and text(opts.detail, c.on_surface_variant, "body_medium") or nil },
            },
            node,
        },
    }
end

return M
