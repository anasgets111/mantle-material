-- M3 top app bar: small, center-aligned, medium, large and flexible.
local theme = require("m3.theme")
local core = require("m3.core")
local icon_button = require("m3.actions.icon_button").icon_button
local window = require("m3.window")
local open_menu = require("m3.selection.menu").open_menu

local c = theme.c
local text = core.text

local M = {}

-- `f(v)` on a signal, or on a plain number.
---@param v number|Signal<number>
---@param f fun(v: number): any
local function lift(v, f)
    return type(v) == "number" and f(v) or v:map(f)
end

local BAR_HEIGHT = { center = 64, small = 64, medium = 112, large = 120, flexible = 112 }

-- The height of a top app bar of `kind`, for padding the content that scrolls under it.
---@param kind? "small"|"center"|"medium"|"large"|"flexible" Default "small".
---@return number
function M.top_app_bar_height(kind)
    return BAR_HEIGHT[kind or "small"]
end

-- A top app bar. Medium and large bars start with a headline that fades into the title row as
-- `scroll` grows, collapsing the bar to 64px; the bar takes surface container once content
-- passes under it. Pad the scrolling content by `top_app_bar_height(kind)`.
---@class m3.TopAppBarAction
---@field icon string
---@field on_click? fun()
---@field label? string Accessible name.
---@field menu? m3.MenuItem[]|{ items: m3.MenuItem[], width?: number } Opens under the button when clicked, after `on_click`.

---@class m3.TopAppBarOpts
---@field kind? "small"|"center"|"medium"|"large"|"flexible" Default "small". Flexible is the Expressive bar: a title and a subtitle that collapse to the 64px row.
---@field title? string|Signal<string>
---@field subtitle? string|Signal<string> A line under the title.
---@field navigation_icon? string Symbol name of the leading button.
---@field on_navigation? fun()
---@field actions? m3.TopAppBarAction[]
---@field scroll? Signal<number> The content's scroll signal.
---@field window? string A client-side window's id: the bar becomes its title bar (drag moves, double press maximises, right press opens the window menu) and ends in its window controls.
---@field on_close? fun() The window controls' close button; the window's own `on_close`.
---@field [string] "no such property"

---@param id string
---@param opts m3.TopAppBarOpts
---@return Node
function M.top_app_bar(id, opts)
    local kind = opts.kind or "small"
    local top = BAR_HEIGHT[kind]
    local range = top - 64
    local offset = opts.scroll or 0
    local function progress(s) return math.min(s, range) / math.max(range, 1) end
    local function of(f) return lift(offset, f) end
    local kids = {}
    if opts.navigation_icon then
        kids[1] = icon_button(id .. "_nav", {
            kind = "standard",
            icon = opts.navigation_icon,
            on_click = opts.on_navigation,
            props = { align_v = "center", accessible_name = "Navigate" },
        })
    end
    local align = kind == "center" and "center" or "start"
    local fade = range == 0 and 1 or of(function(s) return math.max(0, progress(s) * 2 - 1) end)
    local title_row = text(opts.title, c.on_surface, "title_large", { width = "fill", text_align = align, opacity = not opts.subtitle and fade or nil })
    if opts.subtitle then
        title_row = column {
            width = "fill",
            align_v = "center",
            opacity = fade,
            children = { title_row, text(opts.subtitle, c.on_surface_variant, "label_medium", { width = "fill", text_align = align }) },
        }
    end
    kids[#kids + 1] = title_row
    for i, action in ipairs(opts.actions or {}) do
        local anchor = action.menu and geometry("m3_" .. id .. "_action_" .. i)
        kids[#kids + 1] = icon_button(("%s_action_%d"):format(id, i), {
            kind = "standard",
            icon = action.icon,
            on_click = function()
                if action.on_click then
                    action.on_click()
                end
                if anchor then
                    local menu = action.menu.items and action.menu or { items = action.menu }
                    open_menu({ anchor = anchor, width = menu.width or 224, align = "end", items = menu.items })
                end
            end,
            props = { align_v = "center", geometry = anchor, accessible_name = action.label },
        })
    end
    if opts.window then
        kids[#kids + 1] = window.window_controls(opts.window, opts.on_close)
    end
    local bar = {
        row {
            width = "fill",
            height = 64,
            padding = { left = opts.navigation_icon and 4 or 16, right = 12 },
            spacing = 4,
            children = kids,
        },
    }
    if range > 0 then
        local big = text(opts.title, c.on_surface, kind == "large" and "display_small" or "headline_medium")
        bar[2] = column {
            align_v = "end",
            margin = { left = 16, bottom = 12 },
            opacity = of(function(s) return math.max(0, 1 - progress(s) * 1.6) end),
            translate = of(function(s) return { y = -math.min(s, range) * 0.25 } end),
            children = { big, kind == "flexible" and opts.subtitle and text(opts.subtitle, c.on_surface_variant, "title_medium") or nil },
        }
    end
    if opts.window then
        table.insert(bar, 1, rect { width = "fill", height = "fill", on_press = window.window_drag(opts.window) })
    end
    return rect {
        width = "fill",
        height = of(function(s) return top - math.min(s, range) end),
        background = opts.scroll and computed({ offset, theme.scheme }, function(s, scheme)
            return s >= math.max(range, 1) and scheme.surface_container or scheme.surface
        end) or c.surface,
        animate = { background = { duration = 150 } },
        children = bar,
    }
end

return M
