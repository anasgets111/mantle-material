-- Core building blocks every M3 component uses: text in the M3 type scale, Material Symbols
-- icons, and the interactive surface (state layer and ripple).
local theme = require("m3.theme")

local FADE = theme.motion.fade

local M = {}

local RIPPLE_MS = 450
local HOVER, FOCUS, PRESSED = 0.08, 0.10, 0.10

-- Copies `from`'s fields onto `into`; components use it to let `opts` override their defaults.
function M.merge(into, from)
    for k, v in pairs(from or {}) do
        into[k] = v
    end
    return into
end
local merge = M.merge

function M.text(content, color, style, props)
    local t = theme.type[style or "body_medium"]
    return text(merge({
        content = content,
        foreground = color,
        font_size = t[1],
        font_weight = t[2],
        line_height = t[3] / t[1],
        letter_spacing = t[4],
        align_v = "center",
        animate = { foreground = FADE },
    }, props))
end

-- Icons are Material Symbols, M3's own icon font: `name` is the symbol's ligature, e.g. "star".
-- `props.filled` (boolean or signal) switches to the filled style through the FILL axis.
function M.icon(name, color, size, props)
    props = props or {}
    local function axes(filled)
        return { FILL = filled and 1 or 0, opsz = math.max(20, math.min(48, size or 24)) }
    end
    local filled = props.filled
    props.filled = nil
    props.font_variations = (filled == nil or type(filled) == "boolean") and axes(filled) or filled:map(axes)
    return text(merge({
        content = name,
        font = "Material Symbols Rounded",
        font_size = size or 24,
        foreground = color,
        align_v = "center",
        animate = { foreground = FADE },
    }, props))
end

-- A state layer and a ripple under `content`: hover tints the box with `ink` at 8%, keyboard focus
-- at 10%, and each press grows a shape from the pointer at 10%, fading as it spreads.
function M.interactive(name, props, ink, content)
    local over = hover("m3_" .. name)
    local held = props.focused or focused("m3_focus_" .. name)
    ---@type StateSignal<table|false>
    local press = state("m3_press_" .. name, false)
    local radius = props.radius or 0
    local layer = rect {
        id = "layer",
        width = "fill",
        height = "fill",
        background = ink,
        opacity = computed({ over, held }, function(on, kb) return kb and FOCUS or on and HOVER or 0 end),
        animate = { opacity = { duration = 150, easing = "out_quad" } },
    }
    content.id = "content"
    props.hover = over
    props.focused = held
    props.clip = "rounded"
    props.animate = merge({ background = FADE, border_color = FADE }, props.animate)
    props.on_drag = function(box, pointer, phase)
        if phase == "start" then
            local last = press:get()
            local n = (last and last.n or 0) + 1
            -- Forget the ripple once it has played: named state outlives the node, and a rebuilt
            -- node (a reopened menu) would otherwise replay the last press as it enters.
            timer(RIPPLE_MS, function()
                local now = press:get()
                if now and now.n == n then
                    press:set(false)
                end
            end)
            press:set({
                n = n,
                x = math.max(0, math.min(1, pointer.x / math.max(1, box.width))),
                y = math.max(0, math.min(1, pointer.y / math.max(1, box.height))),
            })
        end
    end
    props.children = press:map(function(p)
        local kids = { layer }
        if p then
            kids[2] = rect {
                id = "ripple" .. p.n,
                width = "fill",
                height = "fill",
                radius = radius,
                background = ink,
                origin = { x = p.x, y = p.y },
                scale = 6,
                opacity = 0,
                animate = {
                    scale = { duration = 225, easing = "out_cubic", from = 0 },
                    opacity = { duration = RIPPLE_MS, easing = "in_quad", from = PRESSED },
                },
            }
        end
        kids[#kids + 1] = content
        return kids
    end)
    return rect(props)
end

return M
