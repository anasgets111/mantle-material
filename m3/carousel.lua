-- Multi-browse carousel: the wheel scrolls a row whose items are sized from the live offset. With
-- p = offset / step, item i sits at d = i - p and its width interpolates through large, large,
-- medium, small, gone (knots at d = 0..4; one item shrinks away to the left). The small item is 56
-- wide, the medium one fills what is left. Each image keeps the large width, centred, and its box masks it. A leading spacer as
-- wide as the offset cancels the scroll translate, and a trailing spacer keeps the content width
-- constant so the offset spans (#items - 2) steps.
local core = require("m3.core")
local theme = require("m3.theme")
local photo = require("m3.internal.common").photo
local icon_button = require("m3.icon_button").icon_button

local text = core.text
local c = theme.c

local M = {}

local GAP, SMALL = 8, 56

local function knots(w)
    local large = 0.36 * w
    local medium = math.max(SMALL, math.min(large, w - 2 * large - SMALL - 4 * GAP))
    return { [-1] = 0, [0] = large, large, medium, SMALL, 0 }
end

local function size(k, d)
    if d <= -1 or d >= 4 then
        return 0
    end
    local f = math.floor(d)
    return k[f] + (k[f + 1] - k[f]) * (d - f)
end

-- `opts`: items ({ image = source, label = string }), height (221).
function M.carousel(id, opts)
    local items, height = opts.items, opts.height or 221
    local offset = scroll("m3_" .. id)
    local track = geometry("m3_" .. id)
    local function widths(off, box)
        local w = box and box.width or 0
        local p = off / (0.36 * w + GAP)
        local k, out, sum = knots(w), {}, 0
        for i = 1, #items do
            out[i] = math.floor(size(k, i - 1 - p))
            sum = sum + out[i] + math.min(GAP, out[i])
        end
        return out, sum, w
    end

    -- One item position: the large item's width plus the gap.
    local function step()
        return 0.36 * ((track:get() or {}).width or 0) + GAP
    end

    local large = track:map(function(box) return 0.36 * (box and box.width or 0) end)
    local kids = { rect { width = offset, height = 1 } }
    for i, item in ipairs(items) do
        local width = computed({ offset, track }, function(off, box) return (widths(off, box))[i] end)
        local layers = { photo(item.image, { width = large, height = "fill", align_h = "center" }) }
        if item.label then
            layers[2] = rect {
                align_v = "end",
                margin = 12,
                height = 28,
                radius = 14,
                background = c.surface_container,
                opacity = width:map(function(w) return w > 160 and 1 or 0 end),
                animate = { opacity = { duration = 150 } },
                children = { row { height = "fill", align_v = "center", padding = { left = 12, right = 12 }, children = { text(item.label, c.on_surface, "label_large") } } },
            }
        end
        kids[#kids + 1] = rect {
            width = width,
            height = height,
            radius = 28,
            clip = "rounded",
            margin = width:map(function(w) return { right = math.min(GAP, w) } end),
            -- A click brings the item to the front.
            on_click = function() offset:scroll_to((i - 1) * step()) end,
            accessible_name = item.label,
            children = layers,
        }
    end
    kids[#kids + 1] = rect {
        width = computed({ offset, track }, function(off, box)
            local _, sum, w = widths(off, box)
            return math.max(0, w + math.max(#items - 2, 0) * (0.36 * w + GAP) - off - sum)
        end),
        height = 1,
    }
    local strip = row {
        width = "fill",
        height = height,
        geometry = track,
        scroll = offset,
        animate = { scroll = 160 },
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
                    icon_button(id .. "_prev", { kind = "outlined", icon = "chevron_left", props = { accessible_name = "Previous" }, on_click = function() offset:scroll_by(-step()) end }),
                    icon_button(id .. "_next", { kind = "outlined", icon = "chevron_right", props = { accessible_name = "Next" }, on_click = function() offset:scroll_by(step()) end }),
                },
            },
        },
    }
end

return M
