-- Window chrome: `app_window`, which wires the overlay layers into a window and, by default,
-- draws the frame itself (client-side decorations), plus the window controls and the drag handler a
-- top app bar can carry.
local theme = require("m3.theme")
local core = require("m3.core")
local overlay = require("m3.overlay")
local icon_button = require("m3.actions.icon_button").icon_button

local c = theme.c

local M = {}

-- not in the spec: M3 defines no desktop window frame. The corner is its extra-large shape, 28dp.
local RADIUS = 28
local GRIP = 6
-- A second press within this many ms maximises instead of moving (not in the spec).
local DOUBLE = 400
-- The band `geometry_inset` adds for elevation level 3's shadows: blur plus spread past the frame,
-- less the y offset above and plus it below.
local BAND = { left = 12, right = 12, top = 8, bottom = 16 }

-- The band per side: none on a tiled side, none at all maximised or fullscreen.
local function band(s)
    if s.maximized or s.fullscreen then
        return 0
    end
    local t = s.tiled
    return {
        left = t.left and 0 or BAND.left,
        right = t.right and 0 or BAND.right,
        top = t.top and 0 or BAND.top,
        bottom = t.bottom and 0 or BAND.bottom,
    }
end

-- Square the corners the window shares with a screen edge or a neighbour, and all of them maximised.
local function radii(s)
    local t = s.tiled
    if s.maximized or s.fullscreen then
        return 0
    end
    return {
        top_left = (t.top or t.left) and 0 or RADIUS,
        top_right = (t.top or t.right) and 0 or RADIUS,
        bottom_right = (t.bottom or t.right) and 0 or RADIUS,
        bottom_left = (t.bottom or t.left) and 0 or RADIUS,
    }
end

-- The `on_press` that makes a node a title bar: a left press moves the window, two within 400 ms
-- maximise or restore it, a right press opens the compositor's window menu. Put it on a `rect`
-- stacked behind the bar, never around it: a button has no `on_press`, so a press on it would reach an ancestor's.
---@param id string The window's id.
---@return fun(box: Rect, button: string)
function M.window_drag(id)
    local armed = false
    return function(_, button)
        local win = toplevel(id)
        if button == "right" then
            win:show_menu()
        elseif button == "left" and armed then
            armed = false
            win:set_maximized(not win:state():get().maximized)
        elseif button == "left" then
            armed = true
            timer(DOUBLE, function() armed = false end)
            win:move()
        end
    end
end

-- Minimise, maximise or restore, and close, as standard icon buttons.
---@param id string The window's id.
---@param on_close? fun() The close button's action; the window's own `on_close`.
---@return Node
function M.window_controls(id, on_close)
    local win = toplevel(id)
    local maximized = win:state():map(function(s) return s.maximized end)
    return row {
        spacing = 4,
        align_v = "center",
        children = {
            icon_button(id .. "_minimize", { icon = "remove", on_click = function() win:set_minimized() end, props = { accessible_name = "Minimise" } }),
            icon_button(id .. "_maximize", {
                icon = maximized:map(function(on) return on and "filter_none" or "crop_square" end),
                on_click = function() win:set_maximized(not win:state():get().maximized) end,
                props = { accessible_name = "Maximise" },
            }),
            icon_button(id .. "_close", { icon = "close", on_click = on_close, props = { accessible_name = "Close" } }),
        },
    }
end

---@alias m3.WindowClass "compact"|"medium"|"expanded"|"large"|"extra_large"

-- M3 window size classes by width in dp: compact < 600 <= medium < 840 <= expanded < 1200 <= large < 1600 <= extra large.
local CLASSES = { { 1600, "extra_large" }, { 1200, "large" }, { 840, "expanded" }, { 600, "medium" } }
local classes = {}

-- The window's size class, a signal built once per window id. Width comes from the window root's
-- `geometry`; before the first layout it reads "expanded" (not in the spec) so a desktop window doesn't flash compact.
---@param window? string The window's id; default `core.window`. Pass it when the first `app_window` is built after the caller.
---@return Signal<m3.WindowClass>
function M.window_class(window)
    local id = window or core.window or ""
    if not classes[id] then
        classes[id] = overlay.bounds(window):map(function(g)
            local width = g and g.width or 0
            for _, class in ipairs(CLASSES) do
                if width >= class[1] then
                    return class[2]
                end
            end
            return width > 0 and "compact" or "expanded"
        end)
    end
    return classes[id]
end

