-- M3 Expressive floating action buttons: fab, extended_fab, fab_menu.
local theme = require("m3.theme")
local core = require("m3.core")
local internal = require("m3.internal.button")
local scrolled_down = require("m3.internal.common").scrolled_down

local c, FADE = theme.c, theme.motion.fade
local SPRING = theme.motion.spatial_fast
local merge, text, icon = core.merge, core.text, core.icon
local pressable = internal.pressable

local M = {}

local FABS = {
    small = { size = 40, icon = 24, radius = 12, press = 8 },
    fab = { size = 56, icon = 24, radius = 16, press = 12 },
    large = { size = 96, icon = 36, radius = 28, press = 20 },
}
local FAB_TONES = {
    primary = { bg = "primary_container", fg = "on_primary_container" },
    secondary = { bg = "secondary_container", fg = "on_secondary_container" },
    tertiary = { bg = "tertiary_container", fg = "on_tertiary_container" },
    surface = { bg = "surface_container_high", fg = "primary" },
}

---@alias m3.FabTone "primary"|"secondary"|"tertiary"|"surface"

-- Floating action button.
---@class m3.FabOpts
---@field size? "small"|"fab"|"large" Default "fab".
---@field tone? m3.FabTone Default "primary".
---@field icon string|Signal<string> Material Symbols name.
---@field disabled? boolean|Signal<boolean> Dimmed to 38% and inert.
---@field props? table Extra node props.
---@field on_click? fun()
---@field [string] "no such property"

---@param id string
---@param opts m3.FabOpts
---@return Node
function M.fab(id, opts)
    local sz, tone = FABS[opts.size or "fab"], FAB_TONES[opts.tone or "primary"]
    local held = state("m3_held_" .. id, false)
    return pressable(id, merge(merge({
        width = sz.size,
        height = sz.size,
        radius = held:map(function(down) return down and sz.press or sz.radius end),
        background = c[tone.bg],
        on_click = opts.on_click,
        disabled = opts.disabled,
    }, theme.elevation[3]), opts.props), c[tone.fg], icon(opts.icon, c[tone.fg], sz.icon, { align_h = "center" }), held)
end

-- Extended FAB that collapses to a plain FAB while `expanded` is false: the width springs and the
-- label fades. With `scroll` it collapses while the content scrolls down and expands on a scroll up.
---@class m3.ExtendedFabOpts
---@field tone? m3.FabTone Default "primary".
---@field icon string|Signal<string> Material Symbols name.
---@field label string|Signal<string>
---@field expanded? StateSignal<boolean> Default true; own state if omitted. Ignored with `scroll`.
---@field scroll? Signal<number> The content's scroll signal: collapses on a scroll down, expands on a scroll up.
---@field disabled? boolean|Signal<boolean> Dimmed to 38% and inert.
---@field props? table Extra node props.
---@field on_click? fun()
---@field [string] "no such property"

---@param id string
---@param opts m3.ExtendedFabOpts
---@return Node
function M.extended_fab(id, opts)
    local tone = FAB_TONES[opts.tone or "primary"]
    local held = state("m3_held_" .. id, false)
    local expanded = opts.scroll and scrolled_down(opts.scroll):map(function(away) return not away end) or opts.expanded or state("m3_expanded_" .. id, true)
    return pressable(id, merge({
        width = expanded:map(function(on) return on and 144 or 56 end),
        height = 56,
        radius = held:map(function(down) return down and 12 or 16 end),
        background = c[tone.bg],
        on_click = opts.on_click,
        disabled = opts.disabled,
        animate = { width = SPRING },
    }, theme.elevation[3]), c[tone.fg], row {
        height = "fill",
        align_v = "center",
        spacing = 12,
        padding = { left = 16 },
        children = {
            icon(opts.icon, c[tone.fg], 24),
            text(opts.label, c[tone.fg], "label_large", {
                font_size = 16,
                opacity = expanded:map(function(on) return on and 1 or 0 end),
                animate = { opacity = { duration = 150 }, foreground = FADE },
            }),
        },
    }, held)
end

-- FAB menu: the toggle FAB morphs from a rounded square to a circle and its glyph from add to
-- close, while the items spring in one by one, nearest the FAB first.
---@class m3.FabMenuItem
---@field icon string Material Symbols name.
---@field label string
---@field on_click? fun()

---@class m3.FabMenuOpts
---@field items m3.FabMenuItem[]
---@field value? StateSignal<boolean> Open state; own if omitted.
---@field [string] "no such property"

---@param id string
---@param opts m3.FabMenuOpts
---@return Node
function M.fab_menu(id, opts)
    local items = opts.items
    local open = opts.value or state("m3_open_" .. id, false)
    local held = state("m3_held_" .. id, false)
    local function item(i, it)
        local from_fab = #items - i
        return pressable(id .. "_item" .. i, {
            id = "item" .. i,
            height = 56,
            radius = 28,
            align_h = "end",
            background = c.primary_container,
            opacity = 1,
            scale = 1,
            translate = { y = 0 },
            origin = { x = 1, y = 1 },
            on_click = function()
                open:set(false)
                if it.on_click then
                    it.on_click()
                end
            end,
            animate = {
                opacity = { duration = 150, delay = from_fab * 40, from = 0 },
                scale = { spring = SPRING.spring, delay = from_fab * 40, from = 0.6 },
                translate = { spring = SPRING.spring, delay = from_fab * 40, from = { y = 24 } },
                exit = { duration = 120, delay = i * 15, opacity = 0, scale = 0.8 },
            },
        }, c.on_primary_container, row {
            height = "fill",
            align_v = "center",
            spacing = 8,
            padding = { left = 16, right = 24 },
            children = { icon(it.icon, c.on_primary_container, 24), text(it.label, c.on_primary_container, "label_large", { font_size = 16 }) },
        }, state("m3_held_" .. id .. "_item" .. i, false))
    end
    local menu = column {
        spacing = 4,
        align_h = "end",
        children = open:map(function(on)
            local kids = {}
            for i, it in ipairs(on and items or {}) do
                kids[i] = item(i, it)
            end
            return kids
        end),
    }
    local function glyph(glyph_name, on_when_open)
        return icon(glyph_name, c.on_primary, 24, {
            align_h = "center",
            opacity = open:map(function(o) return (o == on_when_open) and 1 or 0 end),
            rotate = open:map(function(o) return (o == on_when_open) and 0 or (on_when_open and -90 or 90) end),
            animate = { opacity = { duration = 150 }, rotate = SPRING, foreground = FADE },
        })
    end
    local toggle = pressable(id .. "_toggle", {
        width = 56,
        height = 56,
        radius = computed({ held, open }, function(down, on) return down and 12 or on and 28 or 16 end),
        align_h = "end",
        background = theme.pick(open, "primary", "primary_container"),
        on_click = function() open:set(not open:get()) end,
        shadows = theme.shadows[3],
    }, c.on_primary, rect { width = "fill", height = "fill", children = { glyph("close", true), glyph("add", false) } }, held)
    return column { spacing = 8, align_h = "end", align_v = "end", children = { menu, toggle } }
end

return M
