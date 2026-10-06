-- M3 progress indicators: linear and circular, determinate and indeterminate, flat and wavy.
-- Motion is declarative: tweens and looping keyframes, never a Lua timer per frame.
local theme = require("m3.theme")
local core = require("m3.core")
local signal = require("m3.internal.common").signal

local c, FADE = theme.c, theme.motion.fade
local merge = core.merge

local M = {}

local LINEAR = { duration = 220, easing = "linear" }
local TRACK, STOP, GAP = 4, 4, 4

-- The track after a determinate indicator at `v`: the gap grows with the indicator up to GAP, as in
-- Compose, so an empty bar is all track.
local function track(p, w)
    local function start(v) return v * w + math.min(v * w, GAP) end
    return rect {
        width = p:map(function(v) return math.max(0, w - start(v)) end),
        height = TRACK,
        radius = 2,
        margin = p:map(function(v) return { left = start(v) } end),
        align_v = "center",
        background = c.secondary_container,
        animate = { width = LINEAR, margin = LINEAR, background = FADE },
    }
end

-- Determinate bar: active indicator, a 4px gap, the track and a stop dot. `p` is a 0..1 signal.
local function linear(p, w)
    return rect {
        width = w,
        height = TRACK,
        children = {
            rect { width = p:map(function(v) return v * w end), height = TRACK, radius = 2, background = c.primary, animate = { width = LINEAR, background = FADE } },
            track(p, w),
            rect { width = STOP, height = STOP, radius = 2, align_h = "end", background = c.primary, animate = { background = FADE } },
        },
    }
end

local LINEAR_MS = 1750

-- Keyframes for a trim fraction of a bar whose caps stay inside it: `...` are {fraction, ms, easing}
-- steps after the first value, which is a bare {fraction}.
local function trims(w, ...)
    local out = {}
    for i, p in ipairs({ ... }) do
        local v = math.max(0, math.min(1, (p[1] * w - 2) / (w - 4)))
        out[i] = i == 1 and v or { value = v, duration = p[2], easing = p[3] }
    end
    return out
end

local function loop(frames) return { duration = LINEAR_MS, easing = "linear", keyframes = frames, loops = "infinite" } end

