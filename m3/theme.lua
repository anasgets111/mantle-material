-- Live M3 tokens: the engine's `palette.scheme` turns the seed, mode and variant states into the
-- M3 roles, and `c.<role>` is a signal of one role, so every node bound to it recolours in place.
local M = {}

M.SEEDS = {
    { name = "Violet", color = "#6750A4" },
    { name = "Blue", color = "#4285F4" },
    { name = "Teal", color = "#00796B" },
    { name = "Green", color = "#386A20" },
    { name = "Amber", color = "#B68A00" },
    { name = "Rose", color = "#B3261E" },
}
M.VARIANTS = { "tonal_spot", "vibrant", "expressive", "fidelity", "monochrome" }

M.seed = state("m3_seed_color", "#6750A4")
M.dark = state("m3_dark", true)
M.variant = state("m3_variant", "tonal_spot")

M.scheme = computed({ M.seed, M.dark, M.variant }, function(seed, dark, variant)
    return palette.scheme(seed or M.SEEDS[1].color, { dark = dark ~= false, variant = variant })
end)

M.c = setmetatable({}, {
    __index = function(roles, role)
        local signal = M.scheme:map(function(scheme) return scheme[role] end)
        rawset(roles, role, signal)
        return signal
    end,
})

-- A role chosen by a boolean signal: `pick(on, "primary", "outline")`.
function M.pick(flag, yes, no)
    return computed({ flag, M.scheme }, function(on, scheme)
        return scheme[on and yes or no] or yes
    end)
end

M.CLEAR = "#00000000"

-- M3 type scale: { role, size, line height, weight, tracking }, and `M.type[role]` as
-- { size, weight, line height, tracking }.
M.type = {}
M.TYPE_SCALE = {
    { "display_large", 57, 64, 400, -0.25 }, { "display_medium", 45, 52, 400, 0 }, { "display_small", 36, 44, 400, 0 },
    { "headline_large", 32, 40, 400, 0 }, { "headline_medium", 28, 36, 400, 0 }, { "headline_small", 24, 32, 400, 0 },
    { "title_large", 22, 28, 400, 0 }, { "title_medium", 16, 24, 500, 0.15 }, { "title_small", 14, 20, 500, 0.1 },
    { "body_large", 16, 24, 400, 0.5 }, { "body_medium", 14, 20, 400, 0.25 }, { "body_small", 12, 16, 400, 0.4 },
    { "label_large", 14, 20, 500, 0.1 }, { "label_medium", 12, 16, 500, 0.5 }, { "label_small", 11, 16, 500, 0.5 },
}
for _, style in ipairs(M.TYPE_SCALE) do
    M.type[style[1]] = { style[2], style[4], style[3], style[5] }
end

-- M3 Expressive motion scheme: springs from the Compose tokens, damping = ratio * 2 * sqrt(stiffness).
local function spring(stiffness, ratio)
    return { spring = { stiffness = stiffness, damping = ratio * 2 * math.sqrt(stiffness) } }
end
M.motion = {
    spatial_fast = spring(800, 0.6),
    spatial = spring(380, 0.8),
    spatial_slow = spring(200, 0.8),
    effects_fast = spring(3800, 1),
    effects = spring(1600, 1),
    effects_slow = spring(800, 1),
    fade = { duration = 300, easing = "in_out_quad" },
}

-- M3 easing tokens, as CSS cubic-beziers.
M.easing = {
    standard = { 0.2, 0, 0, 1 },
    standard_decelerate = { 0, 0, 0, 1 },
    standard_accelerate = { 0.3, 0, 1, 1 },
    emphasized_decelerate = { 0.05, 0.7, 0.1, 1 },
    emphasized_accelerate = { 0.3, 0, 0.8, 0.15 },
}

-- `color` at `alpha` (0..1), for M3's scrim and state-layer opacities.
function M.alpha(color, alpha)
    return color:sub(1, 7) .. string.format("%02X", math.floor(alpha * 255 + 0.5))
end

-- M3 elevation levels 0..5 (0, 1, 3, 6, 8, 12 dp): a 30% key shadow over a 15% ambient one, from the
-- M3 elevation tokens. Spread onto a node's props; `M.shadows[n]` is the bare list, for binding.
local function level(key_y, key_blur, y, blur, spread)
    return {
        { color = "#0000004D", blur = key_blur, offset = { y = key_y } },
        { color = "#00000026", blur = blur, offset = { y = y }, spread = spread },
    }
end
M.shadows = {
    [0] = {},
    [1] = level(1, 2, 1, 3, 1),
    [2] = level(1, 2, 2, 6, 2),
    [3] = level(1, 3, 4, 8, 3),
    [4] = level(2, 3, 6, 10, 4),
    [5] = level(4, 4, 8, 12, 6),
}
M.elevation = {}
for n, shadows in pairs(M.shadows) do
    M.elevation[n] = { shadows = shadows }
end

return M
