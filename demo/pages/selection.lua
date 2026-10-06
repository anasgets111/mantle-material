-- Selection: checkbox, radio, switch, chips, segmented button, sliders, menus and the pickers.
local m3 = require("m3")
local sec = require("demo.section")

local c = m3.theme.c
local notify = m3.notify

local function section(title, detail, children, wide)
    table.insert(children, 1, m3.text(detail, c.on_surface_variant, "body_medium", { margin = { bottom = 4 }, wrap = "word", width = "fill" }))
    local node = sec.card(title, children)
    return wide and sec.wide(node) or node
end

-- `box`: a fixed height the control centres in, so captions in a row share a line.
local function variant(caption, node, box)
    if box then
        node = rect { height = box, children = { rect { align_v = "center", children = { node } } } }
    end
    return column { spacing = 8, children = { node, m3.text(caption, c.on_surface_variant, "label_medium") } }
end

local function pickers(children) return row { spacing = 16, width = "fill", wrap = true, line_spacing = 16, children = children } end

local function cluster(children) return row { spacing = 32, width = "fill", wrap = true, line_spacing = 24, children = children } end

local function switches(prefix, opts, ...)
    local kids = {}
    for i, on in ipairs({ ... }) do
        kids[i] = m3.switch(prefix .. i, { value = state("m3_demo_sw_" .. prefix .. i, on), icons = opts.icons, disabled = opts.disabled })
    end
    return row { spacing = 12, children = kids }
end

local wifi, bluetooth = state("m3_wifi", true), state("m3_bt", false)
local volume = state("m3_volume", 0.6)
local range = state("m3_range", "Week")
local plan = state("m3_sel_plan", "Monthly")
local people = state("m3_sel_people", { "Ada", "Alan", "Grace" })
local discrete = state("m3_sel_discrete", 0.4)
local lo, hi = state("m3_sel_lo", 0.25), state("m3_sel_hi", 0.7)
local centered = state("m3_sel_centered", 0.7)
local tall, tall_range_lo, tall_range_hi, tall_icon = state("m3_sel_tall", 0.4), state("m3_sel_tall_lo", 0.2), state("m3_sel_tall_hi", 0.8), state("m3_sel_tall_icon", 0.6)
local weekdays = state("m3_sel_weekdays", { Mon = true })

local function checkbox(id, label, initial, opts)
    opts = opts or {}
    opts.label, opts.value = label, state("m3_demo_cb_" .. id, initial)
    return m3.checkbox(id, opts)
end

local WIDE = true

