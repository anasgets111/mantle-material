-- Actions: common buttons, icon buttons, FABs, button groups and split buttons.
local m3 = require("m3")
local section = require("demo.section")

local c = m3.theme.c
local notify = m3.overlay.notify

local function caption(label)
    return m3.text(label, c.on_surface_variant, "label_medium", { margin = { top = 4 } })
end

local function detail(description)
    return m3.text(description, c.on_surface_variant, "body_medium", { wrap = "word", width = "fill" })
end

local function line(children, spacing)
    return row { width = "fill", wrap = true, spacing = spacing or 12, line_spacing = 12, children = children }
end

local function toggle(name, default)
    return state("m3_a_" .. name, default or false)
end


---------------------------------------------------------------------------------------------------

-- Elevated buttons are filled for a surface; on a container they would read as holes.
local on_page = { background = c.surface, border_width = 1, border_color = c.outline_variant }

local KINDS = { { "filled", "Filled" }, { "tonal", "Tonal" }, { "elevated", "Elevated" }, { "outlined", "Outlined" }, { "text", "Text" } }
local function buttons(prefix, o)
    local list = {}
    for i, k in ipairs(KINDS) do
        list[i] = m3.button(prefix .. k[1], {
            kind = k[1], label = k[2], icon = o.icon, shape = o.shape, size = o.size,
            on_click = function() notify(k[2] .. " button") end,
        })
    end
    return list
end

local sizes = {}
for _, size in ipairs({ "xs", "s", "m", "l", "xl" }) do
    sizes[#sizes + 1] = m3.button("size_" .. size, {
        kind = "filled", size = size, label = "Save", icon = "save", props = { align_v = "center" },
        on_click = function() notify("Size " .. size:upper()) end,
    })
end

local toggle_buttons = {}
for _, kind in ipairs({ "filled", "tonal", "elevated", "outlined" }) do
    local selected = toggle("tb_" .. kind)
    toggle_buttons[#toggle_buttons + 1] = m3.button("tb_" .. kind, {
        kind = kind, label = kind:sub(1, 1):upper() .. kind:sub(2), icon = "favorite", value = selected,
    })
end

local common = section.wide(section.card("Common buttons", {
    detail("Buttons start an action. Five emphasis levels, five Expressive sizes, round or square, and each one's corners spring smaller while pressed."),
    line(buttons("btn_", {})),
    line(buttons("btn_icon_", { icon = "add" })),
    caption("Sizes: XS 32, S 40, M 56, L 96, XL 136"),
    line(sizes),
    caption("Round and square shapes"),
    line({
        m3.button("shape_round", { kind = "tonal", size = "m", label = "Round", on_click = function() notify("Round") end }),
        m3.button("shape_square", { kind = "tonal", size = "m", label = "Square", shape = "square", on_click = function() notify("Square") end }),
    }),
    caption("Toggle buttons: selecting morphs round to square"),
    line(toggle_buttons),
}, on_page))

---------------------------------------------------------------------------------------------------

local icon_kinds = {}
local icon_toggles = {}
for _, kind in ipairs({ "standard", "filled", "tonal", "outlined" }) do
    icon_kinds[#icon_kinds + 1] = m3.icon_button("ib_" .. kind, { kind = kind, icon = "settings", on_click = function() notify(kind .. " icon button") end })
    local selected = toggle("ib_" .. kind)
    icon_toggles[#icon_toggles + 1] = m3.icon_button("ibt_" .. kind, {
        kind = kind, icon = "favorite", value = selected,
    })
