-- Core building blocks every M3 component uses: text in the M3 type scale, Material Symbols
-- icons, and the interactive surface (state layer and ripple).
local theme = require("m3.theme")

local FADE = theme.motion.fade

---@alias m3.Size "xs"|"s"|"m"|"l"|"xl"

local M = {}

-- The window or panel id that layers open over when an opener gets no `window`; default the first
-- window `app_window` built. Set it to the app window's id in a multi-window app.
---@type string?
M.window = nil

-- The scroll ease for a user's scroll column: `animate = { scroll = m3.scroll_ease() }` glides wheel
-- notches on a critically damped spring (quick under reduced motion); Expressive spatial springs overshoot.
---@return table
function M.scroll_ease()
    return theme.motion.scroll
end

local RIPPLE_MS = 450
local HOVER, FOCUS, PRESSED = 0.08, 0.10, 0.10

-- Copies `from`'s fields onto `into`; components use it to let `opts` override their defaults.
---@generic T: table
---@param into T
---@param from? table
---@return T
function M.merge(into, from)
    for k, v in pairs(from or {}) do
        into[k] = v
    end
    return into
end
local merge = M.merge

---@param content string|Signal<string>
---@param color string|Signal<string>
---@param style? string A `theme.type` key; default "body".
---@param props? table
---@return Node
function M.text(content, color, style, props)
    local t = theme.type[style or "body"]
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

-- The unified API's shared icon names, each to its Material Symbols ligature.
local SHARED_ICONS = {
    more = "more_horiz", more_vertical = "more_vert", heart = "favorite", copy = "content_copy", paste = "content_paste",
    cut = "content_cut", file = "insert_drive_file", document = "description", user = "person", bell = "notifications",
    unlock = "lock_open", eye = "visibility", eye_off = "visibility_off", play = "play_arrow", volume = "volume_up",
    camera = "photo_camera", calendar = "calendar_month", clock = "schedule", location = "location_on", attach = "attach_file",
    filter = "filter_list", grid = "grid_view", chevron_down = "keyboard_arrow_down", chevron_up = "keyboard_arrow_up",
    external_link = "open_in_new",
}
local function ligature(name) return SHARED_ICONS[name] or name end

-- Icons are Material Symbols, M3's own icon font: `name` is a shared icon name (`SHARED_ICONS`), else
-- the symbol's ligature, e.g. "star".
-- `props.filled` (boolean or signal) switches to the filled style through the FILL axis.
---@param name string|Signal<string>
---@param color string|Signal<string>
---@param size? number Default 24.
---@param props? table
---@return Node
function M.icon(name, color, size, props)
    props = props or {}
    local function axes(filled)
        return { FILL = filled and 1 or 0, opsz = math.max(20, math.min(48, size or 24)) }
    end
    local filled = props.filled
    props.filled = nil
    props.font_variations = (filled == nil or type(filled) == "boolean") and axes(filled) or filled:map(axes)
    return text(merge({
        content = type(name) == "string" and ligature(name) or name:map(ligature),
        font = "Material Symbols Rounded",
        font_size = size or 24,
        foreground = color,
        align_v = "center",
        animate = { foreground = FADE },
    }, props))
end

-- M3's focus indicator on a node that takes Tab focus: a 3dp `secondary` ring 2dp outside its shape
-- while keyboard focus is on it (`focus_visible`). A clipping parent needs 5dp of room around it.
---@param name string
---@param props table
function M.focusable(name, props)
    local on = focus_visible("m3_fv_" .. name)
    props.focus_visible = on
    props.focus_ring = false
    props.ring = computed({ on, theme.scheme }, function(f, s)
        return f and { width = 3, color = s.secondary, offset = 2 } or nil
    end)
    props.animate = merge({ ring = { duration = 150, easing = "out_quad" } }, props.animate)
end

-- Dims a node to M3's 38% and stops it taking the pointer while `props.disabled` (a boolean or a
-- signal) is true. The field is consumed: nodes reject unknown ones.
---@param props table
function M.disable(props)
    local off = props.disabled
    props.disabled = nil
    if off == nil then
        return
    end
    local function look(d) return d and 0.38 or 1 end
    local function live(d) return not d end
    props.opacity = type(off) == "userdata" and off:map(look) or look(off)
    props.hittable = type(off) == "userdata" and off:map(live) or live(off)
    -- `hittable` stops the pointer only; keyboard activation reaches the handlers, so they check too.
    local function disabled() return off == true or type(off) == "userdata" and off:get() end
    for _, handler in ipairs({ "on_click", "on_key" }) do
        local run = props[handler]
        if run then
            props[handler] = function(...)
                if not disabled() then
                    return run(...)
                end
            end
        end
    end
end

-- A state layer and a ripple under `content`: hover tints the box with `ink` at 8%, keyboard focus
-- at 10% with the focus ring, and each press grows a shape from the pointer at 10%, fading as it spreads.
---@param name string
---@param props table
---@param ink string|Signal<string>
---@param content Node
---@return Node
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
    M.disable(props)
    M.focusable(name, props)
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
