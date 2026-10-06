-- Containment: lists, cards, carousels, sheets, dialogs and dividers.
local m3 = require("m3")
local section = require("demo.section")
local contacts_data = require("demo.contacts")

local c, FADE = m3.theme.c, m3.theme.motion.fade
local notify = m3.overlay.notify

local WALLS = mantle.config_dir .. "/demo/wallpapers/"
local PHOTOS = {
    { WALLS .. "dusk.svg", "Dusk" },
    { WALLS .. "ember.svg", "Ember" },
    { WALLS .. "tide.svg", "Tide" },
}
local slides = {}
for i, photo in ipairs(PHOTOS) do
    slides[i] = { image = photo[1], label = photo[2] }
end

local function contact_row(person)
    return m3.list_item("contact_" .. person.name, {
        lines = { person.name, person.detail },
        leading = { avatar = person.name:sub(1, 1) },
        trailing = { node = m3.icon_button("delete_" .. person.name, { kind = "standard", icon = "delete", props = { align_v = "center" }, on_click = function() contacts_data.remove(person) end }) },
        animated = true,
    })
end

local function block(title, description, children, wide)
    table.insert(children, 1, m3.text(description, c.on_surface_variant, "body_medium", { wrap = "word", width = "fill" }))
    local node = section.card(title, children)
    return wide and section.wide(node) or node
end

local WIDE = true

-- A list-item variant in an outlined box, captioned by what it shows.
local function variant(caption, items)
    return column {
        width = "fill",
        spacing = 8,
        children = {
            m3.text(caption, c.on_surface_variant, "label_large"),
            rect {
                width = "fill",
                radius = 12,
                clip = "rounded",
                background = c.surface,
                border_width = 1,
                border_color = c.outline_variant,
                animate = { background = FADE, border_color = FADE },
                children = { column { width = "fill", children = items } },
            },
        },
    }
end

local function rule(id) return m3.divider(id, { kind = "inset" }) end
local TEXT3 = "Supporting text that runs long enough to wrap onto a second line of the item."


local function trigger(id, label, icon_name, on_click)
    return m3.button(id, { kind = "tonal", label = label, icon = icon_name, on_click = on_click })
end

local function card_actions(id, headline, kind)
    return {
        m3.button(id .. "_save", { kind = "text", label = "Save", on_click = function() notify("Saved " .. headline) end }),
        m3.button(id .. "_share", { kind = kind == "filled" and "tonal" or "outlined", label = "Share", on_click = function() notify("Shared " .. headline) end }),
    }
end

local function photo_card(kind, index, headline, subhead, supporting)
    return m3.card("card_" .. kind, {
        kind = kind,
        media = PHOTOS[index][1],
        headline = headline,
        subhead = subhead,
        supporting = supporting,
        actions = card_actions("card_" .. kind, headline, kind),
        on_click = function() notify(headline .. " opened") end,
    })
end

local sync, offline = state("m3_ss_sync", true), state("m3_ss_offline", false)

local function side_content()
    return {
        m3.switch("ss_sync", { label = "Sync photos", detail = "Keep this library up to date", value = sync }),
        m3.switch("ss_offline", { label = "Offline copies", detail = "Store originals on this device", value = offline }),
        m3.divider("ss_rule"),
        m3.text("Changes apply to every album in the library.", c.on_surface_variant, "body_medium", { width = "fill", wrap = "word" }),
    }
end

local function event_content()
    return {
        m3.text("Details", c.on_surface, "headline_small"),
        m3.text_field("fs_title", { label = "Event name", container = c.surface }),
        m3.text_field("fs_place", { label = "Location", container = c.surface }),
        m3.text("A full-screen dialog fills the window and closes with its own action, never by tapping outside.", c.on_surface_variant, "body_medium", { width = "fill", wrap = "word" }),
    }
end

local function share_item(icon_name, label)
    return { icon = icon_name, label = label, on_click = function() notify(label) end }
end

