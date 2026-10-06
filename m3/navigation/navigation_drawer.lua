-- M3 navigation drawer: standard and modal, plus a window-wide modal layer.
-- Items are selected by `item.name or index`; every `opts.value` is a state holding that key.
local theme = require("m3.theme")
local core = require("m3.core")
local overlay = require("m3.overlay")
local nav = require("m3.internal.navigation")
local inert = require("m3.internal.common").inert

local c, motion, easing = theme.c, theme.motion, theme.easing
local FADE = motion.fade
local text, merge = core.text, core.merge
local key_of, selected_of, pill_item, scrim = nav.key_of, nav.selected_of, nav.pill_item, nav.scrim

local M = {}

local SLIDE = { duration = 400, easing = easing.emphasized_decelerate }

-- The drawer sheet: pill items, `{ header = "Mail" }` section headers and `{ separator = true }` rules.
---@param id string
---@param opts m3.NavigationDrawerOpts|m3.OpenNavigationDrawerOpts
---@param select fun(key: m3.NavKey)
---@param props table
---@return Node
local function drawer_sheet(id, opts, select, props)
    local kids = {}
    for i, item in ipairs(opts.items) do
        if item.header then
            kids[i] = row { width = "fill", height = 56, align_v = "center", padding = { left = 16 }, children = { text(item.header, c.on_surface_variant, "title_small") } }
        elseif item.separator then
            kids[i] = rect { width = "fill", height = 1, margin = { left = 16, right = 16, top = 8, bottom = 4 }, background = c.outline_variant }
        else
            local key = key_of(item, i)
            kids[i] = pill_item(("%s_%d"):format(id, i), item, selected_of(opts.value, key), function() select(key) end, 12)
        end
    end
    return column(inert(merge({
        width = 360,
        height = "fill",
        padding = 12,
        background = c.surface_container_low,
        radius = { top_right = 16, bottom_right = 16 },
        animate = { background = FADE },
        children = kids,
    }, props)))
end

---@class m3.DrawerItem: m3.NavItem
---@field header? string A section header instead of a destination.
---@field separator? boolean A rule instead of a destination.

---@class m3.NavigationDrawerOpts
---@field items m3.DrawerItem[]
---@field value? StateSignal<m3.NavKey> The selected item's `name` or index; default its own state.
---@field on_select? fun(key: m3.NavKey)
---@field kind? "modal"|"standard" Default "modal": slides over a scrim; "standard" is the plain sheet.
---@field open? StateSignal<boolean> Modal only: whether it is shown.
---@field [string] "no such property"

-- A drawer to place in a frame or a layout.
---@param id string
---@param opts m3.NavigationDrawerOpts
---@return Node
function M.navigation_drawer(id, opts)
    local open = opts.open or state("m3_drawer_open_" .. id, false)
    opts.value = opts.value or state("m3_drawer_value_" .. id, key_of(opts.items[1] or {}, 1))
    local function select(key)
        opts.value:set(key)
        if opts.kind ~= "standard" then
            open:set(false)
        end
        if opts.on_select then
            opts.on_select(key)
        end
    end
    if opts.kind == "standard" then
        return drawer_sheet("drawer_" .. id, opts, select, { background = c.surface })
    end
    return rect {
        width = "fill",
        height = "fill",
        children = {
            scrim(open),
            drawer_sheet("drawer_" .. id, opts, select, {
                translate = open:map(function(o) return { x = o and 0 or -360 } end),
                animate = { translate = SLIDE, background = FADE },
            }),
        },
    }
end

---@type m3.OpenNavigationDrawerOpts
local layer_opts = { items = {} }

overlay.layer("navigation_drawer", function()
    local function close() overlay.close("navigation_drawer") end
    return rect {
        id = "navigation_drawer",
        width = "fill",
        height = "fill",
        background = theme.scheme:map(function(s) return theme.alpha(s.scrim, 0.32) end),
        opacity = 1,
        on_click = close,
        animate = { opacity = { duration = 200, from = 0 }, exit = { duration = 200, opacity = 0 } },
        children = {
            drawer_sheet("drawer_layer", layer_opts, function(key)
                layer_opts.value:set(key)
                close()
                if layer_opts.on_select then
                    layer_opts.on_select(key)
                end
            end, {
                translate = { x = 0 },
                animate = { translate = merge({ from = { x = -360 } }, SLIDE), exit = { duration = 200, translate = { x = -360 } } },
            }),
        },
    }
end)

---@class m3.OpenNavigationDrawerOpts
---@field items m3.DrawerItem[]
---@field value? StateSignal<m3.NavKey> Default its own state.
---@field on_select? fun(key: m3.NavKey)
---@field window? string The window or panel it opens over; default `core.window`.
---@field [string] "no such property"

-- Opens a modal drawer over the whole window.
---@param opts m3.OpenNavigationDrawerOpts
function M.open_navigation_drawer(opts)
    opts.value = opts.value or state("m3_drawer_value_layer", key_of(opts.items[1] or {}, 1))
    layer_opts = opts
    overlay.open("navigation_drawer", nil, opts.window)
end

return M
