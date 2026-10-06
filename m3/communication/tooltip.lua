-- M3 tooltips: plain and rich, drawn in the overlay so no ancestor clips them.
local theme = require("m3.theme")
local core = require("m3.core")
local overlay = require("m3.overlay")
local button = require("m3.actions.button").button

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
local function anchor(opts, anchor_name, over, enter, leave)
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

local EDGE = 8 -- not in the spec: the least room left between a tip and the host's edge
local tip_box, rich_box = geometry("m3_tip_box"), geometry("m3_rich_tip_box")

-- Where a tip of the measured size `t` goes: `x` along the anchor `r`, 4px above it, below when the
-- host `b` has no room above, slid back inside the host.
local function place(r, b, t, x)
    local w, h = t and t.width or 0, t and t.height or 0
    local left, top = x(r, w), r.y - h - 4
    if b then
        if top < b.y + EDGE then
            top = r.y + r.height + 4
        end
        left = math.max(b.x + EDGE, math.min(left, b.x + b.width - EDGE - w))
    end
    return { left = left, top = top }
end

-- Plain tooltip: a short label centred 4px above `child` once the pointer has rested 500 ms, drawn
-- in the overlay so no ancestor clips it, and kept inside the window.
---@class m3.TooltipOpts
---@field child Node The control.
---@field label string|Signal<string>
---@field window? string The window or panel it shows over; default `core.window`.
---@field [string] "no such property"

---@param id string
---@param opts m3.TooltipOpts
---@return Node
function M.tooltip(id, opts)
    local anchor_name = "m3_tip_" .. id
    local over = hover("m3_" .. id)
    local function build(at, bounds)
        return rect(merge(tip_motion(id), {
            geometry = tip_box,
            margin = computed({ at, bounds, tip_box }, function(r, b, t)
                return place(r, b, t, function(a, w) return a.x + a.width / 2 - w / 2 end)
            end),
            min_height = 24,
            min_width = 40,
            padding = { left = 8, right = 8, top = 4, bottom = 4 },
            radius = 4,
            background = c.inverse_surface,
            children = { text(opts.label, c.inverse_on_surface, "body_small", { align_h = "center" }) },
        }))
    end
    return anchor(opts, anchor_name, over, function()
        timer(500, function()
            if over:get() then
                overlay.show_tip(id, anchor_name, build, opts.window)
            end
        end)
    end, function() overlay.hide_tip(id) end)
end

-- Rich tooltip: title, supporting text and an action above `child`'s start (below it without room), shown after 300 ms of
-- hover and kept while the pointer moves onto it.
---@class m3.RichTooltipOpts
---@field child Node The control.
---@field title string|Signal<string>
---@field body string|Signal<string> Supporting text.
---@field action? string|Signal<string> Label of the action button.
---@field on_action? fun() Runs after the tip closes.
---@field window? string The window or panel it shows over; default `core.window`.
---@field [string] "no such property"

---@param id string
---@param opts m3.RichTooltipOpts
---@return Node
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
    local function build(at, bounds)
        return column(merge(merge(tip_motion(id), theme.elevation[2]), {
            width = 320,
            geometry = rich_box,
            margin = computed({ at, bounds, rich_box }, function(r, b, t)
                return place(r, b, t, function(a) return a.x end)
            end),
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
        }))
    end
    return anchor(opts, anchor_name, over, function()
        timer(300, function()
            if over:get() then
                overlay.show_tip(id, anchor_name, build, opts.window)
            end
        end)
    end, maybe_hide)
end

return M
