-- Full-window layers over the app: the snackbar, the dialog, and any registered layer (menus,
-- sheets, drawers). Each is a root child only while shown: a full-size layer wins every hit test
-- under it, so one left in the tree would swallow the app's clicks.
local theme = require("m3.theme")
local core = require("m3.core")

local c = theme.c

local M = {}

---------------------------------------------------------------------------------------------------
-- Snackbar: one at a time, slides up, leaves after 4 s.

---@type StateSignal<table|false>
local snack = state("m3_snack", false)
local snack_timer = nil
-- A reload drops the dismiss timer and the action callback, so a snackbar left over from the last
-- generation leaves now instead of staying forever.
if snack:get() then
    snack:set(false)
end

-- `opts`: `action` (a button label) with `on_action`, and `close` for a trailing close icon.
-- Without an action the snackbar only informs; a longer message wraps to two lines.
local on_action = nil

function M.notify(message, opts)
    opts = opts or {}
    local last = snack:get()
    on_action = opts.on_action
    snack:set({ n = (last and last.n or 0) + 1, text = message, action = opts.action, close = opts.close })
    if snack_timer then
        snack_timer:cancel()
    end
    snack_timer = timer(opts.action and 8000 or 4000, function() snack:set(false) end)
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

local snackbar = snack:map(function(s)
    if not s then
        return {}
    end
    local kids = { core.text(s.text, c.inverse_on_surface, "body_medium", { wrap = "word", max_lines = 2, max_width = 560, margin = { top = 14, bottom = 14, right = 8 } }) }
    kids[2] = rect { width = "fill", height = 1 }
    if s.action then
        kids[#kids + 1] = text_button("snack_action", core.text(s.action, c.inverse_primary, "label_large"), c.inverse_primary, function()
            snack:set(false)
            if on_action then
                on_action()
            end
        end)
    end
    if s.close then
        kids[#kids + 1] = text_button("snack_close", core.icon("close", c.inverse_on_surface, 24), c.inverse_on_surface, function() snack:set(false) end)
    end
    return {
        core.merge(row {
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
        }, theme.elevation[3]),
    }
end)

---------------------------------------------------------------------------------------------------
-- Dialog: M3 basic dialog over a 32% scrim. The confirm callback stays in Lua because named state
-- holds only plain data. `spec` is { icon, title, body, confirm? }.

---@type StateSignal<table|false>
local dialog = state("m3_dialog", false)
local on_confirm = nil

function M.ask(spec, confirm)
    local last = dialog:get()
    spec.n = (last and last.n or 0) + 1
    on_confirm = confirm
    dialog:set(spec)
end

function M.close_dialog()
    dialog:set(false)
end

local function dialog_layer(spec)
    local actions = { text_button("dialog_cancel", core.text("Cancel", c.primary, "label_large"), c.primary, M.close_dialog) }
    if spec.confirm then
        actions[2] = text_button("dialog_confirm", core.text(spec.confirm, c.primary, "label_large"), c.primary, function()
            M.close_dialog()
            if on_confirm then
                on_confirm()
            end
        end)
    end
    return rect {
        id = "dialog" .. spec.n,
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
                    core.text(spec.body, c.on_surface_variant, "body_medium", { wrap = "word", max_width = 512 }),
                    row { width = "fill", align_h = "end", spacing = 8, margin = { top = 8 }, children = actions },
                },
            }, theme.elevation[3]),
        },
    }
end

---------------------------------------------------------------------------------------------------
-- Registered layers. `M.layer(id, build)` registers a builder; `M.open(id, data)` shows it on top
-- and `M.close(id)` removes it, playing its `exit`. `build(data)` returns a node whose `id` is the
-- layer's own, usually a full-window rect whose `on_click` closes it.

local shown = state("m3_layers", {})
local builders = {}

function M.layer(id, build)
    builders[id] = build
end

function M.close(id)
    local kept = {}
    for _, layer in ipairs(shown:get() or {}) do
        if layer.id ~= id then
            kept[#kept + 1] = layer
        end
    end
    shown:set(kept)
end

function M.open(id, data)
    M.close(id)
    local layers = { table.unpack(shown:get() or {}) }
    layers[#layers + 1] = { id = id, data = data or {} }
    shown:set(layers)
end

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

---------------------------------------------------------------------------------------------------
-- Tooltip: one at a time, over everything, at its anchor. `build(anchor)` gets the anchor's
-- `geometry` signal and returns the tip node; the layer itself lets the pointer through.

---@type StateSignal<table|false>
local tip = state("m3_tip", false)
local tip_builders = {}

function M.show_tip(id, anchor_name, build)
    tip_builders[id] = build
    tip:set({ id = id, anchor = anchor_name })
end

function M.hide_tip(id)
    local now = tip:get()
    if now and now.id == id then
        tip:set(false)
    end
end

local tip_layer = tip:map(function(t)
    if not t then
        return nil
    end
    local build = tip_builders[t.id]
    if not build then
        return nil
    end
    return rect {
        id = "tip_" .. t.id,
        width = "fill",
        height = "fill",
        hittable = false,
        children = { build(geometry(t.anchor)) },
    }
end)

-- Closes every layer and the dialog, e.g. when the page changes under them.
function M.close_all()
    shown:set({})
    tip:set(false)
    M.close_dialog()
end

-- Escape: the dialog first, then the topmost layer.
function M.escape()
    if dialog:get() then
        return M.close_dialog()
    end
    local layers = shown:get() or {}
    if #layers > 0 then
        M.close(layers[#layers].id)
    end
end

-- The root's children: `base`, then layers in opening order, the snackbar, the dialog on top.
function M.root(base)
    return computed({ shown, snackbar, dialog, tip_layer }, function(layers, bar, spec, tip_node)
        local kids = { base }
        for _, layer in ipairs(layers or {}) do
            local build = builders[layer.id]
            if build then
                kids[#kids + 1] = build(layer.data)
            end
        end
        kids[#kids + 1] = bar[1]
        if spec then
            kids[#kids + 1] = dialog_layer(spec)
        end
        kids[#kids + 1] = tip_node
        return kids
    end)
end

-- An app window wired for overlays: `props` are `window`'s, `props.child` the app's content. The
-- root paints `surface`, stacks the app's layers over `child`, and routes Escape to them.
function M.app_window(props)
    local child = props.child
    props.child = rect {
        width = "fill",
        height = "fill",
        background = c.surface,
        animate = { background = theme.motion.fade },
        children = M.root(child),
    }
    props.on_escape = props.on_escape or M.escape
    return window(props)
end

return M
