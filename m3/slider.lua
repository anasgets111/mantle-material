-- M3 slider: three track segments (inactive, active, inactive) split around each 4px handle by a 6px
-- gap with 2px inner corners, optional ticks, and a value bubble over a held handle.
local theme = require("m3.theme")
local core = require("m3.core")

local c, motion = theme.c, theme.motion
local text = core.text
local FADE = motion.fade

local M = {}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local SLIDE = { duration = 120, easing = "out_cubic" }
local SIZES = { xs = { 16, 44, 8 }, s = { 24, 44, 8 }, m = { 40, 44, 12 }, l = { 56, 68, 16 }, xl = { 96, 108, 28 } }

-- opts: kind ("continuous", "discrete", "range" or "centered"), value (state 0..1; the high thumb
-- of a range), low (state: the range's low thumb), size ("xs", "s", "m", "l" or "xl"), steps (discrete, default 5), width, format(v)
-- (bubble text).
function M.slider(id, opts)
    local kind = opts.kind or "continuous"
    local W = opts.width or 300
    local H, HANDLE, R = table.unpack(SIZES[opts.size or "xs"])
    local track = W - 16
    local hi = opts.value or state("m3_slider_" .. id, 0.5)
    local lo = kind == "range" and (opts.low or state("m3_slider_low_" .. id, 0.25)) or nil
    local steps = kind == "discrete" and (opts.steps or 5) or nil
    local format = opts.format or function(v) return tostring(math.floor(v * 100 + 0.5)) end
    ---@type StateSignal<integer>
    local held = state("m3_slider_held_" .. id, 0)
    local grab = 1
    local function snap(v)
        v = clamp(v, 0, 1)
        return steps and math.floor(v * steps + 0.5) / steps or v
    end
    local function seek(_, pointer, phase)
        local v = snap((pointer.x - 8) / track)
        if lo then
            if phase == "start" then
                grab = math.abs(v - lo:get()) < math.abs(v - hi:get()) and 1 or 2
            end
            if grab == 1 then
                lo:set(math.min(v, hi:get() - 0.04))
            else
                hi:set(math.max(v, lo:get() + 0.04))
            end
        else
            hi:set(v)
        end
        held:set(phase == "end" and 0 or grab)
    end

    local ends
    if lo then
        ends = computed({ lo, hi }, function(a, b) return { a or 0, b or 1 } end)
    elseif kind == "centered" then
        ends = hi:map(function(v) return { math.min(0.5, v or 0.5), math.max(0.5, v or 0.5) } end)
    else
        ends = hi:map(function(v) return { 0, v or 0 } end)
    end
    local plain = not lo and kind ~= "centered"
    local segs = ends:map(function(e)
        local l, r = plain and 0 or e[1] * track + 8, e[2] * track + 8
        local gl, gr = lo ~= nil or (kind == "centered" and e[1] < 0.5), kind ~= "centered" or e[1] >= 0.5
        local x1, x2, x3, x4 = l - (gl and 8 or 0), l + (gl and 8 or 0), r - (gr and 8 or 0), r + (gr and 8 or 0)
        local ci, ca = gl and 2 or 0, gr and 2 or 0
        return {
            { x = 0, w = math.max(x1, 0), r = { top_left = R, bottom_left = R, top_right = ci, bottom_right = ci } },
            { x = x2, w = math.max(x3 - x2, 0), r = { top_left = plain and R or ci, bottom_left = plain and R or ci, top_right = ca, bottom_right = ca } },
            { x = x4, w = math.max(W - x4, 0), r = { top_left = ca, bottom_left = ca, top_right = R, bottom_right = R } },
        }
    end)
    local layers = {}
    for i, color in ipairs({ c.secondary_container, c.primary, c.secondary_container }) do
        layers[i] = rect {
            width = segs:map(function(g) return g[i].w end),
            height = H,
            radius = segs:map(function(g) return g[i].r end),
            align_v = "center",
            background = color,
            translate = segs:map(function(g) return { x = g[i].x } end),
            animate = { width = SLIDE, translate = SLIDE, radius = SLIDE, background = FADE },
        }
    end
    for i = 0, steps or -1 do
        local f = i / steps
        layers[#layers + 1] = rect {
            width = 4,
            height = 4,
            radius = 2,
            align_v = "center",
            margin = { left = f * track + 6 },
            background = computed({ ends, theme.scheme }, function(e, s)
                return f >= e[1] - 1e-6 and f <= e[2] + 1e-6 and s.on_primary or s.on_secondary_container
            end),
        }
    end
    local thumbs = lo and { lo, hi } or { hi }
    local bubbles = {}
    for i, thumb in ipairs(thumbs) do
        layers[#layers + 1] = rect {
            width = 4,
            height = HANDLE,
            radius = 2,
            background = c.primary,
            translate = thumb:map(function(v) return { x = (v or 0) * track + 6 } end),
            animate = { translate = SLIDE, background = FADE },
        }
        bubbles[i] = rect {
            width = 48,
            height = 44,
            radius = 22,
            background = c.inverse_surface,
            translate = thumb:map(function(v) return { x = (v or 0) * track + 8 - 24 } end),
            origin = { x = 0.5, y = 1 },
            scale = held:map(function(h) return h == i and 1 or 0 end),
            animate = { translate = SLIDE, scale = motion.spatial, background = FADE },
            children = { text(thumb:map(function(v) return format(v or 0) end), c.inverse_on_surface, "label_large", { align_h = "center" }) },
        }
    end
    return column {
        spacing = 4,
        children = {
            rect { width = W, height = 44, children = bubbles },
            rect {
                width = W,
                height = HANDLE,
                on_drag = seek,
                on_wheel = not lo and function(_, wheel) hi:set(snap(hi:get() + wheel * (steps and 1 / steps or 0.05))) end or nil,
                children = layers,
            },
        },
    }
end

return M
