-- Communication: badges, progress and loading indicators, shapes, snackbars and tooltips.
local m3 = require("m3")
local section = require("demo.section")

local c, FADE = m3.theme.c, m3.theme.motion.fade
local notify = m3.notify

local function detail(description)
    return m3.text(description, c.on_surface_variant, "body_medium", { wrap = "word", width = "fill" })
end

local function caption(label)
    return m3.text(label, c.on_surface_variant, "label_medium")
end

local function labelled(label, node)
    return column { spacing = 12, children = { caption(label), node } }
end

-- An icon with a badge on its corner.
-- A navigation-style destination: icon in its pill, label below, a badge on the pill's corner.
local function destination(icon_name, label, selected, badge_id, count)
    local fg = m3.theme.pick(selected, "on_secondary_container", "on_surface_variant")
    local glyph = m3.icon(icon_name, fg, 24, { filled = selected })
    return column {
        width = 80,
        spacing = 4,
        children = {
            rect {
                width = 56,
                height = 32,
                radius = 16,
                align_h = "center",
                background = m3.theme.pick(selected, "secondary_container", "surface_container"),
                children = {
                    -- The badge rides the icon's corner, inside the pill.
                    rect {
                        align_h = "center",
                        align_v = "center",
                        children = { badge_id and m3.badged(badge_id, { child = glyph, count = count }) or glyph },
                    },
                },
            },
            m3.text(label, fg, "label_medium", { align_h = "center" }),
        },
    }
end

