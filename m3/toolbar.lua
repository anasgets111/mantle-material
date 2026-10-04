-- M3 toolbar (Expressive): docked or floating, with icon actions and an optional FAB.
local theme = require("m3.theme")
local core = require("m3.core")
local icon_button = require("m3.icon_button").icon_button
local fab_button = require("m3.fab").fab

local c, motion = theme.c, theme.motion
local FADE = motion.fade
local merge = core.merge

local M = {}

-- A toolbar of icon actions with an optional FAB. "docked" spans the bottom edge; "floating" is a
-- pill above it that slides away while `scroll` grows and returns when it shrinks.
-- opts: kind ("docked" default | "floating"), actions { { icon, on_click, label? } }, fab
-- { icon, label, on_click }, scroll (the content's scroll signal; floating only).
function M.toolbar(id, opts)
    local kids = {}
    for i, action in ipairs(opts.actions or {}) do
        kids[i] = icon_button(("%s_%d"):format(id, i), {
            kind = "standard",
            icon = action.icon,
            on_click = action.on_click,
            props = { align_v = "center", accessible_name = action.label },
        })
    end
    local fab = opts.fab and fab_button(id .. "_fab", {
        icon = opts.fab.icon,
        on_click = opts.fab.on_click,
        props = merge({ align_v = "center", accessible_name = opts.fab.label }, theme.elevation[0]),
    })
    if opts.kind ~= "floating" then
        kids[#kids + 1] = rect { width = "fill", height = 1 }
        kids[#kids + 1] = fab
        return row {
            width = "fill",
            height = 64,
            align_v = "end",
            padding = { left = 8, right = 16 },
            spacing = 4,
            background = c.surface_container,
            animate = { background = FADE },
            children = kids,
        }
    end
    -- Hide on a scroll down, show on a scroll up: `last` is the offset the previous pass saw.
    local last, away = 0, false
    local hidden = opts.scroll and opts.scroll:map(function(s)
        if s <= 0 or s < last - 1 then
            away = false
        elseif s > last + 1 then
            away = true
        end
        last = s
        return away
    end)
    return row {
        align_h = "center",
        align_v = "end",
        margin = { bottom = 16 },
        spacing = 8,
        translate = hidden and hidden:map(function(h) return { y = h and 96 or 0 } end),
        animate = { translate = motion.spatial },
        children = {
            row {
                height = 64,
                radius = 32,
                align_v = "center",
                padding = { left = 8, right = 8 },
                spacing = 4,
                background = c.surface_container,
                shadows = theme.shadows[3],
                animate = { background = FADE },
                children = kids,
            },
            fab,
        },
    }
end

return M
