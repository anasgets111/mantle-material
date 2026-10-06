-- Navigation: tabs, navigation bar, drawer, rail, top app bars and toolbars, each in a phone frame.
local m3 = require("m3")
local section = require("demo.section")

local c, theme = m3.theme.c, m3.theme
local motion, easing = theme.motion, theme.easing
local FADE = motion.fade
local W, H = 300, 520

-- `wide = true` for phone frames side by side, which need the window's width.
local function card(title, description, body, wide)
    local node = section.card(title, { m3.text(description, c.on_surface_variant, "body_medium", { wrap = "word", width = "fill" }), body })
    return wide and section.wide(node) or node
end

-- A phone-shaped screen: components inside it lay out against its own size.
local function frame(width, height, children)
    return rect {
        width = width,
        height = height,
        radius = 28,
        clip = "rounded",
        background = c.surface,
        border_width = 1,
        border_color = c.outline_variant,
        animate = { background = FADE, border_color = FADE },
        children = children,
    }
end

local function labelled(caption, node)
    return column {
        spacing = 12,
        children = { node, m3.text(caption, c.on_surface_variant, "label_large", { align_h = "center" }) },
    }
end

local function frames(list)
    return row { width = "fill", wrap = true, spacing = 24, line_spacing = 24, children = list }
end

-- Placeholder list rows to scroll under a bar.
local function rows(count, prefix)
    local list = {}
    for i = 1, count do
        list[i] = row {
            width = "fill",
            height = 56,
            align_v = "center",
            spacing = 16,
            padding = { left = 16, right = 16 },
            children = {
                rect { width = 40, height = 40, radius = 20, align_v = "center", background = c.primary_container },
                column {
                    align_v = "center",
                    children = {
                        m3.text(prefix .. " " .. i, c.on_surface, "body_large"),
                        m3.text("Supporting text", c.on_surface_variant, "body_medium"),
                    },
                },
            },
        }
    end
    return list
end

-- A screen that fades through when its selection changes: `name_of(key)` gives the icon and title.
local function screen(value, info_of)
    return rect {
        width = "fill",
        height = "fill",
        children = value:map(function(key)
            local info = info_of(key)
            return {
                column {
                    id = "screen" .. tostring(key),
                    width = "fill",
                    height = "fill",
                    align_v = "center",
                    spacing = 12,
                    opacity = 1,
                    scale = 1,
                    animate = {
                        opacity = { duration = 210, delay = 90, easing = easing.standard, from = 0 },
                        scale = { duration = 300, delay = 90, easing = easing.emphasized_decelerate, from = 0.92 },
                        exit = { duration = 90, opacity = 0 },
                    },
                    children = {
                        m3.icon(info.icon, c.primary, 48, { align_h = "center", filled = true }),
                        m3.text(info.label, c.on_surface, "title_large", { align_h = "center" }),
                    },
                },
            }
        end),
    }
end

---------------------------------------------------------------------------------------------------
-- Tabs

local function tab_pages(items)
    local pages = {}
    for i, item in ipairs(items) do
        pages[i] = column {
            width = "fill",
            padding = 16,
            spacing = 4,
            children = {
                m3.text(item.label, c.on_surface, "title_medium"),
                m3.text("Content for " .. item.label:lower() .. ", sliding in from the side of the tab.", c.on_surface_variant, "body_medium", { wrap = "word", width = "fill" }),
            },
        }
    end
    return pages
end

local function tabs_demo(kind, items)
    local value = state("m3_nav_tabs_" .. kind, 1)
    return labelled(kind:sub(1, 1):upper() .. kind:sub(2), column {
        width = 440,
        radius = 12,
        clip = "rounded",
        background = c.surface,
        animate = { background = FADE },
        children = {
            m3.tabs(kind, { items = items, value = value, kind = kind }),
            m3.tab_content("tab_" .. kind, { value = value, pages = tab_pages(items), height = 88 }),
        },
    })
