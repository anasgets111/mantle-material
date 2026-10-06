-- M3 menu: one layer under its anchor (or at the pointer) over a transparent scrim that closes it on
-- any click outside, kept inside the host. A checked item shows a check on a tinted row; an item
-- with a `submenu` opens it to the side. Arrow keys, Home, End, Enter, Escape and type-ahead steer it.
-- Overlay callbacks and anchors cannot live in named state, so the open spec stays in a Lua local
-- that the layer builder reads.
local theme = require("m3.theme")
local core = require("m3.core")
local overlay = require("m3.overlay")
local sel = require("m3.internal.selection")
local text_field = require("m3.inputs.text_field").text_field

local c, motion = theme.c, theme.motion
local text, icon, interactive = core.text, core.icon, core.interactive
local FADE = motion.fade
local QUICK, ZERO, tint, opacity_of = sel.QUICK, sel.ZERO, sel.tint, sel.opacity_of

local M = {}

local MENU = {
    row = 48,
    width = 224,
    below = 2,
    pad = 8, -- above the first and below the last item
    edge = 8, -- not in the spec: the least room left between a menu and the host's edge
    group = 16, -- the corner of a group's container in a grouped menu
    gap = 4, -- not in the spec: the space between group containers
}

-- Colour roles: standard, and the Expressive vibrant menu on the tertiary container.
local TONES = {
    standard = { bg = "surface_container", fg = "on_surface", sub = "on_surface_variant", pick = "secondary_container", on_pick = "on_secondary_container" },
    vibrant = { bg = "tertiary_container", fg = "on_tertiary_container", sub = "on_tertiary_container", pick = "tertiary", on_pick = "on_tertiary" },
}

local cursor = state("m3_menu_cursor", 0)
local sub = state("m3_menu_sub", 0)
local subsel = state("m3_menu_subsel", 0)
local deep = state("m3_menu_deep", false)
local menu_owner = state("m3_menu_owner", "")
local point = state("m3_menu_at", ZERO)
local box, sub_box = geometry("m3_menu_box"), geometry("m3_menu_sub_box")
local menu_shown = overlay.is_open("menu")

-- `x` moved so the span `size` stays inside [lo, hi] with the edge margin; it keeps `lo` if too big.
local function clamp(x, size, lo, hi)
    return math.max(lo + MENU.edge, math.min(x, hi - MENU.edge - size))
end

---@type table
local spec = {}

