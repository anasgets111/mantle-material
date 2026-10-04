-- Selection: checkbox, radio, switch, chips, segmented button, sliders, menus and the pickers.
local m3 = require("m3")
local card = require("demo.section").card

local c = m3.theme.c
local notify = m3.overlay.notify

local function section(title, detail, children, props)
    table.insert(children, 1, m3.text(detail, c.on_surface_variant, "body_medium", { margin = { bottom = 4 } }))
    return card(title, children, props)
end

local function variant(caption, node)
    return column { spacing = 8, children = { node, m3.text(caption, c.on_surface_variant, "label_medium") } }
end

local function cluster(children) return row { spacing = 32, children = children } end

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

local function checkbox(id, label, initial, opts)
    opts = opts or {}
    opts.label, opts.value = label, state("m3_demo_cb_" .. id, initial)
    return m3.checkbox(id, opts)
end

return column {
    width = "fill",
    spacing = 16,
    children = {
        section("Checkbox", "Select one or more items from a set. The mark draws itself and the box fills.", {
            row {
                spacing = 24,
                children = {
                    variant("Unchecked", checkbox("plain", "Label", false)),
                    variant("Checked", checkbox("on", "Label", true)),
                    variant("Indeterminate", checkbox("mixed", "Label", "indeterminate")),
                    variant("Error", checkbox("err", "Label", false, { error = true })),
                    variant("Disabled", checkbox("dis", "Label", true, { disabled = true })),
                },
            },
            variant("A parent checkbox controls its children", m3.checkbox_group("parent", { label = "Notifications", items = { "Mentions", "Replies", "Reminders" } })),
        }),
        section("Radio button", "Select exactly one option from a set. The dot grows on a spring.", {
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
                    m3.chip("a1", { icon = "event", label = "Add to calendar", on_click = function() notify("Added to calendar") end }),
                    m3.chip("a2", { icon = "directions", label = "Directions", elevated = true, on_click = function() notify("Opening maps") end }),
                },
            }),
            variant("Filter", row {
                spacing = 8,
                children = {
                    m3.chip("c_open", { kind = "filter", label = "Open now", value = state("m3_chip_open", true) }),
                    m3.chip("c_rated", { kind = "filter", label = "Top rated", value = state("m3_chip_rated", false) }),
                    m3.chip("c_near", { kind = "filter", label = "Nearby", value = state("m3_chip_near", false) }),
                },
            }),
            variant("Input: remove with the close button", m3.input_chips("people", { value = people })),
            variant("Suggestion: adds to the input chips", m3.suggestion_chips("people", { options = { "Ada", "Alan", "Barbara", "Grace", "Ken", "Margaret", "Linus" }, value = people })),
        }),
        section("Segmented button", "Choose one range from two to five options.", {
            m3.segmented_button("seg", { options = { "Day", "Week", "Month" }, value = range, width = 96 }),
        }),
        section("Sliders", "Pick a value on a range: continuous, discrete with ticks, two-thumb range, and centered.", {
            row {
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
                            variant("Range", m3.slider("range", { kind = "range", low = lo, value = hi, width = 380 })),
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
        }),
        section("Menus", "An exposed dropdown: a field that opens a menu of options right under it.", {
            cluster({
                variant("Outlined", m3.dropdown("fruit", { label = "Fruit", options = { "Apple", "Banana", "Cherry", "Mango", "Peach" }, value = state("m3_demo_fruit", "Banana") })),
                variant("Filled", m3.dropdown("sort", { kind = "filled", label = "Sort by", options = { "Relevance", "Newest", "Rating" }, value = state("m3_demo_sort", "Newest") })),
            }),
        }),
        section("Date picker", "Pick a day or a range from a month grid. Docked under a field, or modal.", {
            row {
                spacing = 16,
                children = {
                    variant("Docked", m3.date_picker("date", { label = "Date" })),
                    variant("Modal", m3.button("dp_modal", { kind = "tonal", label = "Pick a date", icon = "calendar_month", on_click = function() m3.open_date_picker({}) end })),
                    variant("Modal range", m3.button("dp_range", { kind = "tonal", label = "Pick a range", icon = "date_range", on_click = function() m3.open_date_picker({ range = true }) end })),
                },
            },
        }),
        section("Time picker", "Drag the dial: the hour first, then the minutes.", {
            row {
                spacing = 16,
                children = {
                    variant("Selected time", m3.time_picker("time", { label = "Time" })),
                    variant("Modal dial", m3.button("tp_open", { kind = "tonal", label = "Pick a time", icon = "schedule", on_click = function() m3.open_time_picker({}) end })),
                },
            },
        }),
    },
}