-- Invisible handles on the frame's edges and corners that start a compositor resize.
local function resize_grips(id)
    local function grip(edge, cursor, props)
        props.cursor = cursor
        props.on_press = function(_, button)
            if button == "left" then
                toplevel(id):resize(edge)
            end
        end
        return rect(props)
    end
    return {
        grip("top", "ns-resize", { width = "fill", height = GRIP }),
        grip("bottom", "ns-resize", { width = "fill", height = GRIP, align_v = "end" }),
        grip("left", "ew-resize", { width = GRIP, height = "fill" }),
        grip("right", "ew-resize", { width = GRIP, height = "fill", align_h = "end" }),
        grip("top_left", "nwse-resize", { width = 2 * GRIP, height = 2 * GRIP }),
        grip("top_right", "nesw-resize", { width = 2 * GRIP, height = 2 * GRIP, align_h = "end" }),
        grip("bottom_left", "nesw-resize", { width = 2 * GRIP, height = 2 * GRIP, align_v = "end" }),
        grip("bottom_right", "nwse-resize", { width = 2 * GRIP, height = 2 * GRIP, align_h = "end", align_v = "end" }),
    }
end

-- The shared `navigation`, `actions` and title (the same shape in glass) as adaptive navigation
-- around a top app bar over the child. Returns the child alone when none is given.
---@param props m3.AppWindowProps
---@return Node content
---@return boolean barred The top app bar carries the window controls.
local function shared_chrome(props)
    local nav = props.navigation
    if not (nav or props.actions or props.subtitle) then
        return props.child, false
    end
    local page = column {
        width = "fill",
        height = "fill",
        children = {
            require("m3.navigation.top_app_bar").top_app_bar(props.id .. "_bar", {
                title = props.title,
                subtitle = props.subtitle,
                actions = props.actions,
                window = props.decorations ~= "server" and props.id or nil,
                on_close = props.on_close,
            }),
            props.child,
        },
    }
    if not nav then
        return page, true
    end
    if nav.on_select then
        nav.value:on_change(function(name) nav.on_select(name) end)
    end
    return require("m3.layout.adaptive").adaptive_navigation(props.id .. "_nav", {
        items = nav.items,
        value = nav.value,
        content = page,
        window = props.id,
    }), true
end

-- An app window wired for overlays: any `window` field, with `props.child` the app's content. The
-- root paints `surface`, stacks the app's layers over `child` and routes Escape and keys to them.
---@class m3.AppWindowProps: WindowProps
---@field decorations? "client"|"server" Default "client": the app draws the frame (rounded, shadowed, resizable by its edges) and the window controls. "server" leaves both to the compositor.
---@field controls? boolean Client frame only, default true: minimise, maximise and close at the top end. `false` when the app's own top bar carries `m3.window_controls(id)`.
---@field child Node The app's content.
---@field title? string|Signal<string> Shared with glass: with `subtitle`, `navigation` or `actions`, the window gets a top app bar that carries the title, the actions and the window controls.
---@field subtitle? string|Signal<string>
---@field navigation? m3.WindowNavigation Shared with glass: the app's destinations, drawn as adaptive navigation (a bar, rail or drawer by width).
---@field actions? m3.TopAppBarAction[] Shared with glass: `{ icon, label?, on_click?, menu? }` buttons at the top app bar's end.

---@class m3.WindowNavigation
---@field items m3.NavItem[]
---@field value StateSignal<string> The selected item's name.
---@field header? string Glass shows it over its sidebar; m3's navigation has no header.
---@field on_select? fun(name: string)
---@field [string] "no such property"

-- What `app_window` gives `window`: one app built with either library can host both in one surface.
---@param props m3.AppWindowProps
---@return WindowProps
function M.window_props(props)
    local id = props.id
    local own = core.merge({}, props)
    local child, barred = shared_chrome(props)
    own.child, own.controls, own.navigation, own.actions, own.subtitle = nil, nil, nil, nil, nil
    local client = props.decorations ~= "server"
    local base = child
    if client and props.controls ~= false and not barred then
        base = rect {
            width = "fill",
            height = "fill",
            children = { child, rect { align_h = "end", align_v = "start", margin = { top = 12, right = 12 }, children = { M.window_controls(id, props.on_close) } } },
        }
    end
    local root = rect {
        width = "fill",
        height = "fill",
        background = c.surface,
        animate = { background = theme.motion.fade },
        geometry = overlay.bounds(id),
        children = overlay.root(base, id),
    }
    local common = {
        on_escape = function() overlay.escape(id) end,
        on_key = function(key) return overlay.key(id, key) end,
    }
    if not client then
        return core.merge(core.merge({ decorations = "server", child = root }, common), own)
    end
    local state = toplevel(id):state()
    local inset = state:map(band)
    root.radius = state:map(radii)
    root.clip = "rounded"
    root.shadows = theme.shadows[3]
    local grips = resize_grips(id)
    table.insert(grips, 1, root)
    return core.merge(core.merge({
        background = theme.CLEAR,
        decorations = "client",
        geometry_inset = inset,
        child = rect {
            width = "fill",
            height = "fill",
            padding = inset,
            children = { rect { width = "fill", height = "fill", children = grips } },
        },
    }, common), own)
end

---@param props m3.AppWindowProps
---@return Surface
function M.app_window(props)
    return window(M.window_props(props))
end

return M
