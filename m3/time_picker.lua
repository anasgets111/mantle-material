-- M3 time picker: a dial whose hand is a rotating node. Dragging picks the hour, then the minutes.
-- The hand's angle is stored unwrapped so it turns the short way.
local theme = require("m3.theme")
local core = require("m3.core")
local overlay = require("m3.overlay")
local picker = require("m3.internal.picker")
local sel = require("m3.internal.selection")
local text_field = require("m3.text_field").text_field

local c, pick, motion = theme.c, theme.pick, theme.motion
local text, interactive, merge = core.text, core.interactive, core.merge
local QUICK, tint = sel.QUICK, sel.tint
local modal, actions = picker.modal, picker.actions

local M = {}

local time_default = state("m3_time_default", { h = 10, m = 30, pm = false })
---@type table
local time_spec = {}
local time_draft = state("m3_time_draft", { h = 10, m = 30, pm = false, mode = "hour", ang = 300 })

local DIAL, RING = 256, 101

local function near(current, target) return target + 360 * math.floor((current - target) / 360 + 0.5) end

local function angle_of(t) return t.mode == "hour" and (t.h % 12) * 30 or t.m * 6 end

local function set_time(change)
    local t = merge(merge({}, time_draft:get()), change)
    t.ang = near(time_draft:get().ang, angle_of(t))
    time_draft:set(t)
end

local function dial_drag(box, pointer, phase)
    local half = box.width / 2
    local deg = math.deg(math.atan(pointer.x - half, half - pointer.y)) % 360
    local t = time_draft:get()
    if t.mode == "hour" then
        local h = math.floor(deg / 30 + 0.5) % 12
        set_time({ h = h == 0 and 12 or h })
        if phase == "end" then
            set_time({ mode = "minute" })
        end
    else
        set_time({ m = math.floor(deg / 6 + 0.5) % 60 })
    end
end

local function dial_labels(mode)
    local labels = {}
    for i = 1, 12 do
        local a = math.rad(i * 30)
        local label = mode == "hour" and i or (i * 5) % 60
        local on = time_draft:map(function(t)
            return mode == "hour" and t.mode == "hour" and t.h == i or mode == "minute" and t.mode == "minute" and t.m == label
        end)
        labels[i] = rect {
            width = 48,
            height = 48,
            margin = { left = DIAL / 2 + RING * math.sin(a) - 24, top = DIAL / 2 - RING * math.cos(a) - 24 },
            hittable = false,
            children = {
                text(mode == "hour" and tostring(label) or string.format("%02d", label), pick(on, "on_primary", "on_surface"), "body_large", { align_h = "center" }),
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

local function dial()
    local hand = rect {
        width = DIAL,
        height = DIAL,
        hittable = false,
        rotate = time_draft:map(function(t) return t.ang end),
        animate = { rotate = motion.spatial_fast },
        children = {
            path {
                width = DIAL,
                height = DIAL,
                stroke = c.primary,
                stroke_width = 2,
                stroke_cap = "round",
                commands = { { op = "M", points = { DIAL / 2, DIAL / 2 } }, { op = "L", points = { DIAL / 2, DIAL / 2 - RING + 24 } } },
            },
            rect { width = 8, height = 8, radius = 4, align_h = "center", align_v = "center", background = c.primary },
            rect {
                width = 48,
                height = 48,
                radius = 24,
                align_h = "center",
                margin = { top = DIAL / 2 - RING - 24 },
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
        on_drag = dial_drag,
        children = { hand, rect { width = DIAL, height = DIAL, children = time_draft:map(function(t) return t.mode end):map(dial_labels) } },
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
    }, fg, text(time_draft:map(function(t) return format(t[field == "hour" and "h" or "m"]) end), fg, "display_large", { align_h = "center" }))
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

overlay.layer("time", function()
    local o = time_spec
    return modal("time", 328, 24, {
        text("Select time", c.on_surface_variant, "label_medium"),
        row {
            spacing = 12,
            children = {
                time_box("hour", "hour", function(h) return string.format("%02d", h) end),
                text(":", c.on_surface, "display_large", { align_v = "center" }),
                time_box("minute", "minute", function(m) return string.format("%02d", m) end),
                rect {
                    width = 52,
                    height = 80,
                    radius = 8,
                    clip = "rounded",
                    align_v = "center",
                    border_width = 1,
                    border_color = c.outline,
                    children = { column { children = { period("AM", false), period("PM", true) } } },
                },
            },
        },
        rect { height = 12 },
        dial(),
        actions("time", "tp", function()
            local t = time_draft:get()
            local picked = { h = t.h, m = t.m, pm = t.pm }
            o.value:set(picked)
            if o.on_change then
                o.on_change(picked)
            end
        end),
    })
end)

-- opts: value (state { h = 1..12, m = 0..59, pm = boolean }), on_change(t).
function M.open_time_picker(opts)
    time_spec = merge({ value = time_default }, opts)
    local t = time_spec.value:get()
    time_draft:set({ h = t.h, m = t.m, pm = t.pm, mode = "hour", ang = (t.h % 12) * 30 })
    overlay.open("time")
end

-- A field showing the picked time that opens the dial. opts: label, value (as `open_time_picker`),
-- kind, container, width, on_change.
function M.time_picker(id, opts)
    local value = opts.value or state("m3_time_" .. id, { h = 10, m = 30, pm = false })
    return (text_field(id, {
        kind = opts.kind,
        label = opts.label,
        container = opts.container,
        width = opts.width or 280,
        display = value:map(function(t) return string.format("%d:%02d %s", t.h, t.m, t.pm and "PM" or "AM") end),
        trailing = "schedule",
        active = overlay.is_open("time"),
        on_click = function() M.open_time_picker({ value = value, on_change = opts.on_change }) end,
    }))
end

return M
