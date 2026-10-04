-- M3 Expressive shape library. Every shape is one closed outline of the same N cubic segments,
-- so `animate.commands` morphs any shape into any other point by point.
local M = {}

local N = 72
local TAU = 2 * math.pi

local function circle() return 1 end
local function lobes(count, base, amp, pointy)
    return function(a)
        local phase = (a * count / TAU) % 1
        local wave = pointy and 1 - 2 * math.abs(2 * phase - 1) or math.cos(a * count)
        return base + amp * wave
    end
end

local function polygon(sides, mix)
    return function(a)
        local sector = TAU / sides
        local local_a = (a + math.pi / 2) % sector - sector / 2
        return (1 - mix) * math.cos(math.pi / sides) / math.cos(local_a) + mix
    end
end

local function superellipse(rx, ry, power)
    return function(a)
        local cs, sn = math.cos(a), math.sin(a)
        local r = (math.abs(cs / rx) ^ power + math.abs(sn / ry) ^ power) ^ (-1 / power)
        return r
    end
end

-- Each entry maps an angle to a point, in any scale; `unit` recentres and fits it to [-1, 1].
local function polar(radius)
    return function(a) return radius(a) * math.cos(a), radius(a) * math.sin(a) end
end

local round_rect = superellipse(1, 1, 5)
local DEFS = {
    circle = polar(circle),
    square = polar(round_rect),
    slanted = function(a)
        local r = round_rect(a)
        return r * math.cos(a) + 0.28 * r * math.sin(a), r * math.sin(a)
    end,
    arch = function(a)
        local cs, sn = math.cos(a), math.sin(a)
        if sn < 0 then
            return cs, sn
        end
        local r = round_rect(a)
        return r * cs, r * sn
    end,
    semicircle = function(a)
        local sn = math.sin(a)
        local r = sn > 0.35 and 0.35 / sn or 1
        return r * math.cos(a), r * sn
    end,
    pentagon = polar(polygon(5, 0.3)),
    pill = polar(superellipse(1, 0.55, 5)),
    oval = polar(superellipse(1, 0.72, 2)),
    sunny = polar(lobes(8, 0.9, 0.1, true)),
    very_sunny = polar(lobes(8, 0.76, 0.24, true)),
    cookie_4 = polar(lobes(4, 1, 0.1)),
    cookie_6 = polar(lobes(6, 1, 0.06)),
    cookie_7 = polar(lobes(7, 1, 0.055)),
    cookie_9 = polar(lobes(9, 1, 0.045)),
    cookie_12 = polar(lobes(12, 1, 0.03)),
    clover_4 = polar(lobes(4, 0.66, 0.34)),
    clover_8 = polar(lobes(8, 0.76, 0.24)),
    burst = polar(lobes(12, 0.8, 0.2, true)),
    soft_burst = polar(lobes(10, 0.9, 0.08, true)),
    puffy = polar(function(a) return 0.8 + 0.2 * math.abs(math.cos(a * 4)) ^ 0.6 end),
    flower = polar(function(a) return 0.62 + 0.38 * math.abs(math.cos(a * 2.5)) ^ 0.7 end),
    heart = function(a)
        local s = math.sin(a)
        return s ^ 3 * 16, -(13 * math.cos(a) - 5 * math.cos(2 * a) - 2 * math.cos(3 * a) - math.cos(4 * a))
    end,
}

-- N points of `name` on the unit square, centred on its bounding box, largest extent 1 either side.
local points = {}
local function unit(name)
    if points[name] then
        return points[name]
    end
    local xs, ys, x0, x1, y0, y1 = {}, {}, math.huge, -math.huge, math.huge, -math.huge
    for i = 1, N do
        local x, y = DEFS[name]((i - 1) * TAU / N)
        xs[i], ys[i] = x, y
        x0, x1, y0, y1 = math.min(x0, x), math.max(x1, x), math.min(y0, y), math.max(y1, y)
    end
    local cx, cy, k = (x0 + x1) / 2, (y0 + y1) / 2, 2 / math.max(x1 - x0, y1 - y0)
    for i = 1, N do
        xs[i], ys[i] = (xs[i] - cx) * k, (ys[i] - cy) * k
    end
    points[name] = { xs = xs, ys = ys }
    return points[name]
end

local cache = {}

-- Closed commands of `name` fitting a `size` box: a Catmull-Rom spline through the N points,
-- as N cubic segments. `rotate` is in degrees clockwise.
function M.commands(name, size)
    local key = name .. size
    if cache[key] then
        return cache[key]
    end
    local p = unit(name)
    local half = size / 2
    local function at(i)
        i = (i - 1) % N + 1
        return half + p.xs[i] * half, half + p.ys[i] * half
    end
    local x, y = at(1)
    local commands = { { op = "M", points = { x, y } } }
    for i = 1, N do
        local x0, y0 = at(i - 1)
        local x1, y1 = at(i)
        local x2, y2 = at(i + 1)
        local x3, y3 = at(i + 2)
        commands[#commands + 1] = {
            op = "C",
            points = { x1 + (x2 - x0) / 6, y1 + (y2 - y0) / 6, x2 - (x3 - x1) / 6, y2 - (y3 - y1) / 6, x2, y2 },
        }
    end
    commands[#commands + 1] = { op = "Z", points = {} }
    cache[key] = commands
    return commands
end

M.NAMES = {
    "circle", "square", "slanted", "arch", "semicircle", "pentagon", "pill", "oval", "sunny", "very_sunny",
    "cookie_4", "cookie_6", "cookie_7", "cookie_9", "cookie_12", "clover_4", "clover_8", "burst", "soft_burst",
    "puffy", "flower", "heart",
}

return M