end
local icon_sizes, icon_widths = {}, {}
for _, size in ipairs({ "xs", "s", "m", "l", "xl" }) do
    icon_sizes[#icon_sizes + 1] = m3.icon_button("ibs_" .. size, { kind = "tonal", size = size, icon = "star", props = { align_v = "center" } })
    for _, width in ipairs({ "narrow", "default", "wide" }) do
        if size == "s" or size == "m" then
            icon_widths[#icon_widths + 1] = m3.icon_button("ibw_" .. size .. width, { kind = "filled", size = size, width = width, icon = "star", value = toggle("ibw_" .. size .. width), props = { align_v = "center" } })
        end
    end
end

local icons = section.card("Icon buttons", {
    detail("Icon buttons carry one glyph. A toggle fills its glyph and morphs round to square when selected."),
    line(icon_kinds),
    caption("Toggle: favourite on and off"),
    line(icon_toggles),
    caption("Sizes: XS, S, M, L, XL"),
    line(icon_sizes),
    caption("Widths: narrow, default and wide, on S then M; each toggles"),
    line(icon_widths, 8),
})

---------------------------------------------------------------------------------------------------

local expanded = toggle("efab", true)
local menu_open = toggle("fab_menu")

local fabs = section.wide(section.card("Floating action buttons", {
    detail("A FAB promotes the screen's main action. Extended collapses to a FAB; the FAB menu opens a list of related actions."),
    row { wrap = true, line_spacing = 24,
        width = "fill",
        spacing = 32,
        children = {
            column {
                width = 460,
                spacing = 16,
                children = {
                    caption("Small 40, FAB 56, large 96"),
                    row {
                        spacing = 16,
                        children = {
                            m3.fab("fab_small", { size = "small", icon = "edit", tone = "secondary", props = { align_v = "center" }, on_click = function() notify("Small FAB") end }),
                            m3.fab("fab_reg", { icon = "edit", props = { align_v = "center" }, on_click = function() notify("FAB") end }),
                            m3.fab("fab_large", { size = "large", icon = "edit", tone = "tertiary", props = { align_v = "center" }, on_click = function() notify("Large FAB") end }),
                            m3.fab("fab_surface", { icon = "edit", tone = "surface", props = { align_v = "center" }, on_click = function() notify("Surface FAB") end }),
                        },
                    },
                    caption("Extended: click to collapse and expand"),
                    m3.extended_fab("fab_ext", {
                        icon = "edit", label = "Compose", expanded = expanded,
                        on_click = function() expanded:set(not expanded:get()) end,
                    }),
                },
            },
            column {
                width = "fill",
                spacing = 8,
                children = {
                    caption("FAB menu"),
                    rect {
                        width = 260,
                        height = 300,
                        children = {
                            m3.fab_menu("fabm", {
                                items = {
                                    { icon = "photo_camera", label = "Photo", on_click = function() notify("Photo") end },
                                    { icon = "mic", label = "Voice note", on_click = function() notify("Voice note") end },
                                    { icon = "attach_file", label = "Attachment", on_click = function() notify("Attachment") end },
                                    { icon = "draw", label = "Sketch", on_click = function() notify("Sketch") end },
                                },
                                value = menu_open,
                            }),
                        },
                    },
                },
            },
        },
    },
}))

---------------------------------------------------------------------------------------------------

local pick_a = state("m3_a_connected_a", 1)
local pick_b = state("m3_a_connected_b", 2)

local groups = section.wide(section.card("Button groups", {
    detail("Groups gather related actions. In a standard group the neighbours of a pressed button squish; a connected group is one selection whose chosen item turns fully round."),
    caption("Standard: press and hold a button"),
    m3.button_group("grp_filled", {
        kind = "standard",
        items = { { label = "Day", icon = "light_mode" }, { label = "Week", icon = "calendar_view_week" }, { label = "Month", icon = "calendar_month" } },
    }),
    caption("Standard and connected groups: Tab in, then the arrows, Home and End move between buttons"),
    caption("Connected"),
    line({
        m3.button_group("grp_c_filled", { kind = "connected", button_kind = "filled", items = { { label = "Walk" }, { label = "Cycle" }, { label = "Drive" } }, value = pick_a }),
        m3.button_group("grp_c_outlined", { kind = "connected", button_kind = "outlined", items = { { label = "Small" }, { label = "Medium" }, { label = "Large" } }, value = pick_b }),
    }, 32),
}))

---------------------------------------------------------------------------------------------------

local splits = {}
for i, kind in ipairs({ "filled", "tonal", "elevated", "outlined" }) do
    splits[i] = m3.split_button("split_" .. kind, {
        kind = kind, label = "Send", icon = "send", on_click = function() notify("Sent") end,
        items = {
            { icon = "schedule_send", label = "Schedule send", on_click = function() notify("Schedule send") end },
            { icon = "drafts", label = "Save as draft", on_click = function() notify("Save as draft") end },
            { icon = "delete", label = "Discard", on_click = function() notify("Discard") end },
        },
    })
end

local split = section.wide(section.card("Split buttons", {
    detail("A split button pairs a primary action with a menu of alternatives. The chevron turns over and its button rounds while the menu is open."),
    line(splits, 24),
}, on_page))

---------------------------------------------------------------------------------------------------

local view = state("m3_a_view", "Day")
local features = state("m3_a_features", "Wi-Fi")
local styles = state("m3_a_styles", { Bold = true })
local align = state("m3_a_align", "left")

local segmented = section.card("Segmented buttons", {
    detail("A segmented button is one outlined control of two to five choices; the selected one is tinted and checked."),
    m3.segmented_button("seg_view", { options = { "Day", "Week", "Month" }, value = view, width = 96 }),
    caption("Four options"),
    m3.segmented_button("seg_features", { options = { "Wi-Fi", "Bluetooth", "NFC", "VPN" }, value = features, width = 96 }),
    caption("Multi-select, icon only: any number can be on"),
    m3.segmented_button("seg_styles", {
        multi = true,
        options = { { icon = "format_bold", name = "Bold" }, { icon = "format_italic", name = "Italic" }, { icon = "format_underlined", name = "Underline" } },
        value = styles,
    }),
    caption("Icon and label, single choice"),
    m3.segmented_button("seg_align", {
        options = { { icon = "format_align_left", label = "Left", name = "left" }, { icon = "format_align_center", label = "Centre", name = "centre" }, { icon = "format_align_right", label = "Right", name = "right" } },
        value = align,
        width = 104,
    }),
    caption("Arrow keys, Home and End move focus between segments"),
})

return section.page { common, icons, fabs, groups, split, segmented }
