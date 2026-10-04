-- M3 top app bar: small, center-aligned, medium and large.
local theme = require("m3.theme")
local core = require("m3.core")
local icon_button = require("m3.icon_button").icon_button

local c = theme.c
local text = core.text

local M = {}

-- `f(v)` on a signal, or on a plain number.
local function lift(v, f)
    return type(v) == "number" and f(v) or v:map(f)
end

local BAR_HEIGHT = { center = 64, small = 64, medium = 112, large = 120 }

-- The height of a top app bar of `kind`, for padding the content that scrolls under it.
function M.top_app_bar_height(kind)
    return BAR_HEIGHT[kind or "small"]
end

-- A top app bar. Medium and large bars start with a headline that fades into the title row as
-- `scroll` grows, collapsing the bar to 64px; the bar takes surface container once content
-- passes under it. Pad the scrolling content by `top_app_bar_height(kind)`.
-- opts: kind ("small" default | "center" | "medium" | "large"), title (text or signal),
-- navigation_icon (symbol name), on_navigation, actions { { icon, on_click, label?, geometry? } },
-- scroll (the content's scroll signal).
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
    kids[#kids + 1] = text(opts.title, c.on_surface, "title_large", {
        width = "fill",
        text_align = kind == "center" and "center" or "start",
        opacity = range == 0 and 1 or of(function(s) return math.max(0, progress(s) * 2 - 1) end),
    })
    for i, action in ipairs(opts.actions or {}) do
        kids[#kids + 1] = icon_button(("%s_action_%d"):format(id, i), {
            kind = "standard",
            icon = action.icon,
            on_click = action.on_click,
            props = { align_v = "center", geometry = action.geometry, accessible_name = action.label },
        })
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
        bar[2] = text(opts.title, c.on_surface, kind == "large" and "display_small" or "headline_medium", {
            align_v = "end",
            margin = { left = 16, bottom = 12 },
            opacity = of(function(s) return math.max(0, 1 - progress(s) * 1.6) end),
            translate = of(function(s) return { y = -math.min(s, range) * 0.25 } end),
        })
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