-- A static snackbar mock-up; the live one is m3.notify.
local function snackbar(message, action, close, two_line)
    local kids = { m3.text(message, c.inverse_on_surface, "body_medium", { width = "fill", wrap = "word" }) }
    if action then
        kids[#kids + 1] = m3.interactive("snackprev_" .. action .. #message, { height = 36, radius = 18, align_v = "center" }, c.inverse_primary,
            row { height = "fill", align_v = "center", padding = { left = 12, right = 12 }, children = { m3.text(action, c.inverse_primary, "label_large") } })
    end
    if close then
        kids[#kids + 1] = m3.icon("close", c.inverse_on_surface, 24, { align_v = "center" })
    end
    return row(m3.merge({
        width = 420,
        height = two_line and 68 or 48,
        radius = 4,
        padding = { left = 16, right = 8 },
        spacing = 8,
        align_v = "center",
        background = c.inverse_surface,
        animate = { background = FADE },
        children = kids,
    }, m3.theme.elevation[3]))
end

-- A shape tile: it morphs to the next shape while hovered, and a click steps its resting shape.
local function shape_tile(index)
    local names = m3.shapes.NAMES
    local over = hover("m3_shape" .. index)
    local step = state("m3_c_shape" .. index, 0)
    local current = computed({ over, step }, function(on, n)
        return names[(index - 1 + (n or 0) + (on and 1 or 0)) % #names + 1]
    end)
    return column {
        width = 72,
        spacing = 4,
        hover = over,
        on_click = function() step:set((step:get() or 0) + 1) end,
        children = {
            rect {
                width = 72,
                height = 64,
                radius = 12,
                background = m3.theme.pick(over, "secondary_container", "surface_container_high"),
                animate = { background = FADE },
                children = { m3.shape("shape_tile" .. index, { name = current, props = { align_h = "center", align_v = "center" } }) },
            },
            m3.text(current:map(function(name) return name:gsub("_", " ") end), c.on_surface_variant, "label_medium", { align_h = "center" }),
        },
    }
end

---------------------------------------------------------------------------------------------------

local mail = state("m3_c_mail", 3)
local tab = state("m3_c_tab", "Mail")
local function nav(icon_name, label, badge_id, count)
    local selected = tab:map(function(t) return t == label end)
    return rect {
        on_click = function() tab:set(label) end,
        children = { destination(icon_name, label, selected, badge_id, count) },
    }
end

local badges = section.card("Badges", {
    detail("Badges flag new activity on an icon or destination: a small dot for any, a large pill for a count. A new count springs in."),
    row {
        spacing = 48,
        children = {
            labelled("On icons", row {
                spacing = 32,
                height = 40,
                children = {
                    m3.badged("b_dot", { child = m3.icon("notifications", c.on_surface_variant, 24) }),
                    m3.badged("b_mail", { child = m3.icon("mail", c.on_surface_variant, 24), count = mail }),
                    m3.badged("b_cart", { child = m3.icon("shopping_cart", c.on_surface_variant, 24), count = 1200 }),
                },
            }),
            labelled("On destinations", row {
                spacing = 8,
                children = {
                    nav("mail", "Mail", "b_nav_mail", mail),
                    nav("chat", "Chat", "b_nav_chat"),
                    nav("group", "Groups", "b_nav_groups", 120),
                    nav("person", "Profile", "b_nav_profile", 0),
                },
            }),
            labelled("Count", row {
                spacing = 8,
                children = {
                    m3.button("badge_add", { kind = "secondary", label = "Add", icon = "add", on_click = function() mail:set(mail:get() + 1) end }),
                    m3.button("badge_clear", { kind = "plain", label = "Clear", on_click = function() mail:set(0) end }),
                },
            }),
        },
    },
})

---------------------------------------------------------------------------------------------------

local prog = state("m3_c_prog", 0.6)
local running = 0
local function run()
    running = running + 1
    local mine, n = running, 0
    prog:set(0)
    local function step()
        if mine ~= running then
            return
        end
        n = n + 1
        prog:set(n / 20)
        if n < 20 then
            timer(150, step)
        end
    end
    timer(150, step)
end

local W = 240
local progress = section.card("Progress indicators", {
    detail("Progress shows that something is happening, or how far along it is. Flat and wavy shapes, each determinate or indeterminate."),
    row {
        spacing = 16,
        children = {
            column { align_v = "end", children = { m3.button("prog_run", { kind = "primary", label = "Animate 0 to 100%", icon = "play_arrow", on_click = run }) } },
            m3.slider("prog_slider", { value = prog, width = 280 }),
            m3.text(prog:map(function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end), c.on_surface, "label_large", { align_v = "end", margin = { bottom = 14 } }),
        },
    },
    row {
        spacing = 40,
        children = {
            column {
                spacing = 20,
                children = {
                    labelled("Linear determinate", m3.progress_bar("lin", { value = prog, width = W })),
                    labelled("Linear indeterminate", m3.progress_bar("lin_ind", { indeterminate = true, width = W })),
                    labelled("Linear wavy", m3.progress_bar("lin_wavy", { value = prog, wavy = true, width = W })),
                },
            },
            row {
                spacing = 32,
                children = {
                    labelled("Circular", m3.progress_ring("circ", { value = prog })),
                    labelled("Circular indeterminate", m3.progress_ring("circ_ind", { indeterminate = true })),
                    labelled("Circular wavy", m3.progress_ring("circ_wavy", { value = prog, wavy = true })),
                    labelled("Wavy indeterminate", m3.progress_ring("circ_wavy_ind", { indeterminate = true, wavy = true })),
                },
            },
        },
    },
})

---------------------------------------------------------------------------------------------------

local loading = section.card("Loading indicator", {
    detail("The Expressive loading indicator morphs a filled shape through a sequence while it turns, for waits of a few seconds."),
    row {
        spacing = 48,
        children = {
            labelled("Uncontained", m3.spinner("load")),
            labelled("Contained", m3.spinner("load_c", { contained = true })),
        },
    },
})

local tiles = { {}, {} }
for i, _ in ipairs(m3.shapes.NAMES) do
    local row_tiles = tiles[i <= 11 and 1 or 2]
    row_tiles[#row_tiles + 1] = shape_tile(i)
end

local shape_card = section.card("Shapes", {
    detail("M3 Expressive's shape library. Every shape shares one outline layout, so any shape morphs into any other: hover a tile to morph it, click to step to the next resting shape."),
    row { width = "fill", wrap = true, spacing = 8, line_spacing = 8, children = table.move(tiles[2], 1, #tiles[2], #tiles[1] + 1, { table.unpack(tiles[1]) }) },
})

---------------------------------------------------------------------------------------------------

local snackbar = section.card("Snackbar", {
    detail("A snackbar reports the result of an action. It carries at most one action and a close icon; long messages take two lines. One shows at a time; the rest queue."),
    row {
        spacing = 32,
        width = "fill",
        wrap = true,
        line_spacing = 16,
        children = {
            column {
                spacing = 12,
                children = {
                    caption("Single line"),
                    snackbar("Message archived"),
                    caption("With action"),
                    snackbar("Message archived", "Undo"),
                    caption("Two lines, action and close"),
                    snackbar("Your changes could not be saved. Check the connection and try again.", "Retry", true, true),
                },
            },
            column {
                spacing = 12,
                children = {
                    caption("Live, at the bottom of the window"),
                    m3.button("snack_show", { kind = "secondary", label = "Show snackbar", on_click = function() notify { title = "Message archived" } end }),
                    caption("Three at once: each waits for the one before"),
                    m3.button("snack_queue", {
                        kind = "secondary",
                        label = "Queue three",
                        on_click = function()
                            notify { title = "First message" }
                            notify { title = "Second message, after the first", action = "Undo" }
                            notify { title = "Third message, last", close = true }
                        end,
                    }),
                },
            },
        },
    },
})

---------------------------------------------------------------------------------------------------

local tooltips = section.card("Tooltips", {
    detail("A tooltip names a control. Plain: a short label after the pointer rests. Rich: a title, a sentence and an action that stays while you reach for it."),
    row {
        spacing = 24,
        margin = { top = 72 },
        children = {
            m3.tooltip("tip_edit", { label = "Edit", child = m3.icon_button("tip_edit_btn", { icon = "edit", on_click = function() notify { title = "Edit" } end }) }),
            m3.tooltip("tip_share", { label = "Share", child = m3.icon_button("tip_share_btn", { kind = "secondary", icon = "share", on_click = function() notify { title = "Share" } end }) }),
            m3.tooltip("tip_delete", { label = "Delete", child = m3.icon_button("tip_delete_btn", { kind = "outlined", icon = "delete", on_click = function() notify { title = "Delete" } end }) }),
            m3.rich_tooltip("tip_info", {
                child = m3.icon_button("tip_info_btn", { kind = "primary", icon = "info", on_click = function() notify { title = "Info" } end }),
                title = "Offline mode",
                body = "Download maps and documents to keep using them without a connection.",
                action = "Learn more",
                on_action = function() notify { title = "Learn more" } end,
            }),
        },
    },
})

---------------------------------------------------------------------------------------------------

local wide = section.wide

return section.page { wide(badges), wide(progress), loading, shape_card, wide(snackbar), wide(tooltips) }
