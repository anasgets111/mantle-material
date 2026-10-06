-- M3 slider: three track segments (inactive, active, inactive) split around each 4px handle by a 6px
-- gap with 2px inner corners, optional ticks, and a value bubble over a held handle.
local theme = require("m3.theme")
local core = require("m3.core")

local c, motion = theme.c, theme.motion
local text, icon = core.text, core.icon
local FADE = motion.fade

local M = {}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local SLIDE = { duration = 120, easing = "out_cubic" }
local SIZES = { xs = { 16, 44, 8 }, s = { 24, 44, 8 }, m = { 40, 44, 12 }, l = { 56, 68, 16 }, xl = { 96, 108, 28 } }

-- Slider over 0..1; a bubble shows the value over a held handle.
---@class m3.SliderOpts
---@field kind? "continuous"|"discrete"|"range"|"centered" Default "continuous".
---@field value? StateSignal<number> 0..1, the high thumb of a range; default own, 0.5.
---@field low? StateSignal<number> The range's low thumb; default own, 0.25.
---@field size? m3.Size Default "xs".
---@field steps? integer Divisions and ticks (discrete); default 5.
---@field width? number Length along the track, the height of a vertical one. Default 300.
---@field vertical? boolean Bottom to top; the bubble sits to the right. Not in the spec's compact sizes: pair with "m" or larger.
---@field icon? string Leading icon in the track, from size "m" up; not with range or centered.
---@field label? string Accessible name; default the id.
---@field format? fun(v: number): string Bubble text; default the percentage.
---@field [string] "no such property"

---@param id string
---@param opts? m3.SliderOpts
---@return Node
function M.slider(id, opts)
    opts = opts or {}
    local kind = opts.kind or "continuous"
    local W = opts.width or 300
    local H, HANDLE, R = table.unpack(SIZES[opts.size or "xs"])
    local vertical = opts.vertical
    local track = W - 16
    -- A box `len` long on the slider's axis and `thick` across it.
    local function box(len, thick)
        return { width = vertical and thick or len, height = vertical and len or thick }
    end
    -- A v-space offset `x` of a `w`-long piece, as a translate: v runs left to right, or up from the bottom.
    local function at(x, w) return vertical and { y = W - x - w } or { x = x } end
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
    local function put(is_low, v)
        v = snap(v)
        if is_low and lo then
            lo:set(math.min(v, hi:get() - 0.04))
        elseif lo then
            hi:set(math.max(v, lo:get() + 0.04))
        else
            hi:set(v)
        end
    end
    local function seek(_, pointer, phase)
        local v = snap(((vertical and W - pointer.y or pointer.x) - 8) / track)
        if lo and phase == "start" then
            grab = math.abs(v - lo:get()) < math.abs(v - hi:get()) and 1 or 2
        end
        put(grab == 1, v)
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
            width = vertical and H or segs:map(function(g) return g[i].w end),
            height = vertical and segs:map(function(g) return g[i].w end) or H,
            radius = segs:map(function(g)
                local r = g[i].r
                return vertical and { bottom_left = r.top_left, bottom_right = r.top_left, top_left = r.top_right, top_right = r.top_right } or r
            end),
            align_h = vertical and "center" or nil,
            align_v = not vertical and "center" or nil,
            background = color,
            translate = segs:map(function(g) return at(g[i].x, g[i].w) end),
            animate = { width = SLIDE, height = SLIDE, translate = SLIDE, radius = SLIDE, background = FADE },
        }
    end
    for i = 0, steps or -1 do
        local f = i / steps
        layers[#layers + 1] = rect {
            width = 4,
            height = 4,
            radius = 2,
            align_h = vertical and "center" or nil,
            align_v = not vertical and "center" or nil,
            margin = vertical and { top = W - (f * track + 6) - 4 } or { left = f * track + 6 },
            background = computed({ ends, theme.scheme }, function(e, s)
                return f >= e[1] - 1e-6 and f <= e[2] + 1e-6 and s.on_primary or s.on_secondary_container
            end),
        }
    end
    local thumbs = lo and { lo, hi } or { hi }
    local bubbles = {}
    if opts.icon and plain and H >= 40 then
        layers[#layers + 1] = icon(opts.icon, computed({ hi, theme.scheme }, function(v, s) return (v or 0) * track > 28 and s.on_primary or s.on_secondary_container end), 24, {
            align_h = vertical and "center" or nil,
            align_v = not vertical and "center" or "end",
            margin = vertical and { bottom = 12 } or { left = 12 },
            hittable = false,
        })
    end
    local step, big = steps and 1 / steps or 0.01, steps and 1 / steps or 0.1
    local jump = { Left = -step, Down = -step, Right = step, Up = step, Page_Down = -big, Page_Up = big }
    for i, thumb in ipairs(thumbs) do
        local low = lo ~= nil and i == 1
        layers[#layers + 1] = rect(core.merge(box(4, HANDLE), {
            radius = 2,
            background = c.primary,
            translate = thumb:map(function(v) return at((v or 0) * track + 6, 4) end),
            animate = { translate = SLIDE, background = FADE },
        }))
        -- Keyboard: arrows step, Page keys leap, Home and End go to the ends.
        layers[#layers + 1] = rect(core.merge(box(20, HANDLE), {
            radius = 4,
            hittable = false,
            accessible_name = (opts.label or id) .. (lo and (low and " (low)" or " (high)") or ""),
            translate = thumb:map(function(v) return at((v or 0) * track + 8 - 10, 20) end),
            animate = { translate = SLIDE },
            on_key = function(key)
                local v = thumb:get() or 0
                if jump[key.name] then
                    put(low, v + jump[key.name])
                elseif key.name == "Home" or key.name == "End" then
                    put(low, key.name == "Home" and 0 or 1)
                else
                    return false
                end
                return true
            end,
        }))
        bubbles[i] = rect {
            width = 48,
            height = 44,
            radius = 22,
            background = c.inverse_surface,
            translate = thumb:map(function(v)
                v = v or 0
                return vertical and { x = 4, y = W - v * track - 8 - 22 } or { x = v * track + 8 - 24 }
            end),
            origin = { x = vertical and 0 or 0.5, y = vertical and 0.5 or 1 },
            scale = held:map(function(h) return h == i and 1 or 0 end),
            animate = { translate = SLIDE, scale = motion.spatial, background = FADE },
            children = { text(thumb:map(function(v) return format(v or 0) end), c.inverse_on_surface, "label_large", { align_h = "center" }) },
        }
    end
    -- The bubble floats over the handle and takes no room in the layout: a zero-thick layer whose
    -- bubbles paint past it, beside the track (vertical) or above it.
    local bubble_layer = rect(vertical
        and { width = 0, height = W, translate = { x = HANDLE + 4, y = 0 }, hittable = false, children = { rect { width = 56, height = W, children = bubbles } } }
        or { width = W, height = 0, translate = { x = 0, y = -48 }, hittable = false, children = { rect { width = W, height = 44, children = bubbles } } })
    local track_box = rect(core.merge(box(W, HANDLE), {
        on_drag = seek,
        on_wheel = not lo and function(_, wheel) hi:set(snap(hi:get() + wheel * (steps and 1 / steps or 0.05))) end or nil,
        children = layers,
    }))
    return rect { children = { track_box, bubble_layer } }
end

return M