-- A head or tail running `shift` to 1 + `shift` after `delay`, ms in all.
local function run(w, delay, ms, shift)
    local steps = { { shift } }
    if delay > 0 then
        steps[2] = { shift, delay }
    end
    steps[#steps + 1] = { 1 + shift, ms, theme.easing.emphasized_accelerate }
    steps[#steps + 1] = { 1 + shift, LINEAR_MS - delay - ms }
    return trims(w, table.unpack(steps))
end

-- Indeterminate bar, as Compose's M3: two lines, each with a head and a tail running 0 to 1 on
-- their own delays, and the track in the gaps between them. A line hides while its head and
-- tail meet, since a round cap would still draw a dot.
local function linear_indeterminate(w)
    local gap, ACC = (GAP + TRACK) / w, theme.easing.emphasized_accelerate
    local function bar(color, from, to, shown)
        local props = {
            width = w,
            height = TRACK,
            stroke = color,
            stroke_width = TRACK,
            stroke_cap = "round",
            commands = { { op = "M", points = { 2, 2 } }, { op = "L", points = { w - 2, 2 } } },
            trim_start = from[1],
            trim_end = to[1],
            animate = { stroke = FADE },
        }
        for key, frames in pairs({ trim_start = from, trim_end = to, opacity = shown }) do
            props.animate[key] = #frames > 1 and loop(frames) or nil
        end
        if shown then
            props.opacity = shown[1]
        end
        return path(props)
    end
    local track = c.secondary_container
    return rect {
        width = w,
        height = TRACK,
        children = {
            bar(track, run(w, 0, 1000, gap), trims(w, { 1 })),
            bar(track, trims(w, { 0 }, { 0, 650 }, { gap, 0 }, { 1 + gap, 850, ACC }, { 1 + gap, 250 }), trims(w, { -gap }, { -gap, 250 }, { 1 - gap, 1000, ACC }, { 1, 0 }, { 1, 500 })),
            bar(track, trims(w, { 0 }), trims(w, { -gap }, { -gap, 900 }, { 1 - gap, 850, ACC })),
            bar(c.primary, run(w, 250, 1000, 0), run(w, 0, 1000, 0), { 1, { value = 1, duration = 1250 }, { value = 0, duration = 0 }, { value = 0, duration = 500 } }),
            bar(c.primary, run(w, 900, 850, 0), run(w, 650, 850, 0), { 0, { value = 0, duration = 650 }, { value = 1, duration = 0 }, { value = 1, duration = 1100 } }),
        },
    }
end

local WAVE, AMP, WAVE_H = 40, 3, 10
local WAVE_FADE = { duration = 500, easing = theme.easing.standard }
local CAP = TRACK / 2

-- M3 flattens the wave at the start and the end of the range.
local function waviness(v) return v > 0.1 and v < 0.95 and 1 or 0 end

-- A sine wave of amplitude `amp` across `w` px plus one wavelength to its left, vertically centred
-- in WAVE_H, so shifting it right by one wavelength loops its phase.
local function sine(w, amp)
    local commands = {}
    for i = 0, (w + WAVE) // 2 do
        local x = i * 2 - WAVE
        commands[i + 1] = { op = i == 0 and "M" or "L", points = { x, WAVE_H / 2 + amp * math.sin(x / WAVE * 2 * math.pi) } }
    end
    return commands
end

-- Wavy determinate bar: the active part is a travelling sine wave trimmed to the progress, its
-- amplitude easing flat near the ends of the range, then a gap, the flat track and the stop dot.
local function linear_wavy(p, w)
    return rect {
        width = w,
        height = WAVE_H,
        children = {
            path {
                width = w,
                height = WAVE_H,
                stroke = c.primary,
                stroke_width = TRACK,
                stroke_cap = "round",
                stroke_join = "round",
                commands = p:map(waviness):map(function(on) return sine(w, on * AMP) end),
                trim_axis = "x",
                trim_start = CAP / w,
                trim_end = p:map(function(v) return math.max(CAP / w, v - CAP / w) end),
                opacity = p:map(function(v) return v * w > TRACK and 1 or 0 end),
                animate = {
                    commands = WAVE_FADE,
                    trim_end = LINEAR,
                    stroke = FADE,
                    shift = { duration = 1000, easing = "linear", keyframes = { { x = 0, y = 0 }, { x = WAVE, y = 0 } }, loops = "infinite" },
                },
            },
            track(p, w),
            rect { width = STOP, height = STOP, radius = 2, align_h = "end", align_v = "center", background = c.primary, animate = { background = FADE } },
        },
    }
end

local SIZE, R = 48, 18
local WAVES, WAVE_R, WAVE_AMP, STEPS, RING_PHASES = 9, 20.4, 1.6, 108, 8
local FULL = 360
local WAVE_RING_MS = 950

local function circle(r) return { { op = "A", points = { SIZE / 2, SIZE / 2, r, -90, FULL } } } end

-- Wavy full ring starting at 12 o'clock, its wave shifted by `phase` radians.
local function wavy_ring(phase)
    local commands = {}
    for i = 0, STEPS do
        local a = math.rad(-90 + FULL * i / STEPS)
        local r = WAVE_R + WAVE_AMP * math.sin(WAVES * a - phase)
        commands[i + 1] = { op = i == 0 and "M" or "L", points = { SIZE / 2 + r * math.cos(a), SIZE / 2 + r * math.sin(a) } }
    end
    return commands
end

local function wave_frames()
    local frames = {}
    for k = 0, RING_PHASES do
        frames[k + 1] = wavy_ring(2 * math.pi * k / RING_PHASES)
    end
    return frames, { commands = { duration = WAVE_RING_MS // RING_PHASES, easing = "linear", keyframes = frames, loops = "infinite" } }
end

local function length(commands)
    local total, prev = 0, nil
    for _, cmd in ipairs(commands) do
        local x, y = cmd.points[1], cmd.points[2]
        if prev then
            total = total + math.sqrt((x - prev[1]) ^ 2 + (y - prev[2]) ^ 2)
        end
        prev = cmd.points
    end
    return total
end

local function ring_stroke(color, commands, props)
    return path(merge({
        width = SIZE,
        height = SIZE,
        stroke = color,
        stroke_width = TRACK,
        stroke_cap = "round",
        commands = commands,
    }, props))
end

local function clamp(v) return math.max(0, math.min(1, v)) end

-- Determinate ring: one fixed path per part, trimmed. The active arc runs clockwise from 12
-- o'clock, a 4px gap (measured between the round caps) follows it, then the track. The gap closes
-- at 0 and 100%. `active` is the active path's commands, `r` the track's radius, `extra` its
-- animation, `flat` the commands of the flat arc a wave flattens into at either end of the range.
local function circular(p, r, active, active_len, extra, flat)
    local cap_t, gap = CAP / (2 * math.pi * r), GAP / (2 * math.pi * r)
    local function split(v)
        local g = gap * math.min(1, v * 20, (1 - v) * 20)
        return g, v * (1 - 2 * g)
    end
    local function arc(commands, len, opacity)
        local cap = CAP / len
        return ring_stroke(c.primary, commands, {
            trim_start = cap,
            trim_end = p:map(function(v) local _, a = split(v) return clamp(a - cap) end),
            opacity = opacity,
            animate = merge({ trim_end = LINEAR, opacity = WAVE_FADE, stroke = FADE }, commands == active and extra or nil),
        })
    end
    local wavy = flat and p:map(waviness)
    local arcs = flat and { arc(flat, 2 * math.pi * r, wavy:map(function(o) return 1 - o end)), arc(active, active_len, wavy) } or { arc(active, active_len) }
    return rect {
        width = SIZE,
        height = SIZE,
        children = {
            ring_stroke(c.secondary_container, circle(r), {
                trim_start = p:map(function(v) local g, a = split(v) return clamp(a + g + cap_t) end),
                trim_end = p:map(function(v) local g = split(v) return clamp(1 - g - cap_t) end),
                animate = { trim_start = LINEAR, trim_end = LINEAR, stroke = FADE },
            }),
            table.unpack(arcs),
        },
    }
end

local function circular_flat(p) return circular(p, R, circle(R), 2 * math.pi * R) end

local function circular_wavy(p)
    local frames, extra = wave_frames()
    return circular(p, WAVE_R, frames[1], length(frames[1]), extra, circle(WAVE_R))
end

-- Indeterminate ring, as Compose's M3: one arc whose sweep grows from 10% to 87% over 3 s and
-- shrinks back, turned by a steady 1080 degrees per 6 s plus a 90 degree step every 1.5 s.
-- `commands` and `extra` pick flat or wavy.
local function circular_indeterminate(commands, len, extra)
    local ease, cap = theme.easing.emphasized_decelerate, CAP / len
    ---@type any[]
    local frames = { 0 }
    for i = 1, 4 do
        frames[#frames + 1] = { value = 90 * i, duration = 300, easing = ease }
        frames[#frames + 1] = { value = 90 * i, duration = 1200 }
    end
    return rect {
        width = SIZE,
        height = SIZE,
        rotate = 0,
        animate = { rotate = { duration = 6000, easing = "linear", keyframes = { 0, 1080 }, loops = "infinite" } },
        children = {
            rect {
                width = SIZE,
                height = SIZE,
                rotate = 0,
                animate = { rotate = { duration = 6000, easing = "linear", keyframes = frames, loops = "infinite" } },
                children = {
                    ring_stroke(c.primary, commands, {
                        trim_start = cap,
                        trim_end = 0.1 - cap,
                        animate = merge({
                            trim_end = { duration = 3000, easing = "linear", keyframes = { 0.1 - cap, 0.87 - cap, { value = 0.1 - cap, easing = theme.easing.standard } }, loops = "infinite" },
                            stroke = FADE,
                        }, extra),
                    }),
                },
            },
        },
    }
end

local function circular_wavy_indeterminate()
    local frames, extra = wave_frames()
    return circular_indeterminate(frames[1], length(frames[1]), extra)
end

-- Linear progress bar (`progress_bar`).
---@class m3.ProgressOpts
---@field value? number|Signal<number> 0..1. Default 0.
---@field indeterminate? boolean Ignores `value`.
---@field wavy? boolean Wavy active indicator.
---@field name? string Accessible name; default "progress".
---@field [string] "no such property"

---@class m3.ProgressBarOpts: m3.ProgressOpts
---@field width? number Default 240.
---@field [string] "no such property"

---@param id string
---@param opts m3.ProgressBarOpts
---@return Node
function M.progress_bar(id, opts)
    local w = opts.width or 240
    local bar = opts.indeterminate and linear_indeterminate(w) or (opts.wavy and linear_wavy or linear)(signal(id, opts.value), w)
    return rect { accessible_name = opts.name or "progress", children = { bar } }
end

-- Circular progress ring (`progress_ring`, 48px).
---@param id string
---@param opts m3.ProgressOpts
---@return Node
function M.progress_ring(id, opts)
    local ring
    if opts.indeterminate then
        ring = opts.wavy and circular_wavy_indeterminate() or circular_indeterminate(circle(R), 2 * math.pi * R)
    else
        local p = signal(id, opts.value)
        ring = opts.wavy and circular_wavy(p) or circular_flat(p)
    end
    return rect { accessible_name = opts.name or "progress", children = { ring } }
end

return M
