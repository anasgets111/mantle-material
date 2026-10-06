-- Styles, in tabs: colour (seed, variant, roles), wallpaper extraction, type, shape and motion.
local m3 = require("m3")
local section = require("demo.section")

local theme = m3.theme
local c, FADE = theme.c, theme.motion.fade

-- A seed colour to pick, checked while it is the seed.
local function seed_swatch(name, color)
    local selected = theme.seed:map(function(s) return s == color end)
    return m3.interactive("seed_" .. name, {
        width = 48,
        height = 48,
        radius = 24,
        background = color,
        border_width = selected:map(function(on) return on and 3 or 0 end),
        border_color = c.on_surface,
        animate = { border_width = { duration = 150 } },
        on_click = function() theme.seed:set(color) end,
        accessible_name = name,
    }, "#ffffff", m3.icon("check", "#ffffff", 24, {
        align_h = "center",
        opacity = selected:map(function(on) return on and 1 or 0 end),
        animate = { opacity = { duration = 150 } },
    }))
end

local PAIRS = {
    { "primary", "on_primary" },
    { "primary_container", "on_primary_container" },
    { "secondary", "on_secondary" },
    { "secondary_container", "on_secondary_container" },
    { "tertiary", "on_tertiary" },
    { "tertiary_container", "on_tertiary_container" },
    { "error", "on_error" },
    { "error_container", "on_error_container" },
    { "surface_container_highest", "on_surface" },
    { "inverse_surface", "inverse_on_surface" },
}

local function role_tile(pair)
    return rect {
        width = "fill",
        height = 72,
        radius = 12,
        padding = 12,
        background = c[pair[1]],
        animate = { background = FADE },
        children = { m3.text(pair[1]:gsub("_", " "), c[pair[2]], "label_large", { align_v = "end" }) },
    }
end

local swatches, tiles = {}, {}
for i, seed in ipairs(theme.SEEDS) do
    swatches[i] = seed_swatch(seed.name, seed.color)
