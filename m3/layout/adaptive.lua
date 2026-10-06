-- Adaptive layouts: the navigation and the canonical list-detail layout, picked by the window's size class.
local theme = require("m3.theme")
local core = require("m3.core")
local window_class = require("m3.window").window_class
local icon_button = require("m3.actions.icon_button").icon_button
local navigation_bar = require("m3.navigation.navigation_bar").navigation_bar
local navigation_rail = require("m3.navigation.navigation_rail").navigation_rail
local navigation_drawer = require("m3.navigation.navigation_drawer").navigation_drawer

local c, motion = theme.c, theme.motion

local M = {}

-- M3 canonical layouts: 24dp margins and pane gaps, 360dp list pane, panes on surface containers.
local MARGIN, LIST_WIDTH, PANE_RADIUS = 24, 360, 28
local BAR, RAIL, EXPANDED_RAIL, DRAWER = 80, 96, 220, 360

---@class m3.AdaptiveNavigationOpts
---@field items m3.NavItem[] Required. Three to five make a bar; the rail takes up to seven.
---@field value StateSignal<m3.NavKey> Required. The selected item's `name` or index.
---@field content Node Required. The page; the navigation is placed beside or below it.
---@field window? string The window whose width picks the layout; see `m3.window_class`.
---@field class? Signal<m3.WindowClass> Overrides the window's class (a preview in a fixed frame).
---@field fab? m3.NavFab Shown by the rails.
---@field drawer? boolean Expanded windows (840dp and up) get a standard navigation drawer instead of the expanded rail.
---@field [string] "no such property"

-- `content` with the navigation M3 picks for the window's class: a bottom navigation bar when compact,
-- a collapsed rail when medium, an expanded rail (or `drawer`) from 840dp. Each variant is built once.
---@param id string
---@param opts m3.AdaptiveNavigationOpts
---@return Node
function M.adaptive_navigation(id, opts)
    local class = opts.class or window_class(opts.window)
    local wide = class:map(function(k) return k ~= "compact" and k ~= "medium" end)
    -- The host lets the pointer through to the content; each navigation takes it back.
    local function solid(node, props)
        return rect(core.merge({ hittable = true, children = { node } }, props))
    end
    local nav = {
        compact = solid(navigation_bar(id .. "_bar", { items = opts.items, value = opts.value }), { width = "fill", height = BAR, align_v = "end" }),
        medium = solid(navigation_rail(id .. "_rail", { destinations = opts.items, value = opts.value, fab = opts.fab, expanded = wide --[[@as StateSignal<boolean>]] }), { height = "fill" }),
    }
    nav.expanded = nav.medium
    if opts.drawer then
        nav.expanded = solid(navigation_drawer(id .. "_drawer", { kind = "standard", items = opts.items, value = opts.value }), { height = "fill" })
    end
    nav.large, nav.extra_large = nav.expanded, nav.expanded
    local inset = class:map(function(k)
        if k == "compact" then
            return { bottom = BAR }
        end
        return { left = k == "medium" and RAIL or opts.drawer and DRAWER or EXPANDED_RAIL }
    end)
    return rect {
        width = "fill",
        height = "fill",
        children = {
            rect { width = "fill", height = "fill", padding = inset, animate = { padding = motion.spatial }, children = { opts.content } },
            rect { width = "fill", height = "fill", hittable = false, children = class:map(function(k) return { nav[k] } end) },
        },
    }
end

---@class m3.ListDetailOpts
---@field list Node Required. The list pane's content.
---@field detail Node Required. The detail pane's content.
---@field has_detail StateSignal<boolean> Required. Whether an item is open: narrow windows show the detail, with a back button that sets it false.
---@field window? string The window whose width picks the layout.
---@field class? Signal<m3.WindowClass> Overrides the window's class (a preview in a fixed frame).
---@field [string] "no such property"

-- Side by side on a window of 840dp and up (list 360dp, detail filling, panes 24dp apart); on a narrower
-- one the list, or, once `has_detail`, the detail under a back button.
---@param id string
---@param opts m3.ListDetailOpts
---@return Node
function M.list_detail(id, opts)
    local class = opts.class or window_class(opts.window)
    local function pane(width, child)
        return column {
            width = width,
            height = "fill",
            radius = PANE_RADIUS,
            clip = "rounded",
            background = c.surface_container,
            animate = { background = theme.motion.fade },
            children = { child },
        }
    end
    local views = {
        side = row { width = "fill", height = "fill", padding = MARGIN, spacing = MARGIN, children = { pane(LIST_WIDTH, opts.list), pane("fill", opts.detail) } },
        list = rect { width = "fill", height = "fill", children = { opts.list } },
        detail = column { width = "fill", height = "fill", children = {
            row { width = "fill", padding = { left = 4, top = 4 }, children = {
                icon_button(id .. "_back", { icon = "arrow_back", on_click = function() opts.has_detail:set(false) end, props = { accessible_name = "Back" } }),
            } },
            rect { width = "fill", height = "fill", children = { opts.detail } },
        } },
    }
    return rect {
        width = "fill",
        height = "fill",
        children = computed({ class, opts.has_detail }, function(k, open)
            if k ~= "compact" and k ~= "medium" then
                return { views.side }
            end
            return { open and views.detail or views.list }
        end),
    }
end

return M
