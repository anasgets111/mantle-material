local theme = require("m3.theme")
local core = require("m3.core")

local FADE, CLEAR = theme.motion.fade, theme.CLEAR
local SPRING = theme.motion.spatial_fast
local merge, text, icon = core.merge, core.text, core.icon

local M = {}

-- `core.interactive` plus a `held` state that is true while the pointer is down, so shapes can
-- morph on press. Press feedback is paint-only: a layout change would cancel the click.
local function pressable(name, props, ink, content, held)
    local over = hover("m3_" .. name)
    local keyed = focused("m3_focus_" .. name)
    ---@type StateSignal<table|false>
    local ripple = state("m3_ripple_" .. name, false)
    local layer = rect {
        id = "layer",
        width = "fill",
        height = "fill",
        background = ink,
        opacity = computed({ over, keyed }, function(on, kb) return kb and 0.10 or on and 0.08 or 0 end),
        animate = { opacity = { duration = 150, easing = "out_quad" } },
    }
    content.id = "content"
    props.hover = over
    props.focused = keyed
    core.disable(props)
    core.focusable(name, props)
    props.clip = "rounded"
    props.animate = merge({ background = FADE, border_color = FADE, radius = SPRING }, props.animate)
    props.on_drag = function(box, pointer, phase)
        if phase == "start" then
            local last = ripple:get()
            ripple:set({
                n = (last and last.n or 0) + 1,
                x = math.max(0, math.min(1, pointer.x / math.max(1, box.width))),
                y = math.max(0, math.min(1, pointer.y / math.max(1, box.height))),
            })
            held:set(true)
        elseif phase == "end" then
            held:set(false)
        end
    end
    props.children = ripple:map(function(p)
        local kids = { layer }
        if p then
            kids[2] = rect {
                id = "ripple" .. p.n,
                width = "fill",
                height = "fill",
                background = ink,
                origin = { x = p.x, y = p.y },
                scale = 6,
                opacity = 0,
                animate = {
                    scale = { duration = 900, easing = "out_cubic", from = 0 },
                    opacity = { duration = 900, easing = "in_quad", from = 0.14 },
                },
            }
        end
        kids[#kids + 1] = content
        return kids
    end)
    return rect(props)
end

-- Expressive sizes: container height, label type style, icon size (`ib`: the icon button's, when it
-- differs), horizontal padding, icon gap, outline width, and the corner radius of the square and
-- the pressed shape (round is half the height).
local SIZES = {
    xs = { h = 32, type = "label_large", icon = 20, pad = 12, gap = 4, outline = 1, square = 12, press = 8 },
    s = { h = 40, type = "label_large", icon = 20, ib = 24, pad = 16, gap = 8, outline = 1, square = 12, press = 8 },
    m = { h = 56, type = "title_medium", icon = 24, pad = 24, gap = 8, outline = 1, square = 16, press = 12 },
    l = { h = 96, type = "headline_small", icon = 32, pad = 48, gap = 12, outline = 2, square = 28, press = 16 },
    xl = { h = 136, type = "headline_large", icon = 40, pad = 64, gap = 16, outline = 3, square = 28, press = 16 },
}

-- Colour roles per kind. `on` / `off` override the container while a toggle is selected or not.
local BUTTON_TONES = {
    filled = { bg = "primary", fg = "on_primary", off = { bg = "surface_container_highest", fg = "on_surface_variant" } },
    tonal = { bg = "secondary_container", fg = "on_secondary_container", on = { bg = "secondary", fg = "on_secondary" } },
    elevated = { bg = "surface_container_low", fg = "primary", elevation = 1, on = { bg = "primary", fg = "on_primary" } },
    outlined = { fg = "primary", border = "outline_variant", on = { bg = "inverse_surface", fg = "inverse_on_surface" } },
    text = { fg = "primary" },
}

-- Background, foreground and border signals of `kind`; `selected` (a boolean signal) picks the
-- toggle's colours, nil leaves a plain button.
local function paint(tones, kind, selected)
    local t = tones[kind]
    local function out(field)
        local function color(scheme, on)
            local base = on == nil and t or on and (t.on or t) or (t.off or t)
            return base[field] and scheme[base[field]] or CLEAR
        end
        if selected == nil then
            return theme.scheme:map(color)
        end
        return computed({ theme.scheme, selected }, color)
    end
    return out("bg"), out("fg"), out("border")
end

-- Corner radius signal: round, or square while a toggle is selected / `shape = "square"`, and
-- the smaller pressed radius while held.
local function radius_of(sz, shape, held, selected)
    local function radius(down, on)
        if down then
            return sz.press
        end
        return (shape == "square" or on) and sz.square or sz.h / 2
    end
    if selected and shape == "toggle" then
        return computed({ held, selected }, radius)
    end
    return held:map(function(down) return radius(down, false) end)
end

-- Shared button builder; `o.selected` (boolean signal) makes it a toggle, `o.radius` is a
-- fn(held, selected) -> radius signal that overrides the shape, `o.padding` and `o.icon_size`
-- override the size's.
local function button(id, o)
    local sz = SIZES[o.size or "s"]
    local held = o.held or state("m3_held_" .. id, false)
    local bg, fg, border = paint(BUTTON_TONES, o.kind, o.selected)
    local tone = BUTTON_TONES[o.kind]
    local kids = {}
    if o.icon then
        kids[1] = icon(o.icon, fg, o.icon_size or sz.icon, merge({ animate = { foreground = FADE, rotate = SPRING } }, o.icon_props))
    end
    if o.label then
        kids[#kids + 1] = text(o.label, fg, sz.type)
    end
    local pad = o.kind == "text" and sz.pad * 0.75 or sz.pad
    local props = merge({
        width = o.width,
        height = sz.h,
        radius = o.radius and o.radius(held, o.selected) or radius_of(sz, o.shape, held, o.selected),
        background = bg,
        border_width = tone.border and sz.outline or 0,
        border_color = border,
        on_click = o.on_click,
        disabled = o.disabled,
    }, theme.elevation[tone.elevation or 0])
    return pressable(id, merge(props, o.props), fg, row {
        width = o.width and "fill",
        height = "fill",
        align_h = o.width and "center",
        align_v = "center",
        spacing = sz.gap,
        padding = o.padding or (o.label and { left = pad, right = pad } or 0),
        children = kids,
    }, held)
end

-- The click handler of a component that toggles `opts.value`, then calls `opts.on_click`.
local function click_of(opts)
    local value = opts.value
    if not value then
        return opts.on_click
    end
    return function()
        value:set(not value:get())
        if opts.on_click then
            opts.on_click()
        end
    end
end
M.pressable, M.SIZES, M.paint, M.radius_of, M.button, M.click_of = pressable, SIZES, paint, radius_of, button, click_of

return M
