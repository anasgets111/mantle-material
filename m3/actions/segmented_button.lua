-- M3 Expressive segmented button: one outlined pill split into equal segments.
local theme = require("m3.theme")
local core = require("m3.core")
local check = require("m3.internal.common").check
local keys = require("m3.internal.keys")

local c, FADE, CLEAR = theme.c, theme.motion.fade, theme.CLEAR
local text, icon = core.text, core.icon

local M = {}

-- One outlined pill split into equal segments; the selected ones are tinted, and a text-only one
-- is checked. An option is a label, or `{ label?, icon?, name? }`; icon-only needs a `name`.
---@alias m3.Segment string|{ label?: string, icon?: string, name?: string }

---@class m3.SegmentedButtonOpts
---@field options m3.Segment[]
---@field multi? boolean Several segments can be on; `value` is then a set of keys.
---@field value? StateSignal<string>|StateSignal<table<string, boolean>> The selected key (a label or `name`), or with `multi` the set of selected keys; default the first option, or empty.
---@field width? number Per segment.
---@field [string] "no such property"

---@param id string
---@param opts m3.SegmentedButtonOpts
---@return Node
function M.segmented_button(id, opts)
    local multi = opts.multi
    local function norm(o) return type(o) == "table" and o or { label = o } end
    local function key_of(o) return norm(o).name or norm(o).label end
    local value = opts.value or state("m3_" .. id, multi and {} or key_of(opts.options[1]))
    local bind = keys.roving("seg_" .. id, #opts.options)
    local segments = {}
    for i, option in ipairs(opts.options) do
        local key = key_of(option)
        local label, glyph = norm(option).label, norm(option).icon
        local selected = value:map(function(v)
            if multi then
                return (v or {})[key] == true
            end
            return v == key
        end)
        local fg = theme.pick(selected, "on_secondary_container", "on_surface")
        local content = {}
        if glyph then
            content[1] = icon(glyph, fg, 18)
        end
        if label then
            content[#content + 1] = text(label, fg, "label_large", { id = "label" })
        end
        segments[i] = core.interactive(id .. i, bind(i, {
            -- not in the spec: an icon-only segment is a fixed 52 wide.
            width = opts.width or (not label and 52 or nil),
            height = "fill",
            background = computed({ selected, theme.scheme }, function(on, scheme) return on and scheme.secondary_container or CLEAR end),
            border_width = i > 1 and { left = 1 } or 0,
            border_color = c.outline,
            accessible_name = label or key,
            on_click = function()
                if multi then
                    local set = core.merge({}, value:get())
                    set[key] = not set[key] or nil
                    value:set(set)
                else
                    value:set(key)
                end
            end,
        }), fg, row {
            width = "fill",
            height = "fill",
            align_h = "center",
            align_v = "center",
            spacing = 8,
            children = glyph and content or check(selected, fg, content[1]),
        })
    end
    return rect {
        height = 40,
        radius = 20,
        clip = "rounded",
        children = {
            row { height = "fill", children = segments },
            rect { width = "fill", height = "fill", radius = 20, border_width = 1, border_color = c.outline, hittable = false, animate = { border_color = FADE } },
        },
    }
end

return M
