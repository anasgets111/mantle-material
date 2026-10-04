-- M3 tooltips: plain and rich, drawn in the overlay so no ancestor clips them.
local theme = require("m3.theme")
local core = require("m3.core")
local overlay = require("m3.overlay")
local button = require("m3.button").button

local c = theme.c
local SPRING = theme.motion.spatial_fast
local text, merge = core.text, core.merge

local M = {}

local function tip_motion(id)
    return {
        id = id,
        scale = 1,
        opacity = 1,
        animate = {
            scale = { spring = SPRING.spring, from = 0.8 },
            opacity = { duration = 150, from = 0 },
            exit = { duration = 75, opacity = 0 },
        },
    }
end

-- Wraps `child` as a tooltip anchor: hovering it calls `enter`/`leave`, and its rect is published
-- under `anchor_name` for the overlay to place the tip.
local function anchor(id, opts, anchor_name, over, enter, leave)
    return rect {
        hover = over,
        geometry = geometry(anchor_name),
        on_hover = function(inside)
            if inside then
                enter()
            else
                leave()
            end
        end,
        children = { opts.child },
    }
end

local TIP_SPAN = 320

-- Plain tooltip: a short label centred 4px above `child` once the pointer has rested 500 ms,
-- drawn in the overlay so no ancestor clips it. opts: child (the control), label.
function M.tooltip(id, opts)
    local anchor_name = "m3_tip_" .. id
    local over = hover("m3_" .. id)
    local function build(at)
        -- A box TIP_SPAN wide centred on the anchor, the tip centring itself in it. Wider than
        -- the anchor, since a stack cell sizes its child to the cell; a row's `align_h` would
        -- also centre the row in the window layer.
        return rect {
            width = TIP_SPAN,
            margin = at:map(function(r) return { left = r.x + r.width / 2 - TIP_SPAN / 2, top = r.y - 28 } end),
            children = {
                rect(merge(tip_motion(id), {
                    align_h = "center",
                    min_height = 24,
                    min_width = 40,
                    origin = { x = 0.5, y = 1 },
                    padding = { left = 8, right = 8, top = 4, bottom = 4 },
                    radius = 4,
                    background = c.inverse_surface,
                    children = { text(opts.label, c.inverse_on_surface, "body_small", { align_h = "center" }) },
                })),
            },
        }
    end
    return anchor(id, opts, anchor_name, over, function()
        timer(500, function()
            if over:get() then
                overlay.show_tip(id, anchor_name, build)
            end
        end)
    end, function() overlay.hide_tip(id) end)
end

-- Rich tooltip: title, supporting text and an action above `child`'s start, shown after 300 ms of
-- hover and kept while the pointer moves onto it. opts: child, title, body, action (label),
-- on_action.
function M.rich_tooltip(id, opts)
    local anchor_name = "m3_tip_" .. id
    local over = hover("m3_" .. id)
    local tip_over = hover("m3_" .. id .. "_tip")
    local function maybe_hide()
        timer(150, function()
            if not over:get() and not tip_over:get() then
                overlay.hide_tip(id)
            end
        end)
    end
    local function build(at)
        -- The column spans from the window top to just above the anchor; the card sits at its end.
        return rect {
            width = 320,
            height = at:map(function(r) return math.max(0, r.y - 4) end),
            margin = at:map(function(r) return { left = r.x } end),
            children = {
                column(merge(merge(tip_motion(id), theme.elevation[2]), {
                    width = 320,
                    align_v = "end",
                    origin = { x = 0, y = 1 },
                    hittable = true,
                    hover = tip_over,
                    on_hover = function(inside)
                        if not inside then
                            maybe_hide()
                        end
                    end,
                    padding = { left = 16, right = 16, top = 13, bottom = 6 },
                    spacing = 4,
                    radius = 12,
                    background = c.surface_container,
                    children = {
                        text(opts.title, c.on_surface_variant, "title_small"),
                        text(opts.body, c.on_surface_variant, "body_medium", { width = "fill", wrap = "word" }),
                        rect {
                            margin = { top = 10, left = -12 },
                            children = {
                                button(id .. "_action", { kind = "text", label = opts.action, on_click = function()
                                    overlay.hide_tip(id)
                                    if opts.on_action then
                                        opts.on_action()
                                    end
                                end }),
                            },
                        },
                    },
                })),
            },
        }
    end
    return anchor(id, opts, anchor_name, over, function()
        timer(300, function()
            if over:get() then
                overlay.show_tip(id, anchor_name, build)
            end
        end)
    end, maybe_hide)
end

return M
