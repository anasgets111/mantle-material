-- List items: 56, 72 or 88 high by line count; `list` is a scrolling keyed list with move / enter / exit animation.
local core = require("m3.core")
local theme = require("m3.theme")
local photo = require("m3.internal.common").photo
local keys = require("m3.internal.keys")
local controls = { checkbox = require("m3.selection.checkbox").checkbox, switch = require("m3.selection.switch").switch }

local text, icon, interactive, merge = core.text, core.icon, core.interactive, core.merge
local c, FADE, easing, CLEAR = theme.c, theme.motion.fade, theme.easing, theme.CLEAR

local M = {}

-- The constant false signal a `list` row gets for `emphasized` and `selected` without selection.
local OFF = theme.scheme:map(function() return false end)

local MOVE = { duration = 400, easing = easing.emphasized_decelerate }

-- Segment corners: the list's ends round to 16, the corners between segments to 4.
local SEGMENT_RADIUS = {
    first = { top_left = 16, top_right = 16, bottom_left = 4, bottom_right = 4 },
    middle = 4,
    last = { top_left = 4, top_right = 4, bottom_left = 16, bottom_right = 16 },
    only = 16,
}

local function leading(spec, align, fg)
    if spec.icon then
        return icon(spec.icon, fg, 24, { align_v = align })
    elseif spec.avatar then
        return rect {
            width = 40,
            height = 40,
            radius = 20,
            align_v = align,
            background = c.primary_container,
            animate = { background = FADE },
            children = { text(spec.avatar, c.on_primary_container, "title_medium", { align_h = "center" }) },
        }
    elseif spec.image then
        return photo(spec.image, { width = 56, height = 56, radius = 8, align_v = align })
    end
    return spec.node
end

local function trailing(id, spec, align, fg)
    if spec.text then
        return text(spec.text, fg, "label_small", { align_v = align })
    end
    local control = spec.checkbox and "checkbox" or spec.switch and "switch"
    if control then
        local value = spec[control]
        if value == true then
            value = state("m3_" .. id .. "_" .. control, control == "switch")
        end
        return rect { align_v = align, children = { controls[control](id .. "_" .. control, { value = value }) } }
    end
    return spec.node
end

---@class m3.ListLeading
---@field icon? string Icon name.
---@field avatar? string Avatar letter.
---@field image? string Image source.
---@field node? Node
---@field [string] "no such property"

---@class m3.ListTrailing
---@field text? string|Signal<string>
---@field checkbox? true|StateSignal<boolean> `true` keeps its own state.
---@field switch? true|StateSignal<boolean> `true` keeps its own state.
---@field node? Node
---@field [string] "no such property"

