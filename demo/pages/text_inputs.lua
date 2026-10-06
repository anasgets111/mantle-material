-- Text inputs: filled and outlined text fields in every state, the new-contact form, and search.
local m3 = require("m3")
local sec = require("demo.section")
local contacts_data = require("demo.contacts")

local c = m3.theme.c

local function section(title, detail, children, wide)
    table.insert(children, 1, m3.text(detail, c.on_surface_variant, "body_medium", { margin = { bottom = 4 }, wrap = "word", width = "fill" }))
    local node = sec.card(title, children)
    return wide and sec.wide(node) or node
end

local PEOPLE = { "Ada Lovelace", "Alan Turing", "Barbara Liskov", "Claude Shannon", "Donald Knuth", "Edsger Dijkstra", "Grace Hopper", "Ken Thompson", "Margaret Hamilton" }

-- The six states of one field kind, three to a row; `kind` namespaces the ids.
local function states(kind)
    local function field(id, label, opts)
        opts.kind, opts.label, opts.container, opts.width = kind, label, c.surface_container, 288
        return (m3.text_field(kind .. "_" .. id, opts))
    end
    local function row3(a, b, c3) return row { width = "fill", wrap = true, spacing = 24, line_spacing = 16, children = { a, b, c3 } } end
    return column {
        spacing = 16,
        children = {
            row3(
                field("plain", "Label", { supporting = "Supporting text" }),
                field("icons", "Search", { leading = "search", clear = true, supporting = "Leading icon, clear when typing" }),
                field("affix", "Amount", { prefix = "$", suffix = "USD", trailing = "payments", supporting = "Prefix, suffix, trailing icon" })
            ),
            row3(
                field("count", "Message", { max_length = 20, supporting = "Typing stops at 20" }),
                field("error", "Email", { validate = contacts_data.is_email, supporting = "Type an invalid address", clear = true }),
                field("off", "Disabled", { disabled = true, value = state("m3_demo_off_" .. kind, "Can't edit this"), supporting = "Supporting text" })
            ),
        },
    }
end

local function outlined(id, label, opts)
    opts.kind, opts.label, opts.container = "outlined", label, c.surface_container
    return m3.text_field(id, opts)
end

local name_field, name = outlined("name", "Name", { leading = "person", clear = true, supporting = "As it appears on your profile" })
local email_field, email = outlined("email", "Email", { leading = "mail", clear = true, supporting = "We never share it", validate = contacts_data.is_email })
local note_field, note = outlined("note", "Note", { leading = "notes", max_length = 60 })

local function clear_form()
    name.clear()
    email.clear()
    note.clear()
end

local function save_contact()
    local entered = name.value:get() or ""
    local problem = contacts_data.add(entered, email.value:get(), note.value:get())
    if problem then
        return m3.overlay.notify(problem)
    end
    clear_form()
    m3.overlay.notify(entered:match("^%s*(.-)%s*$") .. " added to Contacts")
end

return sec.page {
    section("Filled text field", "A container with a bottom indicator that thickens on focus; the label floats above the text.", { states("filled") }),
    section("Outlined text field", "An outline that thickens to primary on focus; the label floats onto it.", { states("outlined") }),
    section("Multi-line text field", "Wraps and takes Return for a new line. It grows from its minimum to its maximum rows, then scrolls. Right-click any field for the Edit menu.", {
        row { width = "fill", wrap = true, line_spacing = 24,
            spacing = 24,
            children = {
                column {
                    spacing = 4,
                    children = {
                        m3.text("Outlined, 3 to 6 rows", c.on_surface_variant, "label_medium"),
                        (m3.text_field("bio_outlined", { multiline = true, min_lines = 3, max_lines = 6, kind = "outlined", label = "Bio", container = c.surface_container, supporting = "Ctrl+Return submits", max_length = 200, width = 288, leading = "notes" })),
                    },
                },
                column {
                    spacing = 4,
                    children = {
                        m3.text("Filled, 2 rows and up", c.on_surface_variant, "label_medium"),
                        (m3.text_field("bio_filled", { multiline = true, min_lines = 2, kind = "filled", label = "Message", supporting = "Return submits, Shift+Return breaks the line", submit_key = "return", width = 288, trailing = "send", on_submit = function(t) m3.overlay.notify("Sent " .. #t .. " characters") end })),
                    },
                },
            },
        },
    }),
    section("New contact", "An outlined form that saves into Contacts.", {
        name_field,
        email_field,
        note_field,
        row { wrap = true, line_spacing = 24,
            width = "fill",
            align_h = "end",
            spacing = 8,
            children = {
                m3.button("form_clear", { kind = "text", label = "Clear", on_click = clear_form }),
                m3.button("form_save", { kind = "filled", label = "Save", on_click = save_contact }),
            },
        },
    }),
    section("Search", "The bar opens a search view that grows out of it, with suggestions as you type. Right-click its field for the Edit menu.", {
        m3.search_bar("contacts", { placeholder = "Search contacts", options = PEOPLE }),
    }),
}
