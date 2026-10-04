-- M3 text field (outlined and filled; also the read-only field the dropdown and pickers use).
-- See docs/inputs.md.
local theme = require("m3.theme")
local core = require("m3.core")
local icon_button = require("m3.icon_button").icon_button

local c, pick, motion = theme.c, theme.pick, theme.motion
local text, icon = core.text, core.icon
local FADE, CLEAR = motion.fade, theme.CLEAR

local M = {}

local LABEL_MOVE = { duration = 200, easing = theme.easing.standard }

---------------------------------------------------------------------------------------------------
-- Text field: the label rests inside and floats onto the outline (outlined, cutting it with the
-- container colour) or above the text (filled), shrinking to 12px, while focused or filled.

-- opts: kind ("outlined" or "filled"), label, value (state of the text), container (the colour
-- behind an outlined field, which the floating label cuts the outline with), width (default
-- "fill"), leading, trailing (icon names), clear (a clear button while typing), prefix, suffix,
-- supporting (helper text), validate(text) (an error message or nil, shown in place of the
-- supporting text), max_length (caps the text; shows an n/max counter), disabled (boolean),
-- placeholder.
-- Read-only mode (the dropdown and picker fields): display (a signal of the shown text, replacing
-- the input), on_click, active (a signal that styles the field as focused), spin (turn the
-- trailing icon while active), geometry (a `geometry(name)` for the field).
-- Returns the node and a handle { value, clear, set(text) }; wrap the call in parentheses to
-- keep only the node, e.g. in a table constructor.
function M.text_field(id, opts)
    local name = "m3_tf_" .. id
    local filled = opts.kind == "filled"
    local display = opts.display
    local value = display or opts.value or state(name, "")
    local focus = opts.active or focused(name)
    local target = focus_target(name)
    local over = hover(name .. "_hover")
    local off = opts.disabled
    local dim = off and 0.38 or 1
    local has_trailing = opts.trailing or opts.clear or opts.validate
    local invalid = value:map(function(v)
        if (v or "") == "" then
            return false
        end
        return opts.validate and opts.validate(v) or false
    end)
    local raised = computed({ focus, value }, function(f, v) return f or (v or "") ~= "" end)
    local tint = computed({ focus, invalid, theme.scheme }, function(f, err, s)
        return err and s.error or f and s.primary or s.on_surface_variant
    end)
    local function set(t)
        local cut = opts.max_length and utf8.offset(t, opts.max_length + 1)
        t = cut and t:sub(1, cut - 1) or t
        target:set_text(t)
        value:set(t)
    end
    local function clear() set("") end

    local function side(label)
        return text(label, c.on_surface_variant, "body_large", {
            opacity = raised:map(function(up) return up and dim or 0 end),
            animate = { opacity = { duration = 150 }, foreground = FADE },
        })
    end
    local input = display and text(value, c.on_surface, "body_large", { width = "fill", hittable = false })
        or textfield {
            width = "fill",
            height = "fill",
            font_size = 16,
            letter_spacing = theme.type.body_large[4],
            foreground = c.on_surface,
            placeholder = opts.placeholder,
            placeholder_color = c.on_surface_variant,
            caret = { color = tint },
            initial_text = value,
            disabled = opts.disabled,
            max_length = opts.max_length,
            accessible_name = opts.label,
            focus_ring = false,
            focus_target = target,
            on_change = function(t) value:set(t) end,
        }
    local parts = { input }
    if opts.prefix then
        table.insert(parts, 1, side(opts.prefix))
    end
    if opts.suffix then
        parts[#parts + 1] = side(opts.suffix)
    end
    local entry = row { width = "fill", height = "fill", align_v = "center", margin = { top = filled and 16 or 0 }, opacity = dim, children = parts }

    local function shown(fn) return computed({ value, invalid }, fn) end
    local function fade(v) return v and 1 or 0 end
    local trailing = rect {
        width = 48,
        height = 48,
        align_v = "center",
        opacity = dim,
        children = {
            opts.trailing and icon(opts.trailing, c.on_surface_variant, 24, {
                align_h = "center",
                hittable = false,
                opacity = shown(function(v, err) return fade(not err and not (opts.clear and (v or "") ~= "")) end),
                rotate = opts.spin and focus:map(function(on) return on and 180 or 0 end) or 0,
                animate = { opacity = { duration = 100 }, rotate = LABEL_MOVE, foreground = FADE },
            }) or rect {},
            opts.clear and icon_button("tf_clear_" .. id, {
                kind = "standard",
                icon = "close",
                on_click = clear,
                props = {
                    opacity = shown(function(v, err) return fade(not err and (v or "") ~= "") end),
                    hittable = shown(function(v, err) return not err and (v or "") ~= "" end),
                    animate = { opacity = { duration = 100 } },
                },
            }) or rect {},
            icon("error", c.error, 24, {
                align_h = "center",
                hittable = false,
                opacity = invalid:map(fade),
                animate = { opacity = { duration = 100 }, foreground = FADE },
            }),
        },
    }

    local lead = opts.leading
    local middle = rect {
        width = "fill",
        height = "fill",
        children = {
            rect {
                align_v = "center",
                padding = { left = 4, right = 4 },
                opacity = dim,
                hittable = false,
                background = filled and CLEAR or computed({ raised, opts.container or c.surface_container }, function(up, bg) return up and bg or CLEAR end),
                translate = raised:map(function(up)
                    return { x = (not filled and up and lead) and -32 or -4, y = up and (filled and -12 or -28) or 0 }
                end),
                scale = raised:map(function(up) return up and 0.75 or 1 end),
                origin = { x = 0, y = 0.5 },
                animate = { translate = LABEL_MOVE, scale = LABEL_MOVE },
                children = { text(opts.label, tint, "body_large") },
            },
            entry,
        },
    }
    local line = computed({ focus, invalid, over, theme.scheme }, function(f, err, hov, s)
        if off then
            return theme.alpha(s.on_surface, 0.38)
        end
        return err and (hov and not f and s.on_error_container or s.error) or f and s.primary or hov and s.on_surface or filled and s.on_surface_variant or s.outline
    end)
    local indicator = filled and rect {
        width = "fill",
        height = focus:map(function(f) return f and 2 or 1 end),
        align_v = "end",
        background = line,
        animate = { height = { duration = 150 }, background = FADE },
    } or nil
    local outline = off and theme.scheme:map(function(s) return theme.alpha(s.on_surface, 0.12) end) or line

    local layout = { middle }
    if lead then
        table.insert(layout, 1, rect { width = 48, height = 48, align_v = "center", opacity = dim, children = { icon(lead, c.on_surface_variant, 24, { align_h = "center" }) } })
    end
    if has_trailing then
        layout[#layout + 1] = trailing
    end
    local counter = opts.max_length and text(value:map(function(v) return (utf8.len(v or "") or 0) .. "/" .. opts.max_length end), c.on_surface_variant, "body_small") or nil
    local node = column {
        width = opts.width or "fill",
        spacing = 4,
        children = {
            rect {
                width = "fill",
                height = 56,
                focused = focus,
                hover = over,
                geometry = opts.geometry,
                hittable = not opts.disabled,
                accessible_name = display and opts.label or nil,
                radius = filled and { top_left = 4, top_right = 4, bottom_right = 0, bottom_left = 0 } or 4,
                background = filled and (off and c.on_surface:map(function(o) return theme.alpha(o, 0.04) end) or c.surface_container_highest) or CLEAR,
                border_width = filled and 0 or focus:map(function(f) return f and 2 or 1 end),
                border_color = filled and CLEAR or outline,
                animate = { border_color = FADE, border_width = { duration = 150 }, background = FADE },
                on_click = opts.on_click or function() target:request() end,
                children = {
                    row {
                        width = "fill",
                        height = "fill",
                        align_v = "center",
                        padding = { left = lead and 0 or 16, right = has_trailing and 0 or 16 },
                        children = layout,
                    },
                    indicator,
                },
            },
            row {
                width = "fill",
                padding = { left = 16, right = 16 },
                children = {
                    text(invalid:map(function(err) return err or opts.supporting or "" end), pick(invalid, "error", "on_surface_variant"), "body_small", { width = "fill", opacity = dim }),
                    counter,
                },
            },
        },
    }
    return node, { value = value, clear = not display and clear or nil, set = not display and set or nil }
end

return M
