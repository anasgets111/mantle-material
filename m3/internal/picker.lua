-- Modal chrome shared by the date and time pickers. Not public API.
local theme = require("m3.theme")
local overlay = require("m3.overlay")
local button = require("m3.button").button

local c = theme.c

local M = {}

-- Modal scaffolding: a 32% scrim and a rounded surface that swallows clicks.

function M.modal(id, width, padding, children)
    return rect {
        id = id,
        width = "fill",
        height = "fill",
        background = theme.scheme:map(function(s) return theme.alpha(s.scrim, 0.32) end),
        opacity = 1,
        on_click = function() overlay.close(id) end,
        animate = { opacity = { duration = 150, from = 0 }, exit = { duration = 150, opacity = 0 } },
        children = {
            column {
                width = width,
                align_h = "center",
                align_v = "center",
                padding = padding,
                spacing = 12,
                radius = 28,
                background = c.surface_container_high,
                scale = 1,
                on_click = function() end,
                cursor = "default",
                focus_ring = false,
                animate = { scale = { duration = 400, easing = theme.easing.emphasized_decelerate, from = 0.9 } },
                children = children,
            },
        },
    }
end

function M.actions(id, name, on_ok)
    return row {
        width = "fill",
        align_h = "end",
        spacing = 8,
        padding = { left = 12, right = 12, top = 8 },
        children = {
            button(name .. "_cancel", { kind = "text", label = "Cancel", on_click = function() overlay.close(id) end }),
            button(name .. "_ok", {
                kind = "text",
                label = "OK",
                on_click = function()
                    on_ok()
                    overlay.close(id)
                end,
            }),
        },
    }
end

return M
