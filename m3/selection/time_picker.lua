-- M3 time picker: a dial whose hand is a rotating node. Dragging picks the hour, then the minutes.
-- The hand's angle is stored unwrapped so it turns the short way.
local theme = require("m3.theme")
local core = require("m3.core")
local overlay = require("m3.overlay")
local picker = require("m3.internal.picker")
local sel = require("m3.internal.selection")
local text_field = require("m3.inputs.text_field")
local edit_click = text_field.edit_click
local icon_button = require("m3.actions.icon_button").icon_button

local c, pick, motion = theme.c, theme.pick, theme.motion
local text, interactive, merge = core.text, core.interactive, core.merge
local QUICK, tint = sel.QUICK, sel.tint
local modal, actions = picker.modal, picker.actions

local M = {}

local time_default = state("m3_time_default", { h = 10, m = 30, pm = false })
---@type table
local time_spec = {}
---@type StateSignal<boolean>
local keyboard = state("m3_time_input", false)
local time_draft = state("m3_time_draft", { h = 10, m = 30, pm = false, mode = "hour", ang = 300 })
-- Input mode: which typed fields are not a valid hour or minute; any blocks OK.
local time_err = state("m3_time_err", { hour = false, minute = false })

-- 24 h dial: 1-12 on the outer ring, 13-23 and 00 on the inner ring.
-- not in the spec: the inner ring's radius, and the split between the rings at its midpoint.
local DIAL, RING, INNER = 256, 101, 66

local function hour24(t) return t.h % 12 + (t.pm and 12 or 0) end

local function near(current, target) return target + 360 * math.floor((current - target) / 360 + 0.5) end

local function inner_ring(t)
    local h = hour24(t)
    return t.mode == "hour" and (h == 0 or h >= 13)
end

local function angle_of(t) return t.mode == "hour" and (t.h % 12) * 30 or t.m * 6 end

local function set_time(change)
    local t = merge(merge({}, time_draft:get()), change)
    t.ang = near(time_draft:get().ang, angle_of(t))
    time_draft:set(t)
end

local function dial_drag(h24, box, pointer, phase)
    local half = box.width / 2
    local dx, dy = pointer.x - half, half - pointer.y
    local deg = math.deg(math.atan(dx, dy)) % 360
    local t = time_draft:get()
    if t.mode == "hour" then
        local h = math.floor(deg / 30 + 0.5) % 12
        if h24 then
            local hh = math.sqrt(dx * dx + dy * dy) < (RING + INNER) / 2 and (h == 0 and 0 or h + 12) or (h == 0 and 12 or h)
            set_time({ h = hh % 12 == 0 and 12 or hh % 12, pm = hh >= 12 })
        else
            set_time({ h = h == 0 and 12 or h })
        end
        if phase == "end" then
            set_time({ mode = "minute" })
        end
    else
        set_time({ m = math.floor(deg / 6 + 0.5) % 60 })
    end
end

local function dial_labels(mode, h24)
    local labels = {}
    for i = 1, h24 and mode == "hour" and 24 or 12 do
        local a = math.rad(i * 30)
        local ring = i > 12 and INNER or RING
        local label = mode == "hour" and (i > 12 and (i == 24 and 0 or i) or i) or (i * 5) % 60
        local on = time_draft:map(function(t)
            if mode == "minute" then
                return t.mode == "minute" and t.m == label
            end
            return t.mode == "hour" and (h24 and hour24(t) == label or not h24 and t.h == i)
        end)
        labels[i] = rect {
            width = 48,
            height = 48,
            margin = { left = DIAL / 2 + ring * math.sin(a) - 24, top = DIAL / 2 - ring * math.cos(a) - 24 },
            hittable = false,
            children = {
                text(mode == "hour" and i <= 12 and tostring(label) or string.format("%02d", label), pick(on, "on_primary", "on_surface"), i > 12 and "body_medium" or "body_large", { align_h = "center" }),
            },
        }
    end
    return {
        rect {
            id = "labels_" .. mode,
            width = DIAL,
            height = DIAL,
            opacity = 1,
            animate = { opacity = { duration = 200, from = 0 }, exit = { duration = 100, opacity = 0 } },
            children = labels,
        },
    }
end