return sec.page {
    section("Checkbox", "Select one or more items from a set. The mark draws itself and the box fills.", {
        row {
            spacing = 24,
            children = {
                variant("Unchecked", checkbox("plain", "Label", false)),
                variant("Checked", checkbox("on", "Label", true)),
                variant("Mixed", checkbox("mixed", "Label", "mixed")),
                variant("Error", checkbox("err", "Label", false, { error = true })),
                variant("Disabled", checkbox("dis", "Label", true, { disabled = true })),
            },
        },
        variant("A parent checkbox controls its children", m3.checkbox_group("parent", { label = "Notifications", items = { "Mentions", "Replies", "Reminders" } })),
    }),
    section("Radio button", "Select exactly one option from a set. The dot grows on a spring. Tab in, then Up and Down move and select.", {
        cluster({
            variant("Group", m3.radio_group("plan", { options = { "Monthly", "Yearly", "Lifetime" }, value = plan })),
            variant("Disabled", m3.radio_group("plan_off", { options = { "Monthly", "Yearly" }, value = plan, disabled = true })),
        }),
    }),
    section("Switch", "Turn one setting on or off.", {
        row {
            spacing = 48,
            children = {
                column {
                    width = 360,
                    spacing = 16,
                    children = {
                        m3.switch("wifi", { value = wifi, label = "Wi-Fi", detail = "Connected to Home" }),
                        m3.switch("bluetooth", { value = bluetooth, label = "Bluetooth", detail = "Visible to nearby devices" }),
                    },
                },
                cluster({
                    variant("Off / on", switches("plain", {}, false, true)),
                    variant("With icons", switches("icons", { icons = true }, false, true)),
                    variant("Disabled", switches("off", { disabled = true, icons = true }, false, true)),
                }),
            },
        },
    }),
    section("Chips", "Assist, filter, input and suggestion chips help people act, narrow, enter and pick.", {
        variant("Assist", row {
            spacing = 8,
            children = {
                m3.chip("a1", { icon = "event", label = "Add to calendar", on_click = function() notify { title = "Added to calendar" } end }),
                m3.chip("a2", { icon = "directions", label = "Directions", elevated = true, on_click = function() notify { title = "Opening maps" } end }),
            },
        }),
        variant("Filter, elevated: the arrows move between chips", require("m3.selection.chips").chip_group("filters", {
            items = {
                { kind = "filter", label = "Open now", value = state("m3_chip_open", true) },
                { kind = "filter", label = "Top rated", value = state("m3_chip_rated", false) },
                { kind = "filter", label = "Nearby", elevated = true, value = state("m3_chip_near", false) },
            },
        })),
        variant("Input: remove with the close button; the arrows move between chips", m3.input_chips("people", { value = people })),
        variant("Suggestion: adds to the input chips; the arrows move between chips", m3.suggestion_chips("people", { options = { "Ada", "Alan", "Barbara", "Grace", "Ken", "Margaret", "Linus" }, value = people })),
    }),
    section("Segmented button", "Choose one range from two to five options. The arrows, Home and End move focus.", {
        m3.segmented_control("seg", { items = { "Day", "Week", "Month" }, value = range, width = 96 }),
        m3.segmented_control("seg_multi", { multiple = true, items = { "Mon", "Tue", "Wed", "Thu", "Fri" }, value = weekdays, width = 72 }),
    }),
    section("Sliders", "Pick a value on a range: continuous, discrete with ticks, two-thumb range, and centered.", {
        row { width = "fill", wrap = true, line_spacing = 24,
            spacing = 48,
            children = {
                column {
                    spacing = 16,
                    children = {
                        variant("Continuous", row {
                            spacing = 12,
                            children = { m3.icon("volume_up", c.on_surface_variant, 24, { margin = { top = 48 } }), m3.slider("volume", { value = volume, width = 340 }) },
                        }),
                        variant("Sizes: s, m", column {
                            spacing = 8,
                            children = {
                                m3.slider("size_s", { size = "s", value = volume, width = 380 }),
                                m3.slider("size_m", { size = "m", value = volume, width = 380 }),
                            },
                        }),
                        variant("Scaled: min 16, max 30, step 1", m3.slider("scaled", { min = 16, max = 30, step = 1, value = state("m3_sel_temp", 21), width = 380 })),
                        variant("Range", m3.slider("range", { kind = "range", low = lo, value = hi, width = 380 })),
                        variant("Icon in the track, size m", m3.slider("icon", { size = "m", icon = "volume_up", value = tall_icon, width = 380 })),
                        m3.text("Focus a handle: arrows step, Page Up and Down leap, Home and End jump to the ends.", c.on_surface_variant, "body_small"),
                    },
                },
                column {
                    spacing = 16,
                    children = {
                        variant("Discrete: ticks and a value label", m3.slider("discrete", { kind = "discrete", value = discrete, steps = 5, width = 380 })),
                        variant("Centered", m3.slider("centered", {
                            kind = "centered",
                            value = centered,
                            width = 380,
                            format = function(v) return tostring(math.floor((v - 0.5) * 200 + 0.5)) end,
                        })),
                    },
                },
            },
        },
    }, WIDE),
    section("Vertical sliders", "The same sliders set on end: they run bottom to top and the bubble sits to the right.", {
        row { width = "fill", wrap = true, line_spacing = 24,
            spacing = 48,
            children = {
                variant("Continuous", m3.slider("v_cont", { vertical = true, size = "m", value = tall, width = 220, icon = "brightness_6" })),
                variant("Discrete", m3.slider("v_disc", { vertical = true, kind = "discrete", value = tall, steps = 5, width = 220 })),
                variant("Range", m3.slider("v_range", { vertical = true, kind = "range", low = tall_range_lo, value = tall_range_hi, width = 220 })),
                variant("Centered", m3.slider("v_cent", { vertical = true, kind = "centered", value = tall_icon, width = 220 })),
            },
        },
    }),
    section("Menus", "An exposed dropdown: a field that opens a menu of options right under it. A grouped menu is rounded containers apart.", {
        cluster({
            variant("Grouped (Expressive)", m3.button("menu_grouped", {
                kind = "secondary",
                label = "Grouped menu",
                icon = "menu_open",
                props = { geometry = geometry("m3_demo_grouped") },
                on_click = function()
                    m3.open_menu {
                        anchor = geometry("m3_demo_grouped"),
                        items = {
                            { group = { { icon = "content_cut", label = "Cut" }, { icon = "content_copy", label = "Copy" }, { icon = "content_paste", label = "Paste" } } },
                            { group = { { icon = "select_all", label = "Select all" }, { icon = "find_in_page", label = "Find" } } },
                            { gap = true },
                            { group = { { icon = "delete", label = "Delete", on_click = function() notify { title = "Deleted" } end } } },
                        },
                    }
                end,
            })),
            variant("Outlined", m3.dropdown("fruit", { label = "Fruit", items = { "Apple", "Banana", "Cherry", "Mango", "Peach" }, value = state("m3_demo_fruit", "Banana") })),
            variant("Filled", m3.dropdown("sort", { kind = "filled", label = "Sort by", items = { "Relevance", "Newest", "Rating" }, value = state("m3_demo_sort", "Newest") })),
        }),
    }),
    section("Date picker", "Pick a day or a range from a month grid, docked under a field or modal. The pencil icon in the modal switches to typed, masked dates.", {
        pickers {
            variant("Docked", m3.date_picker("date", { label = "Date" }), 56),
            variant("Modal", m3.button("dp_modal", { kind = "secondary", label = "Pick a date", icon = "calendar_month", on_click = function() m3.open_date_picker({}) end }), 56),
            variant("Modal range", m3.button("dp_range", { kind = "secondary", label = "Pick a range", icon = "date_range", on_click = function() m3.open_date_picker({ range = true }) end }), 56),
        },
        pickers {
            variant("Typed date", m3.button("dp_input", { kind = "secondary", label = "Enter a date", icon = "edit", on_click = function() m3.open_date_picker({ input = true }) end }), 56),
            variant("Typed range: end not before start", m3.button("dp_range_input", { kind = "secondary", label = "Enter a range", icon = "edit_calendar", on_click = function() m3.open_date_picker({ range = true, input = true }) end }), 56),
        },
    }, WIDE),
    section("Time picker", "Drag the dial: the hour first, then the minutes. The keyboard icon switches to typed hour and minute fields.", {
        pickers {
            variant("Field, 12 h dial", m3.time_picker("time", { label = "Time" }), 56),
            variant("Field, 24 h dial", m3.time_picker("time24", { label = "24 h", h24 = true }), 56),
            variant("Modal dial", m3.button("tp_open", { kind = "secondary", label = "Pick a time", icon = "schedule", on_click = function() m3.open_time_picker({}) end }), 56),
        },
        pickers {
            variant("Typed, AM or PM", m3.button("tp_input", { kind = "secondary", label = "Enter a time", icon = "keyboard", on_click = function() m3.open_time_picker({ input = true }) end }), 56),
            variant("Field, typed 24 h: 24 or 60 blocks OK", m3.time_picker("time24i", { label = "24 h input", h24 = true, input = true }), 56),
        },
    }, WIDE),
}
