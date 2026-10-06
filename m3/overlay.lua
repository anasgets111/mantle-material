-- Layers over a window or panel: menus, pickers, sheets, drawers, the dialog, the snackbar and the
-- tooltip. `M.layer(id, build)` registers a builder, `M.open(id, data, host)` shows it on top of
-- `host`'s stack and `M.close(id)` removes it, playing its `exit`. `build(data)` returns a node whose
-- `id` is the layer's own, usually a full-host rect whose `on_click` closes it. A host is an
-- `app_window` (its own id) or a panel that returns `M.popup(id)` among its surfaces; `host` defaults
-- to `core.window`, else the first window root built. Each is a root child only while shown: a
-- full-size layer wins every hit test under it, so one left in the tree would swallow the app's clicks.
-- One layer of a kind is open at a time across hosts: opening a menu on one host closes the other's.
local theme = require("m3.theme")
local core = require("m3.core")
local button = require("m3.actions.button").button

local c = theme.c

local M = {}

local shown = state("m3_layers", {})
local builders, escapes, key_handlers, fallbacks = {}, {}, {}, {}
-- A reload rebuilds the builders and the data they close over, so layers left open by the last
-- generation close instead of building from stale data.
if #(shown:get() or {}) > 0 then
    shown:set({})
end

-- The first window root built: where a layer opened with no host and no `core.window` shows.
local first_root
---@param host? string
---@return string?
local function resolve(host)
    return host or core.window or first_root
end

-- `handlers` (optional): `escape()` replaces the default close when Escape reaches this layer;
-- `key(key)` receives the window's unhandled keys while this layer is on top.
---@param id string
---@param build fun(data: table): Node
---@param handlers? { escape?: fun(), key?: fun(key: KeyPress): boolean? }
function M.layer(id, build, handlers)
    builders[id] = build
    escapes[id] = handlers and handlers.escape
    key_handlers[id] = handlers and handlers.key
end