local function dial(h24)
    local reach = time_draft:map(function(t) return h24 and inner_ring(t) and INNER or RING end)
    local hand = rect {
        width = DIAL,
        height = DIAL,
        hittable = false,
        rotate = time_draft:map(function(t) return t.ang end),
        animate = { rotate = motion.spatial_fast },
        children = {
            rect {
                width = 2,
                align_h = "center",
                background = c.primary,
                height = reach:map(function(r) return r - 24 end),
                margin = reach:map(function(r) return { top = DIAL / 2 - r + 24 } end),
            },
            rect { width = 8, height = 8, radius = 4, align_h = "center", align_v = "center", background = c.primary },
            rect {
                width = 48,
                height = 48,
                radius = 24,
                align_h = "center",
                margin = reach:map(function(r) return { top = DIAL / 2 - r - 24 } end),
                background = c.primary,
                children = {
                    rect {
                        width = 4,
                        height = 4,
                        radius = 2,
                        align_h = "center",
                        align_v = "center",
                        background = c.on_primary,
                        opacity = time_draft:map(function(t) return t.mode == "minute" and t.m % 5 ~= 0 and 1 or 0 end),
                        animate = { opacity = QUICK },
                    },
                },
            },
        },
    }
    return rect {
        width = DIAL,
        height = DIAL,
        radius = DIAL / 2,
        align_h = "center",
        background = c.surface_container_highest,
        on_drag = function(box, pointer, phase) dial_drag(h24, box, pointer, phase) end,
        children = { hand, rect { width = DIAL, height = DIAL, children = time_draft:map(function(t) return t.mode end):map(function(mode) return dial_labels(mode, h24) end) } },
    }
end

local function time_box(name, field, format)
    local active = time_draft:map(function(t) return t.mode == field end)
    local fg = pick(active, "on_primary_container", "on_surface")
    return interactive("tp_" .. name, {
        width = 96,
        height = 80,
        radius = 8,
        background = pick(active, "primary_container", "surface_container_highest"),
        accessible_name = name,
        on_click = function() set_time({ mode = field }) end,
    }, fg, text(time_draft:map(format), fg, "display_large", { align_h = "center" }))
end

local function period(label, pm)
    local on = time_draft:map(function(t) return t.pm == pm end)
    local fg = pick(on, "on_tertiary_container", "on_surface_variant")
    return interactive("tp_" .. label, {
        width = 52,
        height = 40,
        background = tint(on, "tertiary_container"),
        border_width = pm and { top = 1 } or 0,
        border_color = c.outline,
        accessible_name = label,
        on_click = function() set_time({ pm = pm }) end,
    }, fg, text(label, fg, "title_medium", { align_h = "center" }))
end

