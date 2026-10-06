-- M3 checkbox: an 18px box in a 40px state layer. The tick and the dash are round-capped strokes
-- that draw out by animating `trim_end`.
local theme = require("m3.theme")
local core = require("m3.core")
local sel = require("m3.internal.selection")

local pick = theme.pick
local CLEAR = theme.CLEAR
local interactive, merge = core.interactive, core.merge
local QUICK, get, labelled, disabled_look, enabled = sel.QUICK, sel.get, sel.labelled, sel.disabled_look, sel.enabled

local M = {}

-- A plain value or a signal: `sig(x)` always gives a signal.
local function sig(x) return type(x) == "userdata" and x or theme.scheme:map(function() return x end) end

local function stroke(points, shown, color)
    return path {
        width = 18,
        height = 18,
        stroke = color,
        stroke_width = 2,
        stroke_cap = "round",
        stroke_join = "round",
        trim_end = shown,
        commands = { { op = "M", points = points[1] }, { op = "L", points = points[2] }, points[3] and { op = "L", points = points[3] } or nil },
        animate = { trim_end = { duration = 250, easing = theme.easing.standard } },
    }
end

---@param id string
---@param status Signal<"unchecked"|"checked"|"indeterminate">
---@param opts { label?: string, error?: boolean|Signal<boolean>, disabled?: boolean|Signal<boolean> }
---@param toggle fun()
---@return Node
-- `status` is a signal of "unchecked", "checked" or "indeterminate"; `toggle` runs on click.
local function checkbox_node(id, status, opts, toggle)
    local err = sig(opts.error)
    local ticked = status:map(function(s) return s ~= "unchecked" end)
    local function role(e) return e and "error" or "primary" end
    local mark = pick(err, "on_error", "on_primary")
    local box = rect {
        width = 18,
        height = 18,
        radius = 2,
        align_h = "center",
        align_v = "center",
        background = computed({ ticked, err, theme.scheme }, function(on, e, s) return on and s[role(e)] or CLEAR end),
        border_width = 2,
        border_color = computed({ ticked, err, theme.scheme }, function(on, e, s)
            return on and s[role(e)] or e and s.error or s.on_surface_variant
        end),
        animate = { background = QUICK, border_color = QUICK },
        children = {
            stroke({ { 4, 9.5 }, { 7.5, 13 }, { 14, 5.5 } }, status:map(function(v) return v == "checked" and 1 or 0 end), mark),
            stroke({ { 4, 9 }, { 14, 9 } }, status:map(function(v) return v == "indeterminate" and 1 or 0 end), mark),
        },
    }
    local node = interactive("cb_" .. id, {
        width = 40,
        height = 40,
        radius = 20,
        opacity = disabled_look(opts.disabled),
        hittable = enabled(opts.disabled),
        accessible_name = opts.label or id,
        on_click = function()
            if not get(opts.disabled) then
                toggle()
            end
        end,
    }, computed({ ticked, err, theme.scheme }, function(on, e, s) return on and s[role(e)] or s.on_surface end), box)
    return opts.label and labelled(node, opts.label) or node
end

-- Checkbox; unchecked, checked or indeterminate.
---@class m3.CheckboxOpts
---@field value? StateSignal<boolean|"indeterminate"> Default own, false. A click sets true, or false when it was true.
---@field label? string Text beside the box.
---@field error? boolean|Signal<boolean> Error colours.
---@field disabled? boolean|Signal<boolean>
---@field on_change? fun(value: boolean)
---@field [string] "no such property"

---@param id string
---@param opts? m3.CheckboxOpts
---@return Node
function M.checkbox(id, opts)
    opts = opts or {}
    local value = opts.value or state("m3_cb_" .. id, false)
    local status = value:map(function(v) return v == "indeterminate" and "indeterminate" or v and "checked" or "unchecked" end)
    return checkbox_node(id, status, opts, function()
        local next_value = value:get() ~= true
        value:set(next_value)
        if opts.on_change then
            opts.on_change(next_value)
        end
    end)
end

-- A parent checkbox over `items` (labels): checked when all are, indeterminate when some are.
---@class m3.CheckboxGroupOpts
---@field items string[] Child labels. Required.
---@field label? string The parent's label.
---@field value? StateSignal<table<string, boolean>> Set of checked labels; default own, the first item.
---@field error? boolean|Signal<boolean>
---@field disabled? boolean|Signal<boolean>
---@field on_change? fun(set: table<string, boolean>)
---@field [string] "no such property"

---@param id string
---@param opts m3.CheckboxGroupOpts
---@return Node
function M.checkbox_group(id, opts)
    local items = opts.items
    local value = opts.value or state("m3_cbg_" .. id, { [items[1]] = true })
    local function write(set)
        value:set(set)
        if opts.on_change then
            opts.on_change(set)
        end
    end
    local status = value:map(function(set)
        local on = 0
        for _, label in ipairs(items) do
            on = on + ((set or {})[label] and 1 or 0)
        end
        return on == 0 and "unchecked" or on == #items and "checked" or "indeterminate"
    end)
    local kids = {
        checkbox_node(id, status, opts, function()
            local set = {}
            for _, label in ipairs(items) do
                set[label] = status:get() ~= "checked" or nil
            end
            write(set)
        end),
    }
    for i, label in ipairs(items) do
        local own = value:map(function(set) return (set or {})[label] and "checked" or "unchecked" end)
        kids[#kids + 1] = row {
            margin = { left = 32 },
            children = {
                checkbox_node(id .. i, own, { label = label, error = opts.error, disabled = opts.disabled }, function()
                    local set = merge({}, value:get())
                    set[label] = not set[label] or nil
                    write(set)
                end),
            },
        }
    end
    return column { children = kids }
end

return M