-- A 1-3 line row; height follows the line count (56, 72, 88).
---@class m3.ListItemOpts
---@field lines (string|Signal<string>)[] One to three lines. Required.
---@field leading? m3.ListLeading
---@field trailing? m3.ListTrailing
---@field on_click? fun()
---@field animated? boolean Move, fade in and exit, for rows of a keyed `list`.
---@field selected? Signal<boolean> The selected container colour (`secondary_container`) behind the row.
---@field segment? "first"|"middle"|"last"|"only" A separate rounded segment on `surface_container_high`; the ends of the list round to 16, the corners between segments to 4. `item_list` sets it.
---@field props? table Extra node props (e.g. a roving binder's).
---@field [string] "no such property"

---@param id string
---@param opts m3.ListItemOpts
---@return Node
function M.list_item(id, opts)
    local lines, selected = opts.lines, opts.selected
    local strong = selected and theme.pick(selected, "on_secondary_container", "on_surface") or c.on_surface
    local weak = selected and theme.pick(selected, "on_secondary_container", "on_surface_variant") or c.on_surface_variant
    local texts = { text(lines[1], strong, "body_large") }
    for i = 2, #lines do
        texts[i] = text(lines[i], weak, "body_medium", { wrap = "word", width = "fill" })
    end
    local align = #lines == 3 and "start" or "center"
    local kids = {}
    if opts.leading then
        kids[1] = leading(opts.leading, align, weak)
    end
    kids[#kids + 1] = column { width = "fill", align_v = align, children = texts }
    if opts.trailing then
        kids[#kids + 1] = trailing(id, opts.trailing, align, weak)
    end
    local props = merge({ width = "fill", height = ({ 56, 72, 88 })[#lines], on_click = opts.on_click }, opts.props)
    if opts.segment or selected then
        local role = opts.segment and "surface_container_high"
        props.background = selected and computed({ selected, theme.scheme }, function(on, s) return on and s.secondary_container or role and s[role] or CLEAR end)
            or role and c.surface_container_high
            or CLEAR
        props.radius = SEGMENT_RADIUS[opts.segment]
    end
    if opts.animated then
        props.opacity = 1
        props.animate = { move = MOVE, opacity = { duration = 200, from = 0 }, exit = { duration = 150, opacity = 0 } }
    end
    return interactive(id, props, strong, row {
        width = "fill",
        height = "fill",
        align_v = align,
        spacing = 16,
        padding = { left = 16, right = opts.trailing and opts.trailing.node and 12 or 16, top = align == "start" and 12 or 0 },
        children = kids,
    })
end

-- A column of rows in one list: with `segmented` each is its own rounded segment, 2 apart
-- (not in the spec: the gap), and `value` makes them selectable. Tab in, then Up, Down, Home and End move focus.
---@class m3.ListEntry: m3.ListItemOpts
---@field key? string Identity for `value`; default the position.
---@field [string] "no such property"

---@class m3.ItemListOpts
---@field items m3.ListEntry[] Required.
---@field segmented? boolean
---@field value? StateSignal<string?> The `key` of the selected row: a click selects.
---@field width? number|"fill" Default "fill".
---@field [string] "no such property"

---@param id string
---@param opts m3.ItemListOpts
---@return Node
function M.item_list(id, opts)
    local n = #opts.items
    local bind = keys.roving("list_" .. id, n, { axis = "vertical" })
    local rows = {}
    for i, entry in ipairs(opts.items) do
        local key = entry.key or tostring(i)
        local item = merge({}, entry)
        item.key = nil
        item.props = bind(i, (entry.props or {}) --[[@as table]])
        item.segment = opts.segmented and (n == 1 and "only" or i == 1 and "first" or i == n and "last" or "middle") or nil
        if opts.value then
            item.selected = opts.value:map(function(picked) return picked == key end)
            item.on_click = function()
                opts.value:set(key)
                if entry.on_click then
                    entry.on_click()
                end
            end
        end
        rows[i] = M.list_item(id .. "_" .. key, item)
    end
    return column { width = opts.width or "fill", spacing = opts.segmented and 2 or 0, children = rows }
end

-- A scrolling keyed list with move / enter / exit animation.
---@class m3.ListOpts
---@field items any[]|Signal<any[]> The items. Required.
---@field query? Signal<string> Filters `items` by fuzzy match on `search`, best match first (item order breaks ties).
---@field search? fun(item: any): string The text `query` matches. Required with `query`.
---@field key? fun(item: any): string Stable identity for move, exit and `value`; default the item's `label`, else `tostring`.
---@field row fun(item: any, emphasized: Signal<boolean>, selected: Signal<boolean>): Node Usually a `list_item` with `animated`. Required. Both signals follow `value` (this list has no inactive look, so they match), and stay false without `value` or `on_select`.
---@field value? StateSignal<string> The selected key; with `value` or `on_select` a click on a row selects it, tinted `secondary_container`. Leave the row's own `on_click` unset.
---@field on_select? fun(item: any) After a click selects an item.
---@field height? number|"fill"
---@field width? number|"fill" Default "fill".
---@field [string] "no such property"

---@param id string
---@param opts m3.ListOpts
---@return Node
function M.list(id, opts)
    local items = opts.items
    if opts.query then
        if type(items) ~= "userdata" then
            local fixed = items
            items = theme.scheme:map(function() return fixed end)
        end
        items = computed({ items, opts.query }, function(entries, q)
            local hits = {}
            for i, entry in ipairs(entries or {}) do
                local score = fuzzy(opts.search(entry), q or "")
                if score then
                    hits[#hits + 1] = { entry = entry, score = score, index = i }
                end
            end
            table.sort(hits, function(a, b)
                if a.score ~= b.score then
                    return a.score > b.score
                end
                return a.index < b.index
            end)
            for i, hit in ipairs(hits) do
                hits[i] = hit.entry
            end
            return hits
        end)
    end
    local key = opts.key or function(item) return type(item) == "table" and item.label or tostring(item) end
    local selectable = opts.value or opts.on_select
    return list {
        width = opts.width or "fill",
        height = opts.height,
        scroll = scroll("m3_" .. id),
        animate = { scroll = theme.motion.scroll },
        source = items,
        key = key,
        itemfn = function(item)
            if not selectable then
                return opts.row(item, OFF, OFF)
            end
            local k = key(item)
            local selected = opts.value and opts.value:map(function(v) return v == k end) or OFF
            return interactive("list_" .. id .. "_" .. k, {
                width = "fill",
                radius = 12,
                background = computed({ selected, theme.scheme }, function(on, s) return on and s.secondary_container or CLEAR end),
                opacity = 1,
                animate = { move = MOVE, opacity = { duration = 200, from = 0 }, exit = { duration = 150, opacity = 0 } },
                on_click = function()
                    if opts.value then
                        opts.value:set(k)
                    end
                    if opts.on_select then
                        opts.on_select(item)
                    end
                end,
            }, c.on_surface, opts.row(item, selected, selected))
        end,
    }
end

return M
