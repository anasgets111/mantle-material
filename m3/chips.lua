-- M3 chips: 32px, 8px corners.
local theme = require("m3.theme")
local core = require("m3.core")
local check = require("m3.internal.common").check

local c, pick = theme.c, theme.pick
local text, icon, interactive, merge = core.text, core.icon, core.interactive, core.merge
local FADE, CLEAR = theme.motion.fade, theme.CLEAR

local M = {}

local MOVE = { duration = 400, easing = theme.easing.emphasized_decelerate }
local APPEAR = { move = MOVE, opacity = { duration = 200, from = 0 }, exit = { duration = 150, opacity = 0 } }


local function filter_chip(id, opts)
    local selected = opts.value or state("m3_chip_" .. id, false)
    local fg = pick(selected, "on_secondary_container", "on_surface_variant")
    return interactive("chip_" .. id, {
        height = 32,
        radius = 8,
        background = pick(selected, "secondary_container", "surface"),
        border_width = selected:map(function(on) return on and 0 or 1 end),
        border_color = c.outline_variant,
        animate = { width = { duration = 200, easing = "out_cubic" } },
        on_click = function()
            selected:set(not selected:get())
            if opts.on_change then
                opts.on_change(selected:get())
            end
        end,
    }, fg, row {
        height = "fill",
        align_v = "center",
        spacing = 8,
        padding = selected:map(function(on) return { left = on and 8 or 16, right = 16 } end),
        children = check(selected, fg, text(opts.label, fg, "label_large", { id = "label" })),
    })
end

local function input_chip(id, opts)
    return row {
        height = 32,
        radius = 8,
        align_v = "center",
        spacing = 8,
        padding = { left = 4, right = 4 },
        border_width = 1,
        border_color = c.outline_variant,
        opacity = 1,
        animate = merge({ border_color = FADE }, APPEAR),
        children = {
            rect {
                width = 24,
                height = 24,
                radius = 12,
                align_v = "center",
                background = c.primary_container,
                children = { text(opts.avatar or opts.label:sub(1, 1), c.on_primary_container, "label_medium", { align_h = "center" }) },
            },
            text(opts.label, c.on_surface_variant, "label_large", { align_v = "center" }),
            interactive("chip_x_" .. id, {
                width = 24,
                height = 24,
                radius = 12,
                align_v = "center",
                accessible_name = "Remove " .. opts.label,
                on_click = opts.on_remove,
            }, c.on_surface_variant, icon("close", c.on_surface_variant, 18, { align_h = "center" })),
        },
    }
end

-- opts: kind ("assist", "filter", "input" or "suggestion"), label, icon (assist), elevated (assist,
-- suggestion), value (filter: state of selected), avatar (input: a letter), on_click, on_change(on)
-- (filter), on_remove (input), appear (fade in and move when listed).
function M.chip(id, opts)
    local kind = opts.kind or "assist"
    if kind == "filter" then
        return filter_chip(id, opts)
    elseif kind == "input" then
        return input_chip(id, opts)
    end
    local glyph = kind == "assist" and opts.icon or nil
    return interactive("chip_" .. id, merge({
        height = 32,
        radius = 8,
        background = opts.elevated and c.surface_container_low or CLEAR,
        border_width = opts.elevated and 0 or 1,
        border_color = c.outline_variant,
        accessible_name = opts.label,
        opacity = opts.appear and 1 or nil,
        animate = opts.appear and APPEAR or nil,
        on_click = opts.on_click,
    }, theme.elevation[opts.elevated and 1 or 0]), c.on_surface, row {
        height = "fill",
        align_v = "center",
        spacing = 8,
        padding = { left = glyph and 8 or 16, right = 16 },
        children = glyph and { icon(glyph, c.primary, 18), text(opts.label, c.on_surface, "label_large") } or { text(opts.label, c.on_surface, "label_large") },
    })
end

local function without(names, gone)
    local kept = {}
    for _, n in ipairs(names or {}) do
        if n ~= gone then
            kept[#kept + 1] = n
        end
    end
    return kept
end

-- A row of removable input chips. opts: value (state: the list of labels).
function M.input_chips(id, opts)
    local value = opts.value or state("m3_ichips_" .. id, {})
    return list {
        width = "fill",
        height = 32,
        direction = "horizontal",
        spacing = 8,
        source = value,
        key = function(label) return label end,
        itemfn = function(label)
            return M.chip(id .. "_" .. label, { kind = "input", label = label, on_remove = function() value:set(without(value:get(), label)) end })
        end,
    }
end

-- Suggestion chips for the `options` not yet in `value`; picking one appends it. opts: options,
-- value (state: the list of labels, shared with input_chips).
function M.suggestion_chips(id, opts)
    local value = opts.value
    return list {
        width = "fill",
        height = 32,
        direction = "horizontal",
        spacing = 8,
        source = value:map(function(have)
            local left = {}
            for _, option in ipairs(opts.options) do
                if #without(have, option) == #(have or {}) then
                    left[#left + 1] = option
                end
            end
            return left
        end),
        key = function(label) return label end,
        itemfn = function(label)
            return M.chip(id .. "_" .. label, {
                kind = "suggestion",
                label = label,
                appear = true,
                on_click = function()
                    local have = { table.unpack(value:get() or {}) }
                    have[#have + 1] = label
                    value:set(have)
                end,
            })
        end,
    }
end

return M