---@param id string
function M.close(id)
    local kept = {}
    for _, layer in ipairs(shown:get() or {}) do
        if layer.id ~= id then
            kept[#kept + 1] = layer
        end
    end
    shown:set(kept)
end

---@param id string
---@param data? table Passed to the layer's builder.
---@param host? string
function M.open(id, data, host)
    M.close(id)
    local layers = { table.unpack(shown:get() or {}) }
    layers[#layers + 1] = { id = id, data = data or {}, host = resolve(host) }
    shown:set(layers)
end

---@param id string
---@return Signal<boolean>
function M.is_open(id)
    return shown:map(function(layers)
        for _, layer in ipairs(layers or {}) do
            if layer.id == id then
                return true
            end
        end
        return false
    end)
end

-- The `geometry` handle of host `id`'s root, for a layer to keep inside it.
---@param host? string Default `core.window`, else the first window root built.
---@return Signal<Rect>
function M.bounds(host)
    return geometry("m3_root_" .. tostring(resolve(host)))
end

---------------------------------------------------------------------------------------------------
-- Snackbar: one per host (the rest queue), slides up, leaves after 4 s.

---@type StateSignal<table> Host id to the snackbar it shows.
local snacks = state("m3_snacks", {})
local snack_timers, snack_actions = {}, {}
-- A reload drops the dismiss timer and the action callback, so a snackbar left over from the last
-- generation leaves now instead of staying forever.
if next(snacks:get() or {}) then
    snacks:set({})
end

local function with_snack(host, spec)
    local all = core.merge({}, snacks:get())
    all[host] = spec or nil
    snacks:set(all)
end

-- M3 shows one snackbar at a time: later messages wait here, per host, for the current one to leave.
local snack_queue, snack_serial = {}, {}

local show_next
-- Removes the host's snackbar, then shows the next queued one.
local function dismiss(host)
    if snack_timers[host] then
        snack_timers[host]:cancel()
        snack_timers[host] = nil
    end
    with_snack(host, nil)
    show_next(host)
end

function show_next(host)
    local item = table.remove(snack_queue[host] or {}, 1)
    if not item then
        return
    end
    snack_serial[host] = (snack_serial[host] or 0) + 1
    snack_actions[host] = item.on_action
    with_snack(host, { n = snack_serial[host], text = item.message, icon = item.icon, action = item.action, close = item.close })
    snack_timers[host] = timer(item.action and 8000 or 4000, function() dismiss(host) end)
end

-- Shows a snackbar. Without an action it only informs; a longer message wraps to two lines. One shows
-- per host; a new message waits until the current one times out or is dismissed.
---@class m3.NotifyOpts
---@field title string The snackbar's message.
---@field body? string Appended below the title.
---@field icon? string Shared or Material Symbols name, before the message.
---@field action? string Label of a text button; the snackbar then stays 8 s instead of 4.
---@field on_action? fun() Runs when the action is pressed.
---@field close? boolean A trailing close icon.
---@field window? string The window or panel it shows over; default `core.window`.
---@field [string] "no such property"

---@param opts m3.NotifyOpts
function M.notify(opts)
    local item = core.merge({ message = opts.body and opts.title .. "\n" .. opts.body or opts.title }, opts)
    local host = resolve(item.window) or ""
    snack_queue[host] = snack_queue[host] or {}
    table.insert(snack_queue[host], item)
    if not (snacks:get() or {})[host] then
        show_next(host)
    end
end

-- An M3 text button: 40px pill, label in `color`, state layer and ripple in the same colour.
local function text_button(name, content, color, run)
    return core.interactive(name, { height = 40, radius = 20, align_v = "center", on_click = run }, color, row {
        height = "fill",
        align_v = "center",
        padding = { left = 12, right = 12 },
        children = { content },
    })
end

local function snackbar(s, host)
    local kids = {}
    if s.icon then
        kids[1] = core.icon(s.icon, c.inverse_on_surface, 24, { margin = { top = 12 } })
    end
    kids[#kids + 1] = core.text(s.text, c.inverse_on_surface, "body_medium", { wrap = "word", max_lines = 2, max_width = 560, margin = { top = 14, bottom = 14, right = 8 } })
    kids[#kids + 1] = rect { width = "fill", height = 1 }
    if s.action then
        kids[#kids + 1] = text_button("snack_action", core.text(s.action, c.inverse_primary, "label_large"), c.inverse_primary, function()
            local run = snack_actions[host]
            dismiss(host)
            if run then
                run()
            end
        end)
    end
    if s.close then
        kids[#kids + 1] = text_button("snack_close", core.icon("close", c.inverse_on_surface, 24), c.inverse_on_surface, function() dismiss(host) end)
    end
    return core.merge(row {
        id = "snack" .. s.n,
        min_width = 344,
        max_width = 672,
        min_height = 48,
        radius = 4,
        align_h = "center",
        align_v = "end",
        margin = { bottom = 24 },
        padding = { left = 16, right = 8 },
        spacing = 8,
        background = c.inverse_surface,
        translate = { y = 0 },
        opacity = 1,
        animate = {
            translate = { duration = 300, easing = "out_cubic", from = { y = 32 } },
            opacity = { duration = 150, from = 0 },
            exit = { duration = 150, easing = "in_quad", opacity = 0, translate = { y = 16 } },
        },
        children = kids,
    }, theme.elevation[3])
end

---------------------------------------------------------------------------------------------------
-- Dialog: M3 basic dialog over a 32% scrim. Callbacks and nodes stay in Lua because named state
-- holds only plain data. It is a layer like the others, drawn above the snackbar.

---@type table
local dialog = {}
local dialog_n = 0 -- names each opening's nodes afresh

---@class m3.DialogButton
---@field label string
---@field kind? "primary"|"destructive"|"plain" Default "plain". Every button closes the dialog, then runs.
---@field on_click? fun()
---@field [string] "no such property"

---@class m3.DialogOpts
---@field icon? string A shared or Material Symbols name; centres the title.
---@field title string
---@field message? string|Node Supporting text, or any node; it scrolls when taller than the window allows.
---@field buttons? m3.DialogButton[] In the order shown, at the end of the row. Default one "OK".
---@field window? string The window or panel it opens over; default `core.window`.
---@field [string] "no such property"

---@param opts m3.DialogOpts
function M.open_dialog(opts)
    dialog_n = dialog_n + 1
    dialog = opts
    M.open("dialog", nil, opts.window)
end

-- A destructive action behind a confirm dialog, then a snackbar whose Undo calls `restore`.
---@class m3.ConfirmRemoveOpts: m3.DialogOpts
---@field confirm? string The confirming button's label; default "Delete".
---@field removed string The snackbar text after the action.

---@param opts m3.ConfirmRemoveOpts `icon` defaults to a delete's.
---@param remove fun()
---@param restore fun()
function M.confirm_remove(opts, remove, restore)
    opts.icon = opts.icon or "delete"
    opts.buttons = {
        { label = "Cancel" },
        { label = opts.confirm or "Delete", kind = "destructive", on_click = function()
            remove()
            M.notify({ title = opts.removed, action = "Undo", on_action = restore })
        end },
    }
    M.open_dialog(opts)
end

function M.close_dialog()
    M.close("dialog")
end

M.layer("dialog", function()
    local spec = dialog
    if not spec.title then
        return rect { hittable = false } -- a reload cleared the open dialog
    end
    local actions = {}
    for i, a in ipairs(spec.buttons or { { label = "OK" } }) do
        actions[i] = button("dialog_action" .. i, {
            kind = a.kind or "plain",
            label = a.label,
            on_click = function()
                M.close_dialog()
                if a.on_click then
                    a.on_click()
                end
            end,
        })
    end
    local body = spec.message
    if type(body) == "string" then
        body = core.text(body, c.on_surface_variant, "body_medium", { wrap = "word", max_width = 512 })
    end
    local bounds = M.bounds(spec.window)
    return rect {
        id = "dialog" .. dialog_n,
        width = "fill",
        height = "fill",
        background = theme.scheme:map(function(s) return theme.alpha(s.scrim, 0.32) end),
        opacity = 1,
        on_click = M.close_dialog,
        animate = { opacity = { duration = 150, from = 0 }, exit = { duration = 150, opacity = 0 } },
        children = {
            core.merge(column {
                min_width = 280,
                max_width = 560,
                align_h = "center",
                align_v = "center",
                padding = 24,
                spacing = 16,
                radius = 28,
                background = c.surface_container_high,
                scale = 1,
                -- Swallows clicks so only the scrim dismisses.
                on_click = function() end,
                cursor = "default",
                focus_ring = false,
                animate = { scale = { duration = 400, easing = theme.easing.emphasized_decelerate, from = 0.9 } },
                children = {
                    core.icon(spec.icon or "", c.secondary, 24, { align_h = "center", visible = spec.icon ~= nil }),
                    core.text(spec.title, c.on_surface, "headline_small", { align_h = spec.icon and "center" or "start" }),
                    body and column {
                        -- not in the spec: the body scrolls past the host's height less 140px for the title and actions.
                        max_height = bounds:map(function(b) return math.max(120, (b and b.height > 0 and b.height or 600) - 140) end),
                        scroll = scroll("m3_dialog_scroll" .. dialog_n),
                        animate = { scroll = theme.motion.scroll },
                        children = { body },
                    } or nil,
                    row { width = "fill", align_h = "end", spacing = 8, margin = { top = 8 }, children = actions },
                },
            }, theme.elevation[3]),
        },
    }
end)

---------------------------------------------------------------------------------------------------
-- Tooltip: one at a time, over everything, at its anchor. `build(anchor, bounds)` gets the anchor's
-- and the host's `geometry` signals and returns the tip node; the layer itself lets the pointer through.

---@type StateSignal<table|false>
local tip = state("m3_tip", false)
local tip_builders = {}
if tip:get() then
    tip:set(false)
end

---@param id string
---@param anchor_name string Name of the anchor node, for `geometry`.
---@param build fun(anchor: Signal<Rect>, bounds: Signal<Rect>): Node
---@param host? string
function M.show_tip(id, anchor_name, build, host)
    tip_builders[id] = build
    tip:set({ id = id, anchor = anchor_name, host = resolve(host) })
end

---@param id string
function M.hide_tip(id)
    local now = tip:get()
    if now and now.id == id then
        tip:set(false)
    end
end

local function tip_layer(t, host)
    local build = t and t.host == host and tip_builders[t.id]
    if not build then
        return nil
    end
    return rect {
        id = "tip_" .. t.id,
        width = "fill",
        height = "fill",
        hittable = false,
        children = { build(geometry(t.anchor), M.bounds(host)) },
    }
end

-- Closes every layer and the tooltip, e.g. when the page changes under them.
function M.close_all()
    shown:set({})
    tip:set(false)
end

local function top_of(host)
    local layers = shown:get() or {}
    for i = #layers, 1, -1 do
        if layers[i].host == host then
            return layers[i]
        end
    end
end

-- Escape closes `host`'s topmost layer, or runs that layer's own `escape`.
---@param host? string
function M.escape(host)
    local top = top_of(resolve(host))
    if top then
        (escapes[top.id] or function() M.close(top.id) end)()
    end
end

-- A key no focused control took: `host`'s top layer's key handler gets it; with no layer open, the
-- `on_key` fallbacks do.
---@param host? string
---@param key KeyPress
---@return boolean
function M.key(host, key)
    host = resolve(host)
    local top = top_of(host)
    local handle = top and key_handlers[top.id]
    if handle and handle(key) then
        return true
    end
    if not top then
        for _, list in ipairs({ fallbacks[host] or {}, host == first_root and fallbacks[""] or {} }) do
            for _, fallback in ipairs(list) do
                if fallback(key) then
                    return true
                end
            end
        end
    end
    return false
end

-- `fn(key)` sees `host`'s keys that no control or open layer took, e.g. menu shortcuts. Before any
-- window is built, a nil `host` waits for the first one.
---@param host? string
---@param fn fun(key: KeyPress): boolean?
function M.on_key(host, fn)
    host = resolve(host) or ""
    fallbacks[host] = fallbacks[host] or {}
    table.insert(fallbacks[host], fn)
end

-- The dialog is drawn after the snackbar, the other layers before it.
local function stack(host, base)
    return computed({ shown, snacks, tip }, function(layers, bars, t)
        local kids, last = { base }, {}
        for _, layer in ipairs(layers or {}) do
            local build = layer.host == host and builders[layer.id]
            if build then
                local into = layer.id == "dialog" and last or kids
                into[#into + 1] = build(layer.data)
            end
        end
        local bar = (bars or {})[host]
        if bar then
            kids[#kids + 1] = snackbar(bar, host)
        end
        for _, node in ipairs(last) do
            kids[#kids + 1] = node
        end
        local tip_node = tip_layer(t, host)
        if tip_node then
            kids[#kids + 1] = tip_node
        end
        return kids
    end)
end

-- Window `host`'s root children: `base`, then its layers in opening order, the snackbar, the
-- dialog, the tooltip on top. Give the root `geometry = overlay.bounds(host)`.
---@param base Node|Bound
---@param host string
---@return Signal<Node[]>
function M.root(base, host)
    first_root = first_root or host
    return stack(host, base)
end

-- A transparent popup over panel `parent` that draws its layers past the panel's bounds. Return it
-- with the panel's surfaces: `return { bar, m3.overlay.popup("bar") }`; open layers with `window = "bar"`.
---@param parent string
---@return Surface
function M.popup(parent)
    local mine = computed({ shown, tip }, function(layers, t)
        local any, modal = false, false
        for _, layer in ipairs(layers or {}) do
            if layer.host == parent then
                any, modal = true, true
            end
        end
        return { any = any or (t and t.host == parent) or false, modal = modal }
    end)
    -- The popup hangs from the panel's top left corner, a screen in size so layers place in the
    -- panel's coordinates.
    local size = mantle.screens:map(function(screens)
        local w, h = 1920, 1080
        for _, s in ipairs(screens or {}) do
            w, h = math.max(w, s.width), math.max(h, s.height)
        end
        return { width = w, height = h }
    end)
    return popup {
        id = "m3_overlay_" .. parent,
        parent = parent,
        anchor_rect = { x = 0, y = 0, width = 1, height = 1 },
        anchor = "top_left",
        gravity = "bottom_right",
        constraint_adjustment = {},
        background = theme.CLEAR,
        visible = mine:map(function(m) return m.any end),
        grab = mine:map(function(m) return m.modal end),
        on_escape = function() M.escape(parent) end,
        on_dismiss = function()
            local kept = {}
            for _, layer in ipairs(shown:get() or {}) do
                if layer.host ~= parent then
                    kept[#kept + 1] = layer
                end
            end
            shown:set(kept)
            M.hide_tip((tip:get() or {}).id)
        end,
        child = rect {
            width = size:map(function(s) return s.width end),
            height = size:map(function(s) return s.height end),
            geometry = M.bounds(parent),
            on_key = function(key) return M.key(parent, key) end,
            children = stack(parent, nil),
        },
    }
end

return M
