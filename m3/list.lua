-- List items: 56, 72 or 88 high by line count; `list` is a scrolling keyed list with move / enter / exit animation.
local core = require("m3.core")
local theme = require("m3.theme")
local photo = require("m3.internal.common").photo
local controls = { checkbox = require("m3.checkbox").checkbox, switch = require("m3.switch").switch }

local text, icon, interactive = core.text, core.icon, core.interactive
local c, FADE, easing = theme.c, theme.motion.fade, theme.easing

local M = {}

local MOVE = { duration = 400, easing = easing.emphasized_decelerate }

local function leading(spec, align)
    if spec.icon then
        return icon(spec.icon, c.on_surface_variant, 24, { align_v = align })
    elseif spec.avatar then
        return rect {
            width = 40,
            height = 40,
            radius = 20,
            align_v = align,
            background = c.primary_container,
            animate = { background = FADE },
            children = { text(spec.avatar, c.on_primary_container, "title_medium", { align_h = "center" }) },
        }
    elseif spec.image then
        return photo(spec.image, { width = 56, height = 56, radius = 8, align_v = align })
    end
    return spec.node
end

local function trailing(id, spec, align)
    if spec.text then
        return text(spec.text, c.on_surface_variant, "label_small", { align_v = align })
    end
    local control = spec.checkbox and "checkbox" or spec.switch and "switch"
    if control then
        local value = spec[control]
        if value == true then
            value = state("m3_" .. id .. "_" .. control, control == "switch")
        end
        return rect { align_v = align, children = { controls[control](id .. "_" .. control, { value = value }) } }
    end
    return spec.node
end

-- `opts`: lines (1-3 strings or signals, required), leading ({ icon | avatar | image | node }),
-- trailing ({ text | checkbox | switch (true or a state signal) | node }), on_click, animated
-- (move, fade in and exit, for rows of a keyed `list`).
function M.list_item(id, opts)
    local lines = opts.lines
    local texts = { text(lines[1], c.on_surface, "body_large") }
    for i = 2, #lines do
        texts[i] = text(lines[i], c.on_surface_variant, "body_medium", { wrap = "word", width = "fill" })
    end
    local align = #lines == 3 and "start" or "center"
    local kids = {}
    if opts.leading then
        kids[1] = leading(opts.leading, align)
    end
    kids[#kids + 1] = column { width = "fill", align_v = align, children = texts }
    if opts.trailing then
        kids[#kids + 1] = trailing(id, opts.trailing, align)
    end
    local props = { width = "fill", height = ({ 56, 72, 88 })[#lines], on_click = opts.on_click }
    if opts.animated then
        props.opacity = 1
        props.animate = { move = MOVE, opacity = { duration = 200, from = 0 }, exit = { duration = 150, opacity = 0 } }
    end
    return interactive(id, props, c.on_surface, row {
        width = "fill",
        height = "fill",
        align_v = align,
        spacing = 16,
        padding = { left = 16, right = opts.trailing and opts.trailing.node and 12 or 16, top = align == "start" and 12 or 0 },
        children = kids,
    })
end

-- `opts`: source (a list signal), key (fn(entry) -> string), item (fn(entry) -> node, usually a
-- `list_item` with `animated`), height, width.
function M.list(id, opts)
    return list {
        width = opts.width or "fill",
        height = opts.height,
        scroll = scroll("m3_" .. id),
        animate = { scroll = 160 },
        source = opts.source,
        key = opts.key,
        itemfn = opts.item,
    }
end

return M