end

local tabs_card = card("Tabs", "Primary tabs mark the content width with a 3px indicator; secondary tabs underline the whole tab with 2px. The indicator springs between tabs. Tab in, then the arrows move and select.",
    row { wrap = true, line_spacing = 24,
        width = "fill",
        spacing = 24,
        children = {
            tabs_demo("primary", { { label = "Flights", icon = "flight" }, { label = "Trips", icon = "luggage" }, { label = "Explore", icon = "explore" } }),
            tabs_demo("secondary", { { label = "Overview" }, { label = "Specs" }, { label = "Reviews" } }),
        },
    }, true)

---------------------------------------------------------------------------------------------------
-- Navigation bar

local BAR_ITEMS = {
    { label = "Home", icon = "home" },
    { label = "Search", icon = "search" },
    { label = "Library", icon = "video_library" },
    { label = "Profile", icon = "person", badge = 3 },
}

-- not in the spec: the short bar is for wider windows, so its frame is a landscape one.
local SHORT_W = 440

local function bar_demo(id, labels, short)
    local selected = state("m3_nav_bar_" .. id, 1)
    return frame(short and SHORT_W or W, H, {
        column {
            width = "fill",
            height = "fill",
            children = {
                screen(selected, function(i) return BAR_ITEMS[i] end),
                m3.navigation_bar(id, { items = BAR_ITEMS, value = selected, labels = labels, short = short }),
            },
        },
    })
end

local bar_card = card("Navigation bar", "Three to five destinations at the bottom. The 56x32 pill springs open from its centre, the active icon fills and a badge counts. Tab in, then the arrows move between destinations. The short bar sets icon and label side by side.",
    frames { labelled("With labels", bar_demo("full", true)), labelled("Icons only", bar_demo("icons", false)), labelled("Short", bar_demo("short", true, true)) }, true)

---------------------------------------------------------------------------------------------------
-- Navigation drawer and expanded rail: both modal, over a scrim, inside a frame.

local DRAWER_ITEMS = {
    { header = "Mail" },
    { label = "Inbox", icon = "inbox", count = "24" },
    { label = "Outbox", icon = "send" },
    { label = "Favourites", icon = "favorite" },
    { label = "Trash", icon = "delete" },
    { divider = true },
    { header = "Labels" },
    { label = "Family", icon = "label" },
    { label = "Work", icon = "label" },
}

local function drawer_demo(open)
    local selected = state("m3_nav_drawer_sel", 2)
    return frame(400, H, {
        column {
            width = "fill",
            height = "fill",
            children = {
                row {
                    width = "fill",
                    height = 64,
                    padding = { left = 4 },
                    spacing = 4,
                    children = {
                        m3.icon_button("drawer_menu", { kind = "standard", icon = "menu", on_click = function() open:set(true) end, props = { align_v = "center" } }),
                        m3.text(selected:map(function(i) return DRAWER_ITEMS[i].label end), c.on_surface, "title_large"),
                    },
                },
                column { width = "fill", height = "fill", children = rows(8, "Message") },
            },
        },
        m3.navigation_drawer("demo", { items = DRAWER_ITEMS, value = selected, open = open }),
    })
end

local RAIL_ITEMS = {
    { name = "Home", icon = "home" },
    { name = "Search", icon = "search" },
    { name = "Library", icon = "video_library" },
    { name = "Profile", icon = "person" },
}

local function rail_demo()
    local expanded = state("m3_nav_rail", false)
    local selected = state("m3_nav_rail_sel", "Home")
    local info = {}
    for _, item in ipairs(RAIL_ITEMS) do
        info[item.name] = { icon = "dashboard", label = item.name }
    end
    return frame(W, H, {
        column {
            width = "fill",
            height = "fill",
            align_v = "center",
            spacing = 12,
            padding = { left = 80 },
            children = { screen(selected, function(name) return info[name] end) },
        },
        m3.navigation_rail("demo", {
            destinations = RAIL_ITEMS,
            value = selected,
            fab = { icon = "edit", label = "Compose", on_click = function() end },
            expanded = expanded,
            menu = true,
            modal = true,
        }),
    }), expanded
