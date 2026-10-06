-- M3 chips: 32px, 8px corners.
local theme = require("m3.theme")
local core = require("m3.core")
local check = require("m3.internal.common").check
local keys = require("m3.internal.keys")

local c, pick = theme.c, theme.pick
local text, icon, interactive, merge = core.text, core.icon, core.interactive, core.merge
local FADE, CLEAR = theme.motion.fade, theme.CLEAR

local M = {}

local MOVE = { duration = 400, easing = theme.easing.emphasized_decelerate }
local APPEAR = { move = MOVE, opacity = { duration = 200, from = 0 }, exit = { duration = 150, opacity = 0 } }

---@param id string
---@param opts m3.ChipOpts
---@return Node
local function filter_chip(id, opts)
    local selected = opts.value or state("m3_chip_" .. id, false)
    local fg = pick(selected, "on_secondary_container", "on_surface_variant")
    return interactive("chip_" .. id, merge({
        height = 32,
        radius = 8,
        background = pick(selected, "secondary_container", opts.elevated and "surface_container_low" or "surface"),
        border_width = selected:map(function(on) return (on or opts.elevated) and 0 or 1 end),
        border_color = c.outline_variant,
        accessible_name = opts.label,
        disabled = opts.disabled,
        animate = { width = { duration = 200, easing = "out_cubic" } },
        on_click = function()
            selected:set(not selected:get())
            if opts.on_change then
                opts.on_change(selected:get())
            end
        end,
    }, opts.props), fg, row {
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
            interactive("chip_x_" .. id, merge({
                width = 24,
                height = 24,
                radius = 12,
                align_v = "center",
                accessible_name = "Remove " .. opts.label,
                on_click = opts.on_remove,
            }, opts.props), c.on_surface_variant, icon("close", c.on_surface_variant, 18, { align_h = "center" })),
        },
    }
end

-- Chip: assist, filter, input or suggestion.
---@class m3.ChipOpts
---@field kind? "assist"|"filter"|"input"|"suggestion" Default "assist".
---@field label string Required.
---@field icon? string Leading icon (assist).
---@field elevated? boolean Elevated look (assist, filter, suggestion).
---@field value? StateSignal<boolean> Selected (filter); default own, false.
---@field avatar? string Avatar text (input); default the label's first letter.
---@field on_click? fun() Assist and suggestion.
---@field on_change? fun(on: boolean) Filter.
---@field on_remove? fun() Input.
---@field disabled? boolean|Signal<boolean> Dimmed to 38% and inert (assist, filter, suggestion).
---@field appear? boolean Fade in and move when listed.
---@field props? table Extra node props for the container (assist, filter, suggestion), or the remove button (input).
---@field [string] "no such property"

---@param id string
---@param opts m3.ChipOpts
---@return Node
function M.chip(id, opts)
    local kind = opts.kind or "assist"
    if kind == "filter" then
        return filter_chip(id, opts)
    elseif kind == "input" then
        return input_chip(id, opts)
    end
    local glyph = kind == "assist" and opts.icon or nil
    return interactive("chip_" .. id, merge(merge({
        height = 32,
        radius = 8,
        background = opts.elevated and c.surface_container_low or CLEAR,
        border_width = opts.elevated and 0 or 1,
        border_color = c.outline_variant,
        accessible_name = opts.label,
        disabled = opts.disabled,
        opacity = opts.appear and 1 or nil,
        animate = opts.appear and APPEAR or nil,
        on_click = opts.on_click,
    }, theme.elevation[opts.elevated and 1 or 0]), opts.props), c.on_surface, row {
        height = "fill",
        align_v = "center",
        spacing = 8,
        padding = { left = glyph and 8 or 16, right = 16 },
        children = glyph and { icon(glyph, c.primary, 18), text(opts.label, c.on_surface, "label_large") } or { text(opts.label, c.on_surface, "label_large") },
    })
end

-- A row of assist, filter or suggestion chips the arrow keys move across.
---@class m3.ChipGroupOpts
---@field items m3.ChipOpts[] Each chip's opts, without an id.
---@field [string] "no such property"

---@param id string
---@param opts m3.ChipGroupOpts
---@return Node
function M.chip_group(id, opts)
    local bind = keys.roving("chips_" .. id, #opts.items)
    local kids = {}
    for i, item in ipairs(opts.items) do
        kids[i] = M.chip(id .. "_" .. i, merge(merge({}, item), { props = bind(i, merge({}, item.props)) }))
    end
    return row { spacing = 8, children = kids }
end

-- Arrow-key roving for a chip list that grows and shrinks: `keys.roving` fixes its count, so each
-- chip's focus target is named by its label and `order()` lists the labels now shown. Left and Right,
-- Home and End move focus. Returns `bind(label, props)`.
local function label_roving(name, order)
    local targets = {}
    return function(label, props)
        targets[label] = targets[label] or focus_target("m3_rove_" .. name .. "_" .. label)
        props.focus_target = targets[label]
        props.on_key = function(key)
            local list, at = order() or {}, 1
            for i, l in ipairs(list) do
                if l == label then
                    at = i
                end
            end
            local to = ({ Left = at - 1, Right = at + 1, Home = 1, End = #list })[key.name]
            if not to then
                return false
            end
            local next = targets[list[(to - 1) % #list + 1]]
            if next then
                next:request()
            end
            return true
        end
        return props
    end
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

-- A row of removable input chips; the arrow keys move between their remove buttons.
---@class m3.InputChipsOpts
---@field value? StateSignal<string[]> The labels; default own, empty.
---@field [string] "no such property"

---@param id string
---@param opts? m3.InputChipsOpts
---@return Node
function M.input_chips(id, opts)
    opts = opts or {}
    local value = opts.value or state("m3_ichips_" .. id, {})
    local bind = label_roving("input_" .. id, function() return value:get() end)
    return list {
        width = "fill",
        height = 32,
        direction = "horizontal",
        spacing = 8,
        source = value,
        key = function(label) return label end,
        itemfn = function(label)
            return M.chip(id .. "_" .. label, { kind = "input", label = label, props = bind(label, {}), on_remove = function() value:set(without(value:get(), label)) end })
        end,
    }
end

-- Suggestion chips for the `options` not yet in `value`; picking one appends it. The arrow keys move between them.
---@class m3.SuggestionChipsOpts
---@field options string[] Required.
---@field value StateSignal<string[]> The labels, shared with input_chips. Required.
---@field [string] "no such property"

---@param id string
---@param opts m3.SuggestionChipsOpts
---@return Node
function M.suggestion_chips(id, opts)
    local value = opts.value
    local left = value:map(function(have)
        local rest = {}
        for _, option in ipairs(opts.options) do
            if #without(have, option) == #(have or {}) then
                rest[#rest + 1] = option
            end
        end
        return rest
    end)
    local bind = label_roving("suggest_" .. id, function() return left:get() end)
    return list {
        width = "fill",
        height = 32,
        direction = "horizontal",
        spacing = 8,
        source = left,
        key = function(label) return label end,
        itemfn = function(label)
            return M.chip(id .. "_" .. label, {
                kind = "suggestion",
                label = label,
                appear = true,
                props = bind(label, {}),
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
