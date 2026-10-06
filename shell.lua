-- Material 3 on Mantle: M3's component catalogue by category on a navigation rail, coloured from
-- one seed, built on the `m3` library like any app would be. Run from the repo root: mantle -c .
fonts { "Roboto", "Inter", "Noto Sans", "Noto Color Emoji" }

local m3 = require("m3")
local contacts_data = require("demo.contacts")

local theme, overlay = m3.theme, m3.overlay

-- M3's component categories, the styles they draw from and the layouts that adapt to the window.
local DESTINATIONS = {
    { name = "Actions", icon = "touch_app", page = "demo.pages.actions" },
    { name = "Feedback", icon = "chat_bubble", page = "demo.pages.communication" },
    { name = "Containers", icon = "space_dashboard", page = "demo.pages.containment" },
    { name = "Navigation", icon = "explore", page = "demo.pages.navigation" },
    { name = "Selection", icon = "check_box", page = "demo.pages.selection" },
    { name = "Inputs", icon = "text_fields", page = "demo.pages.text_inputs" },
    { name = "Styles", icon = "palette", page = "demo.pages.styles" },
    { name = "Layout", icon = "devices", page = "demo.pages.layout" },
}
local PAGES = {}
for _, entry in ipairs(DESTINATIONS) do
    entry.label = entry.name
    PAGES[entry.name] = require(entry.page)
end

local page = state("m3_page", "Actions")
-- A page name kept from an older version of the demo falls back to the first page.
if not PAGES[page:get()] then
    page:set("Actions")
end
local body = m3.fade_through(page, PAGES, { scroll = "m3_scroll_" })

local function quit() process.detach("mantle", { "stop", "--pid", tostring(mantle.pid) }) end

local MENU = {
    { label = "Restore contacts", icon = "restart_alt", on_click = function()
        contacts_data.restore()
        overlay.notify("Contacts restored")
    end },
    { label = "Toggle dark theme", icon = "contrast", shortcut = "Ctrl+D", on_click = theme.toggle_dark },
    { divider = true },
    { label = "About", icon = "info", on_click = function()
        overlay.ask({ icon = "info", title = "Material 3 on Mantle", body = "Components, colour, type and motion from the Material 3 spec, drawn by the Mantle engine." })
    end },
}
m3.bind_shortcuts(MENU)

local layout = m3.adaptive_navigation("nav", {
    items = DESTINATIONS,
    value = page,
    window = "m3",
    fab = { icon = "edit", label = "Compose", on_click = function() overlay.notify("Draft saved") end },
    content = column {
        id = "layout",
        width = "fill",
        height = "fill",
        children = {
            m3.top_app_bar("app_bar", {
                kind = "small",
                title = page,
                window = "m3",
                on_close = quit,
                actions = {
                    { icon = "palette", label = "Next seed colour", on_click = theme.next_seed },
                    { icon = theme.dark:map(function(d) return d and "light_mode" or "dark_mode" end), label = "Toggle dark theme", on_click = theme.toggle_dark },
                    { icon = "more_vert", label = "More", menu = MENU },
                },
            }),
            rect { width = "fill", height = "fill", children = { body } },
        },
    },
})

-- Dev hook for screenshots: `mantle call peek <page> <offset>`.
action("peek", function(name, offset)
    page:set(name)
    scroll("m3_scroll_" .. name):scroll_to(tonumber(offset) or 0)
end)

return {
    m3.app_window {
        id = "m3",
        title = "Material 3 on Mantle",
        app_id = "mantle-material-demo",
        min_size = { width = 1100, height = 760 },
        on_close = quit,
        controls = false,
        child = layout,
    },
}