end

local drawer_open = state("m3_nav_drawer", false)
local rail_frame, rail_expanded = rail_demo()
local drawer_card = card("Navigation drawer", "A modal drawer slides in over a scrim: pill items, a section header and a divider.",
    column {
        spacing = 16,
        children = {
            m3.button("drawer_open", { kind = "tonal", label = "Open drawer", icon = "menu", on_click = function() drawer_open:set(true) end }),
            drawer_demo(drawer_open),
        },
    })
local rail_card = card("Navigation rail", "The app's own rail on the left is the collapsed rail. The expanded one is modal: the menu button opens it over a scrim.",
    column {
        spacing = 16,
        children = {
            m3.button("rail_open", { kind = "tonal", label = "Expand rail", icon = "menu_open", on_click = function() rail_expanded:set(true) end }),
            rail_frame,
        },
    })

---------------------------------------------------------------------------------------------------
-- Top app bars: the medium and large bars collapse into the small one as the content scrolls.

local function appbar_demo(kind)
    local offset = scroll("m3_nav_appbar_" .. kind)
    return frame(220, 420, {
        column { width = "fill", height = "fill", scroll = offset, animate = { scroll = theme.motion.scroll }, padding = { top = m3.top_app_bar_height(kind) }, children = rows(14, "Item") },
        m3.top_app_bar("appbar_" .. kind, {
            kind = kind,
            title = "Inbox",
            subtitle = kind == "flexible" and "24 unread" or nil,
            navigation_icon = kind == "center" and "menu" or "arrow_back",
            actions = { { icon = "more_vert", label = "More", on_click = function() end } },
            scroll = offset,
        }),
    })
end

local appbar_card = card("Top app bars", "Centre-aligned and small bars stay 64px. Medium and large start with a headline that fades into the title row as the list scrolls; the bar takes surface container once content passes under it. Scroll inside a frame.",
    frames {
        labelled("Centre-aligned", appbar_demo("center")),
        labelled("Small", appbar_demo("small")),
        labelled("Medium", appbar_demo("medium")),
        labelled("Large", appbar_demo("large")),
        labelled("Flexible, with subtitle", appbar_demo("flexible")),
    }, true)

---------------------------------------------------------------------------------------------------
-- Toolbars (Expressive)

local TOOLS = {
    { icon = "edit", label = "Edit" },
    { icon = "share", label = "Share" },
    { icon = "bookmark", label = "Bookmark" },
    { icon = "more_vert", label = "More" },
}
local ADD = { icon = "add", label = "Add", on_click = function() end }

local toolbar_card = card("Toolbars", "Expressive toolbars hold actions: the docked one spans the bottom edge; the floating pill, with a FAB beside it, slides away when you scroll down and returns when you scroll up.",
    frames {
        labelled("Docked", frame(W, H, {
            column { width = "fill", height = "fill", scroll = scroll("m3_nav_docked"), animate = { scroll = theme.motion.scroll }, children = rows(14, "Item") },
            m3.toolbar("docked", { kind = "docked", actions = TOOLS, fab = ADD }),
        })),
        labelled("Floating", (function()
            local offset = scroll("m3_nav_floating")
            return frame(W, H, {
                column { width = "fill", height = "fill", scroll = offset, animate = { scroll = theme.motion.scroll }, children = rows(14, "Item") },
                m3.toolbar("float", { kind = "floating", actions = TOOLS, fab = ADD, scroll = offset }),
            })
        end)()),
    }, true)

return section.page { tabs_card, bar_card, drawer_card, rail_card, appbar_card, toolbar_card }