end
for i = 1, #PAIRS, 2 do
    tiles[#tiles + 1] = row { width = "fill", spacing = 12, children = { role_tile(PAIRS[i]), role_tile(PAIRS[i + 1]) } }
end
local color_page = column {
    width = "fill",
    spacing = 16,
    children = {
        section.card("Seed", { row { spacing = 16, children = swatches } }),
        section.card("Variant", { m3.segmented_button("variant", { options = theme.VARIANTS, value = theme.variant, width = 120 }) }),
        section.card("Roles", tiles),
    },
}

local type_rows = {}
for i, t in ipairs(theme.TYPE_SCALE) do
    type_rows[i] = row {
        width = "fill",
        spacing = 24,
        children = {
            column {
                width = 200,
                align_v = "center",
                children = {
                    m3.text(t[1]:gsub("_", " "), c.on_surface, "label_large"),
                    m3.text(string.format("%d / %d  w%d  %+.2f", t[2], t[3], t[4], t[5]), c.on_surface_variant, "label_medium"),
                },
            },
            text {
                content = "Quick brown fox",
                align_v = "center",
                font_size = t[2],
                line_height = t[3] / t[2],
                font_weight = t[4],
                letter_spacing = t[5],
                foreground = c.on_surface,
                animate = { foreground = FADE },
            },
        },
    }
end
local type_page = column {
    width = "fill",
    spacing = 16,
    children = {
        section.card("Type scale", { table.unpack(type_rows, 1, 15) }),
        section.card("Emphasized type scale", { table.unpack(type_rows, 16) }),
    },
}

-- M3 corner radius scale, in dp.
local SHAPES = {
    { "None", 0 }, { "Extra small", 4 }, { "Small", 8 }, { "Medium", 12 }, { "Large", 16 },
    { "Large increased", 20 }, { "Extra large", 28 }, { "Extra large increased", 32 }, { "Extra extra large", 48 }, { "Full", 999 },
}
local function shape_tile(shape)
    return column {
        width = 128,
        spacing = 8,
        children = {
            rect {
                width = "fill",
                height = 128,
                radius = shape[2],
                background = c.primary_container,
                animate = { background = FADE },
                children = { m3.text(shape[2] == 999 and "full" or tostring(shape[2]), c.on_primary_container, "title_medium", { align_h = "center" }) },
            },
            m3.text(shape[1], c.on_surface_variant, "label_medium", { align_h = "center" }),
        },
    }
end
local shape_rows = {}
for i = 1, #SHAPES, 5 do
    local tiles_in_row = {}
    for j = i, i + 4 do
        tiles_in_row[#tiles_in_row + 1] = shape_tile(SHAPES[j])
    end
    shape_rows[#shape_rows + 1] = row { spacing = 16, children = tiles_in_row }
end
local morphed = state("m3_shape_morph", false)
local shape_page = column {
    width = "fill",
    spacing = 16,
    children = {
        section.card("Corner radius scale", shape_rows),
        section.card("Shape morph", {
            m3.text("Expressive shapes change corner on a spring: press the tile.", c.on_surface_variant, "body_medium"),
            rect {
                width = 96,
                height = 96,
                radius = morphed:map(function(on) return on and 48 or 16 end),
                rotate = morphed:map(function(on) return on and 90 or 0 end),
                background = c.tertiary_container,
                on_click = function() morphed:set(not morphed:get()) end,
                accessible_name = "Morph shape",
                animate = { radius = theme.motion.spatial, rotate = theme.motion.spatial, background = FADE },
            },
        }),
    },
}

-- Motion: one play state drives every dot, so each token is compared over the same run.
local go = state("m3_motion_go", false)
local TRACK = 400
local function lane(name, detail, motion_spec, extra)
    return row {
        width = "fill",
        spacing = 24,
        children = {
            column {
                width = 200,
                align_v = "center",
                children = { m3.text(name, c.on_surface, "label_large"), m3.text(detail, c.on_surface_variant, "label_medium") },
            },
            rect {
                width = TRACK + 16,
                height = 16,
                radius = 8,
                align_v = "center",
                background = c.surface_container_highest,
                animate = { background = FADE },
                children = {
                    rect {
                        width = 16,
                        height = 16,
                        radius = 8,
                        background = c.primary,
                        translate = go:map(function(on) return { x = on and TRACK or 0 } end),
                        animate = { translate = motion_spec, background = FADE },
                    },
                },
            },
            extra or rect { width = 1, height = 1 },
        },
    }
end

local SPRINGS = {
    { "Spatial fast", "spatial_fast" }, { "Spatial default", "spatial" }, { "Spatial slow", "spatial_slow" },
    { "Effects fast", "effects_fast" }, { "Effects default", "effects" }, { "Effects slow", "effects_slow" },
}
local spring_lanes = {}
for i, sp in ipairs(SPRINGS) do
    local spring = theme.springs[sp[2]]
    spring_lanes[i] = lane(sp[1], string.format("stiffness %d, damping ratio %.1f", spring.stiffness, spring.damping / (2 * math.sqrt(spring.stiffness))), theme.motion[sp[2]])
end

local EASINGS = {
    { "Standard", "0.2, 0, 0, 1", theme.easing.standard },
    { "Emphasized decelerate", "0.05, 0.7, 0.1, 1", theme.easing.emphasized_decelerate },
    { "Emphasized accelerate", "0.3, 0, 0.8, 0.15", theme.easing.emphasized_accelerate },
    { "Standard decelerate", "0, 0, 0, 1", theme.easing.standard_decelerate },
    { "Standard accelerate", "0.3, 0, 1, 1", theme.easing.standard_accelerate },
}
local function curve(e)
    local x1, y1, x2, y2 = table.unpack(e)
    return path {
        width = 48,
        height = 48,
        stroke = c.primary,
        stroke_width = 2,
        commands = {
            { op = "M", points = { 4, 44 } },
            { op = "C", points = { 4 + 40 * x1, 44 - 40 * y1, 4 + 40 * x2, 44 - 40 * y2, 44, 4 } },
        },
    }
end
local easing_lanes = {}
for i, e in ipairs(EASINGS) do
    easing_lanes[i] = lane(e[1], "cubic-bezier(" .. e[2] .. ")", { duration = 600, easing = e[3] }, curve(e[3]))
end

local motion_page = column {
    width = "fill",
    spacing = 16,
    children = {
        section.card("Play", {
            m3.text("Every dot below runs on the same trigger; press again to run it back.", c.on_surface_variant, "body_medium"),
            m3.button("motion_play", { kind = "filled", label = "Play", icon = "play_arrow", on_click = function() go:set(not go:get()) end }),
        }),
        section.card("Springs", spring_lanes),
        section.card("Easing curves (600 ms)", easing_lanes),
    },
}

local function elevation_tile(level)
    return m3.merge(rect {
        width = "fill",
        height = 96,
        radius = 12,
        background = c.surface_container_high,
        animate = { background = FADE },
    }, theme.elevation[level])
end

local ELEVATION_DP = { [0] = 0, 1, 3, 6, 8, 12 }
local level_tiles = {}
for level = 0, 5 do
    level_tiles[level + 1] = column {
        width = 128,
        spacing = 12,
        children = {
            elevation_tile(level),
            m3.text("Level " .. level, c.on_surface, "label_large", { align_h = "center" }),
            m3.text(ELEVATION_DP[level] .. " dp", c.on_surface_variant, "label_medium", { align_h = "center" }),
        },
    }
end

-- State layer and disabled opacities: `ink` over the surface.
local STATES = { { "Hover", 0.08 }, { "Focus", 0.10 }, { "Pressed", 0.10 }, { "Dragged", 0.16 }, { "Disabled content", 0.38 }, { "Disabled container", 0.12 } }
local function layer_tile(label, opacity, ink)
    return column {
        width = 128,
        spacing = 8,
        children = {
            rect {
                width = "fill",
                height = 64,
                radius = 12,
                background = c.surface_container_highest,
                animate = { background = FADE },
                children = { rect { width = "fill", height = "fill", background = ink:map(function(color) return theme.alpha(color, opacity) end) } },
                clip = "rounded",
            },
            m3.text(label, c.on_surface, "label_large", { align_h = "center" }),
            m3.text(string.format("%d%%", opacity * 100), c.on_surface_variant, "label_medium", { align_h = "center" }),
        },
    }
end
local layer_tiles = {}
for i, st in ipairs(STATES) do
    layer_tiles[i] = layer_tile(st[1], st[2], c.on_surface)
end
local elevation_page = column {
    width = "fill",
    spacing = 16,
    children = {
        section.card("Elevation", { row { spacing = 24, padding = { bottom = 8 }, children = level_tiles } }),
        section.card("State layers and disabled", { row { spacing = 24, children = layer_tiles } }),
    },
}

local WALLPAPERS = mantle.config_dir .. "/demo/wallpapers"
mantle.files:watch(WALLPAPERS, { "svg", "jpg", "jpeg", "png", "webp" })

local picked = state("m3_wallpaper", "")
local extracted = state("m3_swatches", {})
local vivid = state("m3_vivid", true)
local extraction = nil

-- Score ranks hues by population, so a large dull area can outrank the accent that defines a
-- wallpaper. Vivid mode promotes Score's first pick at tonal spot's primary chroma (36) whose hue,
-- within Score's own +-15 degrees, holds at least 2% of the picture (twice Score's cutoff).
local VIVID_CHROMA, VIVID_SHARE = 36, 0.02

local function hue_share(swatches, hue)
    local share = 0
    for _, swatch in ipairs(swatches) do
        local distance = math.abs(swatch.hue - hue) % 360
        if swatch.chroma >= 5 and math.min(distance, 360 - distance) <= 15 then
            share = share + swatch.share
        end
    end
    return share
end

local function seeds_of(swatches, only_vivid)
    if #swatches == 0 then
        return {}
    end
    local seeds = palette.score(swatches)
    if not only_vivid then
        return seeds
    end
    local by_color = {}
    for _, swatch in ipairs(swatches) do
        by_color[swatch.color] = swatch
    end
    for i, seed in ipairs(seeds) do
        local swatch = by_color[seed]
        if swatch and swatch.chroma >= VIVID_CHROMA and hue_share(swatches, swatch.hue) >= VIVID_SHARE then
            table.insert(seeds, 1, table.remove(seeds, i))
            break
        end
    end
    return seeds
end

local candidates = computed({ extracted, vivid }, seeds_of)

local function reseed()
    local seeds = seeds_of(extracted:get(), vivid:get())
    if seeds[1] then
        theme.seed:set(seeds[1])
    end
end

local function pick_wallpaper(path)
    picked:set(path)
    if extraction then
        extraction:cancel()
    end
    extraction = palette.quantize(path, { depth = 7 }, function(swatches)
        extraction = nil
        if not swatches then
            return
        end
        -- HCT once per picture, so the vivid switch only reads it.
        local measured = {}
        for i, swatch in ipairs(swatches) do
            local hct = palette.hct(swatch.color)
            measured[i] = { color = swatch.color, share = swatch.share, hue = hct.hue, chroma = hct.chroma }
        end
        extracted:set(measured)
        reseed()
    end)
end

action("m3_pick", pick_wallpaper)

local thumbnails = list {
    direction = "horizontal",
    spacing = 12,
    width = "fill",
    scroll = scroll("m3_walls"),
    source = mantle.files:map(function(files)
        local folder = files and files.folders[WALLPAPERS]
        return folder and folder.entries or {}
    end),
    key = function(entry) return entry.path end,
    itemfn = function(entry)
        local selected = picked:map(function(p) return p == entry.path end)
        return rect {
            width = 160,
            height = 100,
            radius = 12,
            border_width = selected:map(function(on) return on and 3 or 0 end),
            border_color = c.primary,
            animate = { border_width = { duration = 150 }, border_color = FADE },
            on_click = function() pick_wallpaper(entry.path) end,
            children = { image { source = entry.path, width = "fill", height = "fill", radius = 12, fit = "cover", async = true } },
        }
    end,
}

-- The top swatches as one bar, each as wide as its share of the picture.
local swatch_strip = extracted:map(function(swatches)
    local top, total = {}, 0
    for i = 1, math.min(16, #swatches) do
        total = total + swatches[i].share
    end
    for i = 1, math.min(16, #swatches) do
        top[i] = rect { width = string.format("%.3f%%", swatches[i].share / total * 100), height = "fill", background = swatches[i].color }
    end
    return top
end)

local candidate_row = candidates:map(function(seeds)
    local kids = {}
    for i, color in ipairs(seeds) do
        kids[i] = seed_swatch("candidate" .. i, color)
    end
    if #kids == 0 then
        kids[1] = m3.text("Pick a wallpaper", c.on_surface_variant, "body_medium")
    end
    return kids
end)

local wallpaper_page = column {
    width = "fill",
    spacing = 16,
    children = {
        section.card("Wallpaper", { thumbnails }),
        row { wrap = true, line_spacing = 24,
            width = "fill",
            spacing = 16,
            children = {
                section.card("Picked", {
                    rect {
                        width = 480,
                        height = 270,
                        radius = 12,
                        background = c.surface_container_highest,
                        children = { image { id = "picked", source = picked, width = "fill", height = "fill", radius = 12, fit = "cover", async = true, transition = { duration = 300 } } },
                    },
                }, { width = 520 }),
                column {
                    width = "fill",
                    spacing = 16,
                    children = {
                        section.card("Quantized (top 16 by share)", {
                            row { width = "fill", height = 48, radius = 12, clip = "rounded", background = c.surface_container_highest, children = swatch_strip },
                        }),
                        section.card("Seeds ranked by Score", {
                            row { spacing = 16, children = candidate_row },
                            m3.switch("vivid", { value = vivid, on_change = reseed, label = "Vivid seeds", detail = "Prefer a colourful accent over a large dull area" }),
                        }),
                    },
                },
            },
        },
    },
}

local TABS = {
    { label = "Color", icon = "palette" },
    { label = "Wallpaper", icon = "wallpaper" },
    { label = "Type", icon = "text_fields" },
    { label = "Shape", icon = "interests" },
    { label = "Elevation", icon = "layers" },
    { label = "Motion", icon = "animation" },
}
local tab = state("m3_styles_tab", 1)

return section.page {
    section.wide(m3.tabs("styles", { items = TABS, value = tab })),
    section.wide(m3.tab_content("styles_tab", { value = tab, pages = { color_page, wallpaper_page, type_page, shape_page, elevation_page, motion_page } })),
}
