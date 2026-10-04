-- Material 3 on Mantle: M3's component catalogue by category on a navigation rail, coloured from
-- one seed, built on the `m3` library like any app would be. Run: mantle -c /mnt/Work/1Progs/m3-demo
fonts { "Inter", "Noto Sans", "Noto Color Emoji" }

local m3 = require("m3")
local contacts_data = require("demo.contacts")

local theme, overlay = m3.theme, m3.overlay

-- M3's component categories, plus the styles they draw from. Seven: the rail's maximum.
local DESTINATIONS = {
    { name = "Actions", icon = "touch_app", page = "demo.pages.actions" },
    { name = "Feedback", title = "Communication", icon = "chat_bubble", page = "demo.pages.communication" },
    { name = "Containers", title = "Containment", icon = "space_dashboard", page = "demo.pages.containment" },
    { name = "Navigation", icon = "explore", page = "demo.pages.navigation" },
    { name = "Selection", icon = "check_box", page = "demo.pages.selection" },
    { name = "Inputs", title = "Text inputs", icon = "text_fields", page = "demo.pages.text_inputs" },
    { name = "Styles", icon = "palette", page = "demo.pages.styles" },
}
local PAGES, TITLES = {}, {}
for _, entry in ipairs(DESTINATIONS) do
    PAGES[entry.name] = require(entry.page)
    TITLES[entry.name] = entry.title or entry.name
end

local stored_page = state("m3_page", "Actions")
local page = stored_page:map(function(name) return PAGES[name] and name or "Actions" end)
-- Any page change, from the rail or `mantle set`, closes what was open over the old page.
stored_page:on_change(overlay.close_all)

-- M3 fade through for top-level destinations: the old page fades out in 90 ms, then the new one
-- fades in over 210 ms while scaling up from 92%.
local body = page:map(function(name)
    return {
        column {
            id = name,
            width = "fill",
            height = "fill",
            scroll = scroll("m3_scroll_" .. name),
            opacity = 1,
            scale = 1,
            origin = { x = 0.5, y = 0 },
            animate = {
                -- Wheel notches glide on a critically damped spring: Expressive spatial springs overshoot.
                scroll = theme.motion.effects,
                opacity = { duration = 210, delay = 90, easing = theme.easing.standard, from = 0 },
                scale = { duration = 300, delay = 90, easing = theme.easing.emphasized_decelerate, from = 0.92 },
                exit = { duration = 90, easing = theme.easing.emphasized_accelerate, opacity = 0 },
            },
            children = { PAGES[name] },
        },
    }
end)

local more = geometry("m3_more")

local function next_seed()
    local index = 1
    for i, seed in ipairs(theme.SEEDS) do
        if seed.color == theme.seed:get() then
            index = i % #theme.SEEDS + 1
        end
    end
    theme.seed:set(theme.SEEDS[index].color)
end

local function toggle_dark()
    theme.dark:set(not theme.dark:get())
end

local function overflow_menu()
    m3.open_menu({
        anchor = more,
        width = 224,
        align = "end",
        items = {
            { label = "Restore contacts", icon = "restart_alt", on_click = function()
                contacts_data.restore()
                overlay.notify("Contacts restored")
            end },
            { label = "Toggle dark theme", icon = "contrast", on_click = toggle_dark },
            { divider = true },
            { label = "About", icon = "info", on_click = function()
                overlay.ask({ icon = "info", title = "Material 3 on Mantle", body = "Components, colour, type and motion from the Material 3 spec, drawn by the Mantle engine." })
            end },
        },
    })
end

local layout = row {
    id = "layout",
    width = "fill",
    height = "fill",
    children = {
        m3.navigation_rail("rail", {
            destinations = DESTINATIONS,
            value = stored_page,
            fab = { icon = "edit", on_click = function() overlay.notify("Draft saved") end },
        }),
        column {
            width = "fill",
            height = "fill",
            padding = { right = 24, bottom = 24 },
            children = {
                m3.top_app_bar("app_bar", {
                    kind = "small",
                    title = page:map(function(name) return TITLES[name] end),
                    actions = {
                        { icon = "palette", label = "Next seed colour", on_click = next_seed },
                        { icon = theme.dark:map(function(d) return d and "light_mode" or "dark_mode" end), label = "Toggle dark theme", on_click = toggle_dark },
                        { icon = "more_vert", label = "More", on_click = overflow_menu, geometry = more },
                    },
                }),
                rect { width = "fill", height = "fill", children = body },
            },
        },
    },
}

-- Dev hook for screenshots: `mantle call peek <page> <offset>`.
action("peek", function(name, offset)
    stored_page:set(name)
    scroll("m3_scroll_" .. name):scroll_to(tonumber(offset) or 0)
end)

return {
    m3.app_window {
        id = "m3",
        title = "Material 3 on Mantle",
        app_id = "mantle-m3-demo",
        min_size = { width = 1100, height = 760 },
        on_close = function() process.detach("mantle", { "stop", "--pid", tostring(mantle.pid) }) end,
        child = layout,
    },
}
