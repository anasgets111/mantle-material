-- Carousel layouts: multi-browse and hero (below), uncontained and full-screen. Multi-browse: the wheel scrolls a row whose items are sized from the live offset. With
-- p = offset / step, item i sits at d = i - p and its width interpolates through large, large,
-- medium, small, gone (knots at d = 0..4; one item shrinks away to the left). The small item is 56
-- wide, the medium one fills what is left. Each image keeps the large width, centred, and its box masks it. A leading spacer as
-- wide as the offset cancels the scroll translate, and a trailing spacer keeps the content width
-- constant so the offset spans (#items - 2) steps.
local core = require("m3.core")
local theme = require("m3.theme")
local photo = require("m3.internal.common").photo
local icon_button = require("m3.actions.icon_button").icon_button

local text = core.text
local c = theme.c

local M = {}

local GAP, SMALL = 8, 56

-- The contained layouts: the large item's width, the item widths at d = -1..4, and how many steps
-- the offset spans.
local LAYOUTS = {
    multi_browse = {
        large = function(w) return 0.36 * w end,
        knots = function(w)
            local large = 0.36 * w
            local medium = math.max(SMALL, math.min(large, w - 2 * large - SMALL - 4 * GAP))
            return { [-1] = 0, [0] = large, large, medium, SMALL, 0 }
        end,
        steps = function(n) return math.max(n - 2, 0) end,
    },
    -- One large item with two small ones beside it.
    hero = {
        large = function(w) return math.max(SMALL, w - 2 * SMALL - 2 * GAP) end,
        knots = function(w) return { [-1] = 0, [0] = math.max(SMALL, w - 2 * SMALL - 2 * GAP), SMALL, SMALL, 0, 0 } end,
        steps = function(n) return math.max(n - 1, 0) end,
    },
}

local function size(k, d)
    if d <= -1 or d >= 4 then
        return 0
    end
    local f = math.floor(d)
    return k[f] + (k[f + 1] - k[f]) * (d - f)
end

---@class m3.CarouselItem
---@field image string Image source.
---@field label? string
---@field [string] "no such property"

---@class m3.CarouselOpts
---@field items m3.CarouselItem[] Required.
---@field layout? "multi_browse"|"hero"|"uncontained"|"full_screen" Default "multi_browse". Uncontained scrolls fixed-width items; full screen stacks full-width items vertically.
---@field item_width? number Uncontained: each item's width. Default 186. Not in the spec: its size.
---@field height? number Default 221 (full screen: each item's height).
---@field controls? boolean Previous / next buttons under the strip; `false` hides them. Default true.
---@field [string] "no such property"

---@param id string
---@param opts m3.CarouselOpts
---@return Node
function M.carousel(id, opts)
    local items, height = opts.items, opts.height or 221
    local layout = opts.layout or "multi_browse"
    local plain = layout == "uncontained" or layout == "full_screen"
    local shape = LAYOUTS[layout] or LAYOUTS.multi_browse
    local offset = scroll("m3_" .. id)
    local track = geometry("m3_" .. id)
    local function widths(off, box)
        local w = box and box.width or 0
        local p = off / (shape.large(w) + GAP)
        local k, out, sum = shape.knots(w), {}, 0
        for i = 1, #items do
            out[i] = math.floor(size(k, i - 1 - p))
            sum = sum + out[i] + math.min(GAP, out[i])
        end
        return out, sum, w
    end

    local item_w = opts.item_width or 186
    -- One item position: the large item's width plus the gap.
    local function step()
        if plain then
            return (layout == "full_screen" and height or item_w) + GAP
        end
        return shape.large((track:get() or {}).width or 0) + GAP
    end

    local large = track:map(function(box) return shape.large(box and box.width or 0) end)
    local function caption(item, shown)
        return rect {
            align_v = "end",
            margin = 12,
            height = 28,
            radius = 14,
            background = c.surface_container,
            opacity = shown,
            animate = { opacity = { duration = 150 } },
            children = { row { height = "fill", align_v = "center", padding = { left = 12, right = 12 }, children = { text(item.label, c.on_surface, "label_large") } } },
        }
    end
    local kids = plain and {} or { rect { width = offset, height = 1 } }
    for i, item in ipairs(items) do
        -- A click brings the item to the front.
        local function front() offset:scroll_to((i - 1) * step()) end
        if plain then
            local full = layout == "full_screen"
            kids[i] = rect {
                width = full and "fill" or item_w,
                height = height,
                radius = full and 0 or 28,
                clip = "rounded",
                on_click = front,
                accessible_name = item.label,
                children = { photo(item.image, { width = "fill", height = "fill" }), item.label and caption(item, 1) or nil },
            }
        else
            local width = computed({ offset, track }, function(off, box) return (widths(off, box))[i] end)
            kids[#kids + 1] = rect {
                width = width,
                height = height,
                radius = 28,
                clip = "rounded",
                margin = width:map(function(w) return { right = math.min(GAP, w) } end),
                on_click = front,
                accessible_name = item.label,
                children = {
                    photo(item.image, { width = large, height = "fill", align_h = "center" }),
                    item.label and caption(item, width:map(function(w) return w > 160 and 1 or 0 end)) or nil,
                },
            }
        end
    end
    if not plain then
        kids[#kids + 1] = rect {
            width = computed({ offset, track }, function(off, box)
                local _, sum, w = widths(off, box)
                return math.max(0, w + shape.steps(#items) * (shape.large(w) + GAP) - off - sum)
            end),
            height = 1,
        }
    end
    local vertical = layout == "full_screen"
    local strip = (vertical and column or row) {
        width = "fill",
        height = height,
        spacing = plain and GAP or nil,
        geometry = track,
        scroll = offset,
        animate = { scroll = theme.motion.scroll },
        children = kids,
    }
    if opts.controls == false then
        return strip
    end
    -- Previous / next step one item; repeated clicks add up while the scroll eases.
    return column {
        width = "fill",
        spacing = 8,
        children = {
            strip,
            row {
                width = "fill",
                align_h = "end",
                spacing = 8,
                children = {
                    icon_button(id .. "_prev", { kind = "outlined", icon = vertical and "expand_less" or "chevron_left", props = { accessible_name = "Previous" }, on_click = function() offset:scroll_by(-step()) end }),
                    icon_button(id .. "_next", { kind = "outlined", icon = vertical and "expand_more" or "chevron_right", props = { accessible_name = "Next" }, on_click = function() offset:scroll_by(step()) end }),
                },
            },
        },
    }
end

return M