-- The flat list a menu works on: each `{ group = {...} }` entry's items, with a `{ gap = true }` between
-- groups (one is kept as given).
local function flatten(entries)
    local flat = {}
    for _, entry in ipairs(entries) do
        if entry.group then
            if #flat > 0 and not flat[#flat].gap then
                flat[#flat + 1] = { gap = true }
            end
            for _, item in ipairs(entry.group) do
                flat[#flat + 1] = item
            end
        else
            flat[#flat + 1] = entry
        end
    end
    return flat
end

local function selectable(item)
    return not (item.separator or item.header or item.disabled or item.gap)
end

local function pick(item)
    overlay.close("menu")
    if item.on_click then
        item.on_click()
    end
    if spec.on_pick then
        spec.on_pick(item)
    end
end

-- The highlighted item, in the submenu when it holds the keyboard; nil while no menu is open.
local function current()
    local items = spec.items
    if not items or not menu_shown:get() then
        return nil
    end
    if deep:get() then
        local parent = items[sub:get()]
        return parent and parent.submenu[subsel:get()]
    end
    return items[cursor:get()]
end

-- One row. `active` is a boolean signal for the keyboard highlight, `open` marks a submenu parent
-- whose submenu is open; `on_enter` runs when the pointer arrives.
local function menu_item(level, i, item, tone, columns, active, on_enter)
    if item.separator then
        return rect { width = "fill", height = 1, margin = { top = 8, bottom = 8 }, background = c.outline_variant }
    end
    if item.header then
        return row { width = "fill", height = 40, align_v = "center", padding = { left = 12, right = 12 }, children = { text(item.header, c[tone.sub], "title_small") } }
    end
    local live = selectable(item)
    local checked = item.checked
    if type(checked) == "boolean" then
        local fixed = checked
        checked = theme.scheme:map(function() return fixed end)
    end
    local fg = checked and theme.pick(checked, tone.on_pick, tone.fg) or c[tone.fg]
    local name = ("menu_item%d_%d"):format(level, i)
    local over = hover("m3_" .. name)
    local kids = {}
    if columns.icon then
        kids[1] = item.icon and icon(item.icon, c[tone.sub], 24) or rect { width = 24, height = 24 }
    end
    kids[#kids + 1] = text(item.label, fg, "body_large", { width = "fill" })
    if item.shortcut then
        kids[#kids + 1] = text(item.shortcut, c[tone.sub], "label_large")
    end
    if checked then
        kids[#kids + 1] = icon("check", c[tone.on_pick], 24, { opacity = opacity_of(checked), animate = { opacity = QUICK, foreground = FADE } })
    end
    if item.submenu then
        kids[#kids + 1] = icon("arrow_right", c[tone.sub], 24)
    end
    return interactive(name, {
        width = "fill",
        height = MENU.row,
        background = checked and tint(checked, tone.pick) or nil,
        opacity = live and 1 or sel.DISABLED,
        geometry = item.submenu and geometry("m3_menu_row_" .. i) or nil,
        accessible_name = item.label,
        on_hover = function(inside)
            if inside and live then
                on_enter()
            end
        end,
        on_click = live and function()
            if item.submenu then
                on_enter()
            else
                pick(item)
            end
        end or function() end,
    }, c[tone.fg], rect {
        width = "fill",
        height = "fill",
        children = {
            -- The keyboard highlight; under the pointer the hover layer shows instead.
            rect {
                width = "fill",
                height = "fill",
                hittable = false,
                background = c[tone.fg],
                opacity = computed({ active, over }, function(on, hovered) return on and not hovered and 0.10 or 0 end),
                animate = { opacity = { duration = 100 } },
            },
            row {
                width = "fill",
                height = "fill",
                align_v = "center",
                padding = { left = 12, right = 12 },
                spacing = 12,
                children = kids,
            },
        },
    })
end

local function panel(items, level, tone, props, active_of, enter)
    local columns = {}
    for _, item in ipairs(items) do
        columns.icon = columns.icon or item.icon ~= nil
    end
    -- A `gap` item ends a group: Expressive menus draw each group as its own rounded container.
    local groups, grouped = { {} }, false
    for i, item in ipairs(items) do
        if item.gap then
            grouped = true
            groups[#groups + 1] = {}
        else
            table.insert(groups[#groups], menu_item(level, i, item, tone, columns, active_of(i), function() enter(i, item) end))
        end
    end
    local rows = groups[1]
    if grouped then
        rows = {}
        for g, kids in ipairs(groups) do
            rows[g] = column {
                width = "fill",
                padding = { top = MENU.pad, bottom = MENU.pad },
                radius = MENU.group,
                clip = "rounded",
                background = c[tone.bg],
                shadows = theme.shadows[2],
                children = kids,
            }
        end
    end
    return column(core.merge({
        spacing = grouped and MENU.gap or nil,
        padding = not grouped and { top = MENU.pad, bottom = MENU.pad } or nil,
        radius = not grouped and 4 or nil,
        background = not grouped and c[tone.bg] or nil,
        shadows = not grouped and theme.shadows[2] or nil,
        on_click = function() end,
        cursor = "default",
        focus_ring = false,
        scale = 1,
        opacity = 1,
        animate = {
            scale = { duration = 300, easing = theme.easing.emphasized_decelerate, from = { x = 0.9, y = 0.6 } },
            opacity = { duration = 150, from = 0 },
            background = FADE,
        },
        children = rows,
    }, props))
end

-- The next selectable index from `from` in direction `step`, wrapping; `from` when none is.
local function move(items, from, step)
    local n, i = #items, from
    for _ = 1, n do
        i = (i - 1 + step) % n + 1
        if selectable(items[i]) then
            return i
        end
    end
    return from
end

local function edge_item(items, last)
    for k = 1, #items do
        local i = last and #items + 1 - k or k
        if selectable(items[i]) then
            return i
        end
    end
    return 0
end

-- The open menu's key handler, rebuilt with the menu; the window hands keys to the top layer.
local keys = nil

overlay.layer("menu", function()
    local items, anchor = spec.items, spec.anchor
    if not items then
        return rect { hittable = false } -- a reload cleared the open menu
    end
    local tone = spec.vibrant and TONES.vibrant or TONES.standard
    local width = spec.width or MENU.width
    local end_aligned = spec.align == "end"
    local bounds = overlay.bounds(spec.window)
    local function w_of(r) return math.max((r or ZERO).width, MENU.width // 2) end
    local main = panel(items, 1, tone, {
        width = width == "anchor" and anchor:map(w_of) or width,
        geometry = box,
        -- Placed by margin, not `translate`: pointer coordinates follow the laid-out box.
        margin = computed({ anchor, bounds, box }, function(r, b, t)
            r = r or ZERO
            local w, h = t and t.width or 0, t and t.height or 0
            -- A context menu touches the pointer, below it or above.
            local gap = spec.at and 0 or MENU.below
            local left, top = r.x, r.y + r.height + gap
            if end_aligned then
                left = r.x + r.width - (width == "anchor" and w_of(r) or width)
            end
            if b then
                if top + h > b.y + b.height - MENU.edge and r.y - gap - h >= b.y + MENU.edge then
                    top = r.y - gap - h
                end
                if spec.at and left + w > b.x + b.width - MENU.edge and r.x - w >= b.x + MENU.edge then
                    left = r.x - w
                end
                left, top = clamp(left, w, b.x, b.x + b.width), clamp(top, h, b.y, b.y + b.height)
            end
            return { left = left, top = top }
        end),
        origin = { x = end_aligned and 1 or spec.at and 0 or 0.5, y = 0 },
    }, function(i)
        return computed({ cursor, sub, deep }, function(s, p, d) return s == i and not (p == i and d) end)
    end, function(i, item)
        cursor:set(i)
        deep:set(false)
        sub:set(item.submenu and i or 0)
    end)
    local subs = {}
    for i, item in ipairs(items) do
        if item.submenu then
            local at = geometry("m3_menu_row_" .. i)
            subs[i] = panel(item.submenu, 2, tone, {
                width = MENU.width,
                geometry = sub_box,
                margin = computed({ at, bounds, sub_box }, function(r, b, t)
                    local h = t and t.height or 0
                    local left, top = r.x + r.width + 2, r.y - MENU.pad
                    if b then
                        if left + MENU.width > b.x + b.width - MENU.edge then
                            left = r.x - 2 - MENU.width
                        end
                        left = clamp(left, MENU.width, b.x, b.x + b.width)
                        top = clamp(top, h, b.y, b.y + b.height)
                    end
                    return { left = left, top = top }
                end),
                origin = { x = 0, y = 0 },
            }, function(j) return computed({ subsel, deep }, function(s, d) return d and s == j end) end, function(j)
                subsel:set(j)
                deep:set(true)
            end)
        end
    end
    local function open_sub(i)
        sub:set(i)
        deep:set(true)
        subsel:set(edge_item(items[i].submenu, false))
    end
    -- Moves the highlight at the level that holds the keyboard.
    local function go(set, to)
        set:set(to)
        if set == cursor then
            sub:set(0)
        end
    end
    keys = function(key)
        local list, at, set = items, cursor:get(), cursor
        if deep:get() then
            list, at, set = items[sub:get()].submenu, subsel:get(), subsel
        end
        local name = key.name
        if name == "Down" or name == "Up" then
            local down = name == "Down"
            go(set, move(list, at == 0 and (down and 0 or 1) or at, down and 1 or -1))
        elseif name == "Home" or name == "End" then
            go(set, edge_item(list, name == "End"))
        elseif name == "Left" and deep:get() then
            deep:set(false)
        elseif name == "Right" and not deep:get() and items[at] and items[at].submenu then
            open_sub(at)
        elseif name == "Return" or name == "KP_Enter" or name == "space" then
            local item = list[at]
            if item and item.submenu and not deep:get() then
                open_sub(at)
            else
                M.pick_highlighted()
            end
        elseif key.text and #key.text == 1 and not key.modifiers.ctrl and not key.modifiers.alt then
            -- Type-ahead: the next item whose label starts with the typed letter.
            local ch = key.text:lower()
            for k = 1, #list do
                local i = (at + k - 1) % #list + 1
                local label = list[i].label
                if selectable(list[i]) and label and label:sub(1, 1):lower() == ch then
                    go(set, i)
                    return true
                end
            end
            return false
        else
            return false
        end
        return true
    end
    return rect {
        id = "menu",
        width = "fill",
        height = "fill",
        cursor = "default",
        focus_ring = false,
        on_click = function() overlay.close("menu") end,
        animate = { exit = { duration = 100, opacity = 0 } },
        children = {
            main,
            rect {
                width = "fill",
                height = "fill",
                hittable = false,
                children = sub:map(function(i) return subs[i] and { subs[i] } or {} end),
            },
        },
    }
end, {
    -- Escape closes an open submenu first, then the menu.
    escape = function()
        if sub:get() ~= 0 then
            deep:set(false)
            sub:set(0)
        else
            overlay.close("menu")
        end
    end,
    key = function(key) return keys and keys(key) end,
})

---@class m3.MenuItem
---@field label? string
---@field icon? string
---@field shortcut? string Shown at the end, e.g. "Ctrl+N" or "⌘⇧N"; `bind_shortcuts` makes it work.
---@field checked? boolean|Signal<boolean> Check and tint while true.
---@field disabled? boolean
---@field submenu? m3.MenuItem[] Opens to the side; one level.
---@field on_click? fun()
---@field separator? boolean A separator line instead of a row.
---@field header? string A group label instead of a row.
---@field group? m3.MenuItem[] Instead of a row: these items as one rounded container (Expressive); consecutive groups sit apart with a gap.
---@field gap? boolean Instead of a row: ends the group before it, so the menu's items form separate rounded containers.
---@field [string] "no such property"

-- Opens the menu layer under `anchor`, or at a point.
---@class m3.OpenMenuOpts
---@field anchor? Signal<Rect> A `geometry(name)` signal; the menu opens under it (above when there is no room).
---@field at? { x: number, y: number } A point in the host's coordinates instead of `anchor`, as a context menu opens at the pointer.
---@field items m3.MenuItem[] Required. Entries with `group` (or `gap = true` between runs of items) make an Expressive grouped menu.
---@field on_pick? fun(item: m3.MenuItem) Runs after an item's own `on_click`.
---@field width? number|"anchor" Px, or the anchor's width; default 224.
---@field align? "start"|"end" Which edge of the anchor it lines up with; "end" needs a px width.
---@field vibrant? boolean The Expressive vibrant colours: a tertiary container.
---@field id? string Names the opener, for `is_menu_open`.
---@field window? string The window or panel it opens over; default `core.window`.
---@field [string] "no such property"

---@param opts m3.OpenMenuOpts
function M.open_menu(opts)
    spec = core.merge(core.merge({}, opts), { items = flatten(opts.items) })
    if opts.at then
        point:set({ x = opts.at.x, y = opts.at.y, width = 0, height = 0 })
        spec.anchor = point
    end
    cursor:set(0)
    sub:set(0)
    subsel:set(0)
    deep:set(false)
    menu_owner:set(opts.id or "")
    overlay.open("menu", nil, opts.window)
end

-- A signal: true while the menu opened with `id` is showing.
---@param id string
---@return Signal<boolean>
function M.is_menu_open(id)
    return computed({ menu_shown, menu_owner }, function(open, owner) return open and owner == id end)
end

-- The item the open menu highlights, or nil: for an opener whose own keys steer the menu.
---@return m3.MenuItem?
function M.highlighted()
    return current()
end

-- Picks the highlighted item as Enter does; false when none is, or the open menu is not `id`'s.
---@param id? string
---@return boolean
function M.pick_highlighted(id)
    local item = current()
    if (id and menu_owner:get() ~= id) or not item or not selectable(item) or item.submenu then
        return false
    end
    pick(item)
    return true
end

-- Wraps `opts.child` so a right click on it opens `opts.items` at the pointer.
---@class m3.ContextMenuOpts
---@field child Node
---@field items m3.MenuItem[]|fun(): m3.MenuItem[] A function builds them at each opening.
---@field on_pick? fun(item: m3.MenuItem)
---@field vibrant? boolean
---@field window? string The window or panel it opens over; default `core.window`.
---@field width? number|"fill" The area's width; default the child's. "fill" lets a child that fills keep its width.
---@field height? number|"fill"
---@field [string] "no such property"

---@param id string
---@param opts m3.ContextMenuOpts
---@return Node
function M.context_menu(id, opts)
    return rect {
        width = opts.width,
        height = opts.height,
        cursor = "default",
        on_click = function(r, button, p)
            if button ~= "right" then
                return
            end
            M.open_menu({
                at = { x = r.x + p.x, y = r.y + p.y },
                items = type(opts.items) == "function" and opts.items() or opts.items --[[@as m3.MenuItem[] ]],
                on_pick = opts.on_pick,
                vibrant = opts.vibrant,
                id = "context_" .. id,
                window = opts.window,
            })
        end,
        children = { opts.child },
    }
end

-- Glyphs and names that mean a modifier in a shortcut string; ⌘ is Ctrl, as Super belongs to the
-- compositor. Key glyphs name keysyms.
M.MODIFIERS = { ["⌘"] = "ctrl", ["⌃"] = "ctrl", ["⌥"] = "alt", ["⇧"] = "shift", ctrl = "ctrl", control = "ctrl", cmd = "ctrl", alt = "alt", shift = "shift", super = "super" }
local KEYS = { ["⏎"] = "Return", ["↩"] = "Return", ["⌫"] = "BackSpace", ["⌦"] = "Delete", ["⎋"] = "Escape",
    ["⇥"] = "Tab", ["←"] = "Left", ["→"] = "Right", ["↑"] = "Up", ["↓"] = "Down", ["Space"] = "space" }

-- A shortcut string such as "Ctrl+Shift+N" or "⌘⇧N" as { mods = { ctrl = true, shift = true }, key = "n" }.
local function parse(shortcut)
    local mods, rest = {}, shortcut
    while true do
        local found
        for glyph, mod in pairs(M.MODIFIERS) do
            local len = #glyph
            if rest:sub(1, len):lower() == glyph and rest:sub(len + 1, len + 1) == "+" then
                mods[mod], rest, found = true, rest:sub(len + 2), true
            elseif not glyph:match("^%a") and rest:sub(1, len) == glyph then
                mods[mod], rest, found = true, rest:sub(len + 1), true
            end
        end
        if not found then
            break
        end
    end
    return { mods = mods, key = (KEYS[rest] or rest):lower() }
end

local function matches(sc, key)
    for _, mod in ipairs({ "ctrl", "alt", "shift", "super" }) do
        if (sc.mods[mod] or false) ~= key.modifiers[mod] then
            return false
        end
    end
    return key.name:lower() == sc.key
end

-- Makes `items`' shortcuts work while `window` has the keyboard and no menu or layer is open:
-- the matching item runs as if picked. Bind the same items a menu shows, so both stay in step.
---@param items m3.MenuItem[]
---@param window? string Default `core.window`, else the first window built.
function M.bind_shortcuts(items, window)
    local bound = {}
    local function collect(list)
        for _, item in ipairs(list) do
            if item.group then
                collect(item.group)
            elseif item.submenu then
                collect(item.submenu)
            elseif item.shortcut and selectable(item) then
                bound[#bound + 1] = { sc = parse(item.shortcut), item = item }
            end
        end
    end
    collect(items)
    overlay.on_key(window, function(key)
        if key["repeat"] then
            return false
        end
        for _, b in ipairs(bound) do
            if matches(b.sc, key) then
                if b.item.on_click then
                    b.item.on_click()
                end
                return true
            end
        end
        return false
    end)
end

---------------------------------------------------------------------------------------------------
-- Exposed dropdown: a read-only text field that opens a menu of options right under it.

-- Exposed dropdown: a read-only field that opens a menu of `items`.
---@class m3.DropdownOpts
---@field items (string|{ label: string, value?: any, icon?: string })[] Required. A string is its own label and value; a table's `value` defaults to its label.
---@field label? string|Signal<string> The floating label.
---@field name? string Accessible name; default the label.
---@field value? StateSignal<any> The chosen value; default own, the first item's.
---@field kind? "outlined"|"filled"
---@field container? string|Signal<string> Colour behind an outlined field.
---@field width? number Default 280.
---@field disabled? boolean|Signal<boolean>
---@field on_change? fun(value: any)
---@field window? string The window or panel the menu opens over; default `core.window`.
---@field [string] "no such property"

---@param id string
---@param opts m3.DropdownOpts
---@return Node
function M.dropdown(id, opts)
    local entries = {}
    for i, item in ipairs(opts.items) do
        entries[i] = type(item) == "table" and { label = item.label, icon = item.icon, value = item.value ~= nil and item.value or item.label } or { label = item, value = item }
    end
    local value = opts.value or state("m3_dd_" .. id, entries[1] and entries[1].value)
    local anchor = geometry("m3_dd_" .. id)
    local items = {}
    for i, entry in ipairs(entries) do
        items[i] = {
            label = entry.label,
            icon = entry.icon,
            checked = value:map(function(v) return v == entry.value end),
            on_click = function()
                value:set(entry.value)
                if opts.on_change then
                    opts.on_change(entry.value)
                end
            end,
        }
    end
    local owner = "dd_" .. id
    return (text_field(id, {
        kind = opts.kind,
        label = opts.label,
        name = opts.name,
        container = opts.container,
        width = opts.width or 280,
        disabled = opts.disabled,
        display = value:map(function(v)
            for _, entry in ipairs(entries) do
                if entry.value == v then
                    return entry.label
                end
            end
            return ""
        end),
        trailing = "arrow_drop_down",
        spin = true,
        geometry = anchor,
        active = M.is_menu_open(owner),
        on_click = function() M.open_menu({ id = owner, anchor = anchor, items = items, width = "anchor", window = opts.window }) end,
    }))
end

return M