-- Input mode: an hour and a minute field of the dial's boxes; a full hour moves on to the minute.
local function input_box(name, label, focus, next_focus, text_of, on_value, autofocus)
    local active = focused("m3_tp_f_" .. name)
    local bad = time_err:map(function(e) return e[name] end)
    local fg = pick(active, "on_primary_container", "on_surface")
    local type = theme.type.display_large
    return column {
        spacing = 4,
        children = {
            rect {
                width = 96,
                height = 72,
                radius = 8,
                background = pick(active, "primary_container", "surface_container_highest"),
                border_width = computed({ active, bad }, function(on, err) return (on or err) and 2 or 0 end),
                border_color = pick(bad, "error", "primary"),
                animate = { background = motion.fade },
                children = {
                    textfield {
                        width = "fill",
                        height = 64,
                        align_v = "center",
                        text_align = "center",
                        font_size = type[1],
                        letter_spacing = type[4],
                        foreground = fg,
                        caret = { color = c.primary },
                        selection = { background = c.primary:map(function(p) return theme.alpha(p, 0.3) end) },
                        on_click = edit_click(focus, has_selection("m3_tp_" .. name .. "_in")),
                        escape = "pass",
                        max_length = 2,
                        initial_text = text_of,
                        accessible_name = label,
                        autofocus = autofocus,
                        focus_ring = false,
                        focused = active,
                        focus_target = focus,
                        on_change = function(t)
                            local digits = (t:gsub("%D", ""))
                            if digits ~= t then
                                focus:set_text(digits)
                            end
                            local n = tonumber(digits)
                            local ok = n ~= nil and on_value(n)
                            time_err:set(merge(merge({}, time_err:get()), { [name] = not ok }))
                            if ok and next_focus and (#digits == 2 or n > 2) then
                                next_focus:request()
                            end
                        end,
                    },
                },
            },
            text(label, pick(bad, "error", "on_surface_variant"), "body_small"),
        },
    }
end

overlay.layer("time", function()
    local o = time_spec
    local h24 = o.h24
    local hour_focus, minute_focus = focus_target("m3_tp_hour_in"), focus_target("m3_tp_minute_in")
    local boxes = row {
        spacing = 12,
        children = {
            time_box("hour", "hour", function(t) return string.format("%02d", h24 and hour24(t) or t.h) end),
            text(":", c.on_surface, "display_large", { align_v = "center" }),
            time_box("minute", "minute", function(t) return string.format("%02d", t.m) end),
            not h24 and rect {
                width = 52,
                height = 80,
                radius = 8,
                clip = "rounded",
                align_v = "center",
                border_width = 1,
                border_color = c.outline,
                children = { column { children = { period("AM", false), period("PM", true) } } },
            } or nil,
        },
    }
    local dial_view = column {
        spacing = 12,
        children = { boxes, rect { height = 12 }, dial(h24) },
    }
    local fields = row {
        spacing = 12,
        children = {
            input_box("hour", "Hour", hour_focus, minute_focus, time_draft:map(function(t) return string.format("%02d", h24 and hour24(t) or t.h) end), function(n)
                local ok = h24 and n <= 23 or n >= 1 and n <= 12
                if ok then
                    set_time(h24 and { h = n % 12 == 0 and 12 or n % 12, pm = n >= 12 } or { h = n })
                end
                return ok
            end, true),
            text(":", c.on_surface, "display_large", { align_v = "center", margin = { bottom = 20 } }),
            input_box("minute", "Minute", minute_focus, nil, time_draft:map(function(t) return string.format("%02d", t.m) end), function(n)
                local ok = n <= 59
                if ok then
                    set_time({ m = n })
                end
                return ok
            end),
            not h24 and rect {
                width = 52,
                height = 80,
                radius = 8,
                clip = "rounded",
                border_width = 1,
                border_color = c.outline,
                children = { column { children = { period("AM", false), period("PM", true) } } },
            } or nil,
        },
    }
    local input_view = column {
        spacing = 4,
        children = {
            fields,
            text(time_err:map(function(e)
                if e.hour or e.minute then
                    return string.format("Enter a valid %s (%s)", e.hour and e.minute and "time" or e.hour and "hour" or "minute", e.hour and (h24 and "0-23" or "1-12") or "0-59")
                end
                return ""
            end), c.error, "body_small", { align_h = "center" }),
        },
    }
    return modal("time", 328, 24, {
        text(keyboard:map(function(on) return on and "Enter time" or "Select time" end), c.on_surface_variant, "label_medium"),
        rect { align_h = "center", children = keyboard:map(function(on) return { on and input_view or dial_view } end) },
        row {
            width = "fill",
            align_v = "center",
            children = {
                icon_button("tp_mode", {
                    kind = "standard",
                    icon = keyboard:map(function(on) return on and "schedule" or "keyboard" end),
                    on_click = function()
                        time_err:set({ hour = false, minute = false })
                        keyboard:set(not keyboard:get())
                    end,
                }),
                actions("time", "tp", function()
                    local t = time_draft:get()
                    local picked = { h = t.h, m = t.m, pm = t.pm }
                    o.value:set(picked)
                    if o.on_change then
                        o.on_change(picked)
                    end
                end, time_err:map(function(e) return e.hour or e.minute end)),
            },
        },
    })
end)

---@class m3.Time
---@field h integer 1..12.
---@field m integer 0..59.
---@field pm boolean

-- Opens the dial.
---@class m3.OpenTimePickerOpts
---@field value? StateSignal<m3.Time> Default shared.
---@field input? boolean Start in input mode, two number fields; the header's keyboard icon toggles it.
---@field h24? boolean 24 h: the dial's outer ring is 1-12, an inner ring 13-23 and 00 (pick by radius), no AM/PM; input mode's hour field is 0-23.
---@field on_change? fun(t: m3.Time) After OK.
---@field window? string The window or panel it opens over; default `m3.core.window`.
---@field [string] "no such property"

---@param opts? m3.OpenTimePickerOpts
function M.open_time_picker(opts)
    time_spec = merge({ value = time_default }, opts or {})
    local t = time_spec.value:get()
    keyboard:set(time_spec.input == true)
    time_err:set({ hour = false, minute = false })
    time_draft:set({ h = t.h, m = t.m, pm = t.pm, mode = "hour", ang = (t.h % 12) * 30 })
    overlay.open("time", nil, time_spec.window)
end

-- A field showing the picked time that opens the dial.
---@class m3.TimePickerOpts
---@field label? string
---@field value? StateSignal<m3.Time> Default own, 10:30 AM.
---@field kind? "outlined"|"filled"
---@field container? string|Signal<string> Colour behind an outlined field.
---@field width? number Default 280.
---@field input? boolean Open in input mode.
---@field h24? boolean Show 24 h; the dial gets an inner ring and input mode takes a 0-23 hour.
---@field on_change? fun(t: m3.Time) After OK.
---@field [string] "no such property"

---@param id string
---@param opts? m3.TimePickerOpts
---@return Node
function M.time_picker(id, opts)
    opts = opts or {}
    local value = opts.value or state("m3_time_" .. id, { h = 10, m = 30, pm = false })
    return (text_field.text_field(id, {
        kind = opts.kind,
        label = opts.label,
        container = opts.container,
        width = opts.width or 280,
        display = value:map(function(t)
            return opts.h24 and string.format("%02d:%02d", hour24(t), t.m) or string.format("%d:%02d %s", t.h, t.m, t.pm and "PM" or "AM")
        end),
        trailing = "schedule",
        active = overlay.is_open("time"),
        on_click = function() M.open_time_picker({ value = value, input = opts.input, h24 = opts.h24, on_change = opts.on_change }) end,
    }))
end

return M