local share_items = { share_item("link", "Copy link"), share_item("mail", "Send by email"), share_item("bookmark", "Save to collection"), share_item("print", "Print") }

return section.page {
    block("Lists", "Rows of related text and actions. Search filters; delete asks first.", {
        m3.search_bar("contacts_search", { kind = "inline", placeholder = "Search contacts", on_change = function(text) contacts_data.query:set(text) end }),
        rect {
            width = "fill",
            radius = 12,
            clip = "rounded",
            background = c.surface,
            animate = { background = FADE },
            children = {
                m3.list("contacts", { height = 432, source = contacts_data.shown, query = contacts_data.query, search = function(person) return person.name .. " " .. person.detail end, key = function(person) return person.name end, item = contact_row }),
            },
        },
    }),
    block("List items", "One, two or three lines, with a leading icon, avatar or image and a trailing text, checkbox or switch.", {
        row {
            width = "fill",
            spacing = 16,
            children = {
                column {
                    width = "fill",
                    spacing = 16,
                    children = {
                        variant("One line, icon and text", {
                            m3.list_item("li_one", { lines = { "Inbox" }, leading = { icon = "inbox" }, trailing = { text = "24" } }),
                            rule("li_rule1"),
                            m3.list_item("li_one2", { lines = { "Starred" }, leading = { icon = "star" }, trailing = { text = "3" } }),
                        }),
                        variant("Two lines, avatar and checkbox", {
                            m3.list_item("li_two", { lines = { "Ada Lovelace", "Analytical Engine notes" }, leading = { avatar = "A" }, trailing = { checkbox = true } }),
                            rule("li_rule2"),
                            m3.list_item("li_two2", { lines = { "Alan Turing", "Computable numbers" }, leading = { avatar = "A" }, trailing = { checkbox = true } }),
                        }),
                    },
                },
                column {
                    width = "fill",
                    spacing = 16,
                    children = {
                        variant("Three lines, image and text", {
                            m3.list_item("li_three", { lines = { "Mountain pass", TEXT3, "Shot at dawn." }, leading = { image = PHOTOS[1][1] }, trailing = { text = "2 h" } }),
                            rule("li_rule3"),
                            m3.list_item("li_three2", { lines = { "The wanderer", TEXT3, "Taken in autumn." }, leading = { image = PHOTOS[2][1] }, trailing = { text = "1 d" } }),
                        }),
                        variant("Two lines, icon and switch", {
                            m3.list_item("li_sw", { lines = { "Do not disturb", "Silence calls and alerts" }, leading = { icon = "do_not_disturb_on" }, trailing = { switch = true } }),
                        }),
                    },
                },
            },
        },
    }, WIDE),
    block("Segmented and selectable lists", "Rows as separate rounded segments, the ends rounder. Click a row to select it; Tab in, then the arrows, Home and End move focus.", {
        row {
            width = "fill",
            spacing = 16,
            children = {
                variant("Selectable", {
                    m3.item_list("il_plain", {
                        value = state("m3_demo_il_plain", "inbox"),
                        items = {
                            { key = "inbox", lines = { "Inbox" }, leading = { icon = "inbox" }, trailing = { text = "24" } },
                            { key = "starred", lines = { "Starred" }, leading = { icon = "star" }, trailing = { text = "3" } },
                            { key = "sent", lines = { "Sent" }, leading = { icon = "send" } },
                        },
                    }),
                }),
                column {
                    width = "fill",
                    spacing = 8,
                    children = {
                        m3.text("Segmented", c.on_surface_variant, "label_large"),
                        m3.item_list("il_seg", {
                            segmented = true,
                            value = state("m3_demo_il_seg", "ada"),
                            items = {
                                { key = "ada", lines = { "Ada Lovelace", "Analytical Engine notes" }, leading = { avatar = "A" } },
                                { key = "alan", lines = { "Alan Turing", "Computable numbers" }, leading = { avatar = "A" } },
                                { key = "grace", lines = { "Grace Hopper", "COBOL and the first compiler" }, leading = { avatar = "G" } },
                            },
                        }),
                    },
                },
            },
        },
    }, WIDE),
    block("Cards", "Elevated, filled and outlined containers for one subject. Hover lifts them; press adds a state layer.", {
        row {
            width = "fill",
            spacing = 16,
            children = {
                photo_card("elevated", 1, "Voyager", "Deep space", "A lone probe on the edge of the solar system, still sending."),
                photo_card("filled", 2, "Blue hour", "Twilight", "The quiet window between sunset and night when everything turns blue."),
                photo_card("outlined", 3, "Cabin", "Winter retreat", "Smoke from the chimney, a path through fresh snow and nobody around."),
            },
        },
    }, WIDE),
    block("Carousel", "Multi-browse: large, medium and small items reflow continuously as the wheel scrolls.", {
        m3.carousel("carousel", { items = slides }),
        m3.text("Hero: one large item with two small ones beside it", c.on_surface_variant, "label_large"),
        m3.carousel("carousel_hero", { items = slides, layout = "hero" }),
        m3.text("Uncontained: fixed-width items that scroll off the edge", c.on_surface_variant, "label_large"),
        m3.carousel("carousel_free", { items = slides, layout = "uncontained", height = 160 }),
        m3.text("Full screen: one full-width item at a time, scrolled vertically", c.on_surface_variant, "label_large"),
        m3.carousel("carousel_full", { items = slides, layout = "full_screen", height = 200 }),
    }, WIDE),
    block("Bottom sheet", "Modal: slides up over a scrim. Standard: no scrim, the page stays live. Drag the handle down past a third of the way or fling it to close; a short drag springs back. Escape closes either.", {
        row {
            spacing = 8,
            children = {
                trigger("open_bottom", "Modal bottom sheet", "vertical_align_bottom", function()
                    m3.open_bottom_sheet { title = "Share with", items = share_items }
                end),
                trigger("open_bottom_std", "Standard bottom sheet", "bottom_sheets", function()
                    m3.open_bottom_sheet { title = "Share with", modal = false, items = share_items }
                end),
            },
        },
    }),
    block("Side sheet", "Modal: slides in from the right over a scrim. Standard: no scrim, the page stays live.", {
        row {
            spacing = 8,
            children = {
                trigger("open_side", "Modal side sheet", "right_panel_open", function()
                    m3.open_side_sheet { title = "Library settings", content = side_content, on_confirm = function() notify("Settings saved") end }
                end),
                trigger("open_side_std", "Standard side sheet", "side_navigation", function()
                    m3.open_side_sheet { title = "Library settings", modal = false, content = side_content, on_confirm = function() notify("Settings saved") end }
                end),
            },
        },
    }),
    block("Dialogs", "Basic dialog for a decision; full-screen dialog for a task that needs the whole window.", {
        row {
            spacing = 8,
            children = {
                trigger("open_dialog", "Basic dialog", "chat", function()
                    m3.overlay.ask({ icon = "delete", title = "Discard draft?", body = "Your draft and its attachments will be deleted.", confirm = "Discard" }, function() notify("Draft discarded") end)
                end),
                trigger("open_fs", "Full-screen dialog", "fullscreen", function()
                    m3.open_fullscreen_dialog { title = "New event", content = event_content, on_confirm = function() notify("Event saved") end }
                end),
            },
        },
    }),
    block("Dividers", "A 1px line that groups content: full width or inset, horizontal or vertical.", {
        column {
            width = "fill",
            spacing = 12,
            children = {
                m3.divider("div_full"),
                m3.divider("div_inset", { kind = "inset" }),
                row {
                    width = "fill",
                    height = 56,
                    spacing = 16,
                    children = {
                        m3.text("Full", c.on_surface, "body_medium"),
                        m3.divider("div_vfull", { vertical = true }),
                        m3.text("Inset", c.on_surface, "body_medium"),
                        m3.divider("div_vinset", { kind = "inset", vertical = true }),
                        m3.text("Text", c.on_surface, "body_medium"),
                    },
                },
            },
        },
    }),
}
