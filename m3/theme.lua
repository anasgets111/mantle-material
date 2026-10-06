-- Live M3 tokens: the engine's `palette.scheme` turns the seed, appearance, variant and contrast
-- (each following the desktop unless set) into the M3 roles, and `c.<role>` is a signal of one role, so every node bound to it recolours in place.
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

-- The app's choices; "system" follows the desktop's settings (`mantle.appearance`, the portal's).
---@type StateSignal<string> A "#RRGGBB" seed, or "system" for the desktop's accent (else the first of `SEEDS`).
M.seed = state("m3_seed_color", "system")
---@type StateSignal<"system"|"light"|"dark">
M.appearance = state("m3_appearance", "system")
---@type StateSignal<"tonal_spot"|"vibrant"|"expressive"|"fidelity"|"monochrome">
M.variant = state("m3_variant", "tonal_spot")
---@type StateSignal<"system"|number> "system" or -1..1: M3's contrast levels (-1 reduced, 0 standard, 0.5 medium, 1 high).
M.contrast = state("m3_contrast", "system")

-- Whether the colours are dark: the choice, else the desktop's preference (none is light).
---@type Signal<boolean>
M.dark = computed({ M.appearance, mantle.appearance }, function(choice, sys)
    if choice == "light" or choice == "dark" then
        return choice == "dark"
    end
    return sys ~= nil and sys.color_scheme == "dark"
end)
---@type Signal<boolean>
M.reduced_motion = mantle.appearance:map(function(sys) return sys ~= nil and sys.reduced_motion == true end)

-- Built once per combination: a scheme change re-reads every role, so it must stay cheap.
local schemes = {}
M.scheme = computed({ M.seed, M.dark, M.variant, M.contrast, mantle.appearance }, function(seed, dark, variant, contrast, sys)
    if seed == "system" then
        local accent = sys and sys.accent
        seed = accent and accent:match("^#%x%x%x%x%x%x$") and accent or M.SEEDS[1].color
    end
    if contrast == "system" then
        contrast = sys and sys.contrast == "high" and 1 or 0
    end
    local key = ("%s|%s|%s|%s"):format(seed, tostring(dark), variant, contrast)
    schemes[key] = schemes[key] or palette.scheme(seed, { dark = dark, variant = variant, contrast = contrast })
    return schemes[key]
end)

-- Flips light and dark from what shows now.
function M.toggle_dark()
    M.appearance:set(M.dark:get() and "light" or "dark")
end

-- The next of `SEEDS` after the current one (the first when it is none of them).
function M.next_seed()
    local at = 0
    for i, seed in ipairs(M.SEEDS) do
        if seed.color == M.seed:get() then
            at = i
        end
    end
    M.seed:set(M.SEEDS[at % #M.SEEDS + 1].color)
end

-- The shared roles every library of the unified API answers to, from the scheme and `dark`: they sit
-- beside the native roles (`background` aliases `surface`).
local SHARED = {
    accent = "primary", on_accent = "on_primary", text = "on_surface", text_secondary = "on_surface_variant",
    background = "surface", container = "surface_container", container_raised = "surface_container_high", separator = "outline_variant",
}
local STATUS = { success = { "#2E7D32", "#81C784" }, warning = { "#B26A00", "#FFB74D" } }

M.c = setmetatable({}, {
    __index = function(roles, role)
        local signal
        if role == "text_disabled" then
            signal = M.scheme:map(function(scheme) return M.alpha(scheme.on_surface, 0.38) end)
        elseif STATUS[role] then
            signal = M.dark:map(function(dark) return STATUS[role][dark and 2 or 1] end)
        else
            local native = SHARED[role] or role
            signal = M.scheme:map(function(scheme) return scheme[native] end)
        end
        rawset(roles, role, signal)
        return signal
    end,
})

-- A role chosen by a boolean signal: `pick(on, "primary", "outline")`.
---@param flag Signal<boolean>
---@param yes string Colour role when `flag` is true.
---@param no string Colour role otherwise.
---@return Signal<string>
function M.pick(flag, yes, no)
    return computed({ flag, M.scheme }, function(on, scheme)
        return scheme[on and yes or no] or yes
    end)
end

M.CLEAR = "#00000000"

-- M3 type scale (the 15 styles, then their `_emphasized` variants): { role, size, line height, weight, tracking }, and `M.type[role]` as
-- { size, weight, line height, tracking }.
M.type = {}
M.TYPE_SCALE = {
    { "display_large", 57, 64, 400, -0.25 }, { "display_medium", 45, 52, 400, 0 }, { "display_small", 36, 44, 400, 0 },
    { "headline_large", 32, 40, 400, 0 }, { "headline_medium", 28, 36, 400, 0 }, { "headline_small", 24, 32, 400, 0 },
    { "title_large", 22, 28, 400, 0 }, { "title_medium", 16, 24, 500, 0.15 }, { "title_small", 14, 20, 500, 0.1 },
    { "body_large", 16, 24, 400, 0.5 }, { "body_medium", 14, 20, 400, 0.25 }, { "body_small", 12, 16, 400, 0.4 },
    { "label_large", 14, 20, 500, 0.1 }, { "label_medium", 12, 16, 500, 0.5 }, { "label_small", 11, 16, 500, 0.5 },
}
-- M3 Expressive's emphasized variant of each style: the same size, line height and tracking, heavier.
-- not in the spec: the weights are Compose's emphasized tokens as recalled, 500 for display, headline,
-- title large and body, 700 for title medium and small and the labels.
local EMPHASIZED = { title_medium = 700, title_small = 700, label_large = 700, label_medium = 700, label_small = 700 }
for i = 1, #M.TYPE_SCALE do
    local s = M.TYPE_SCALE[i]
    M.TYPE_SCALE[#M.TYPE_SCALE + 1] = { s[1] .. "_emphasized", s[2], s[3], EMPHASIZED[s[1]] or 500, s[5] }
end
for _, style in ipairs(M.TYPE_SCALE) do
    M.type[style[1]] = { style[2], style[4], style[3], style[5] }
end
-- The shared type styles of the unified API, beside the native ones.
M.type.title, M.type.headline, M.type.body, M.type.label, M.type.caption =
    M.type.title_large, M.type.headline_small, M.type.body_medium, M.type.label_large, M.type.body_small

-- M3 Expressive motion scheme: springs from the Compose tokens, damping = ratio * 2 * sqrt(stiffness).
-- Reduced motion swaps every spring for a quick critically damped one (not in the spec): the entry's
-- `spring` is a signal, so it can't be read with `.stiffness`; `M.springs` has the plain numbers.
local QUICK = { stiffness = 2500, damping = 100 }
M.springs = {}
local function spring(name, stiffness, ratio)
    local own = { stiffness = stiffness, damping = ratio * 2 * math.sqrt(stiffness) }
    M.springs[name] = own
    return { spring = M.reduced_motion:map(function(reduced) return reduced and QUICK or own end) }
end
M.motion = {
    spatial_fast = spring("spatial_fast", 800, 0.6),
    spatial = spring("spatial", 380, 0.8),
    spatial_slow = spring("spatial_slow", 200, 0.8),
    effects_fast = spring("effects_fast", 3800, 1),
    effects = spring("effects", 1600, 1),
    effects_slow = spring("effects_slow", 800, 1),
    fade = { duration = 300, easing = "in_out_quad" },
}
-- The shared motion names of the unified API, beside the native ones.
M.motion.fast, M.motion.default, M.motion.slow = M.motion.spatial_fast, M.motion.spatial, M.motion.spatial_slow
-- Wheel notches glide on a critically damped spring: Expressive spatial springs overshoot.
M.motion.scroll = M.motion.effects

-- M3 easing tokens, as CSS cubic-beziers.
M.easing = {
    standard = { 0.2, 0, 0, 1 },
    standard_decelerate = { 0, 0, 0, 1 },
    standard_accelerate = { 0.3, 0, 1, 1 },
    emphasized_decelerate = { 0.05, 0.7, 0.1, 1 },
    emphasized_accelerate = { 0.3, 0, 0.8, 0.15 },
}

-- `color` at `alpha` (0..1), for M3's scrim and state-layer opacities.
---@param color string "#RRGGBB[AA]"
---@param alpha number 0..1
---@return string
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
