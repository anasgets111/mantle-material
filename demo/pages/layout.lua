-- Layout: window size classes, adaptive navigation and the list-detail canvas. Each preview is forced
-- to one class (the window can't be resized from here); the live class is the window's own.
local m3 = require("m3")
local section = require("demo.section")

local c, theme = m3.theme.c, m3.theme
local FADE = theme.motion.fade

local CLASSES = {
    { "compact", 320, "< 600 dp" },
    { "medium", 420, "600 - 839 dp" },
    { "expanded", 760, "840 - 1199 dp" },
}
local H = 420

local PEOPLE = {
    { "Ada Lovelace", "Analytical Engine notes" },
    { "Alan Turing", "Computable numbers" },
    { "Grace Hopper", "COBOL and the first compiler" },
    { "Ken Thompson", "Unix and UTF-8" },
    { "Margaret Hamilton", "Apollo guidance software" },
}

local function frame(width, child)
    return rect {
        width = width,
        height = H,
        radius = 28,
        clip = "rounded",
        background = c.surface,
        border_width = 1,
        border_color = c.outline_variant,
        animate = { background = FADE, border_color = FADE },
        children = { child },
    }
end

local function labelled(caption, node)
    return column { spacing = 12, children = { node, m3.text(caption, c.on_surface_variant, "label_large", { align_h = "center" }) } }
end

local function previews(build)
    local frames = {}
    for i, k in ipairs(CLASSES) do
        local class = state("m3_layout_class_" .. k[1], k[1])
        frames[i] = labelled(k[1] .. "  " .. k[3], frame(k[2], build(k[1], class)))
    end
    return row { spacing = 24, line_spacing = 24, wrap = true, children = frames }
end

local live = m3.window_class("m3")
local live_width = m3.overlay.bounds("m3")
local live_card = section.wide("Window class", {
    m3.text(live:map(function(k) return (k:gsub("_", " ")) end), c.primary, "display_small_emphasized"),
    m3.text(live_width:map(function(g) return string.format("%d dp wide", g and g.width or 0) end), c.on_surface_variant, "body_large"),
    m3.text("Compact under 600 dp, medium to 839, expanded to 1199, large to 1599, extra large from 1600.", c.on_surface_variant, "body_medium"),
})

local ITEMS = { { name = "Inbox", label = "Inbox", icon = "inbox" }, { name = "Starred", label = "Starred", icon = "star" }, { name = "Sent", label = "Sent", icon = "send" } }
local function nav_preview(key, class)
    return m3.adaptive_navigation("lay_nav_" .. key, {
        items = ITEMS,
        value = state("m3_layout_nav_" .. key, "Inbox"),
        class = class,
        fab = { icon = "edit", label = "Compose" },
        content = column {
            width = "fill",
            height = "fill",
            padding = 24,
            spacing = 8,
            children = { m3.text("Page", c.on_surface, "headline_small_emphasized"), m3.text("The navigation follows the width.", c.on_surface_variant, "body_medium") },
        },
    })
end

local function detail_preview(key, class)
    local sel = state("m3_layout_sel_" .. key, 1)
    local has_detail = state("m3_layout_open_" .. key, false)
    local rows = {}
    for i, p in ipairs(PEOPLE) do
        rows[i] = m3.list_item("lay_" .. key .. i, {
            lines = { p[1], p[2] },
            leading = { avatar = p[1]:sub(1, 1) },
            on_click = function() sel:set(i) has_detail:set(true) end,
        })
    end
    local detail = column {
        width = "fill",
        height = "fill",
        padding = 24,
        spacing = 8,
        align_h = "center",
        children = {
            rect { width = 72, height = 72, radius = 36, background = c.primary_container, animate = { background = FADE }, children = {
                m3.text(sel:map(function(i) return PEOPLE[i][1]:sub(1, 1) end), c.on_primary_container, "headline_medium_emphasized", { align_h = "center" }),
            } },
            m3.text(sel:map(function(i) return PEOPLE[i][1] end), c.on_surface, "title_large_emphasized"),
            m3.text(sel:map(function(i) return PEOPLE[i][2] end), c.on_surface_variant, "body_medium"),
        },
    }
    return m3.list_detail("lay_ld_" .. key, { list = column { width = "fill", padding = { top = 8 }, children = rows }, detail = detail, has_detail = has_detail, class = class })
end

return section.page {
    live_card,
    section.wide("Adaptive navigation", {
        m3.text("A bottom bar when compact, a collapsed rail when medium, an expanded rail from 840 dp.", c.on_surface_variant, "body_medium"),
        previews(nav_preview),
    }),
    section.wide("List-detail", {
        m3.text("Side by side from 840 dp; narrower, the list, then the detail under a back button.", c.on_surface_variant, "body_medium"),
        previews(detail_preview),
    }),
}
