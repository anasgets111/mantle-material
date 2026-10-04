-- M3 tabs: primary and secondary tabs, and the page of the selected tab.
-- Items are selected by `item.name or index`; every `opts.value` is a state holding that key.
local theme = require("m3.theme")
local core = require("m3.core")
local nav = require("m3.internal.navigation")

local c, pick, motion, easing = theme.c, theme.pick, theme.motion, theme.easing
local FADE = motion.fade
local text, icon, interactive = core.text, core.icon, core.interactive
local key_of, selected_of = nav.key_of, nav.selected_of

local M = {}

-- Primary tabs (3px indicator under the content, icons above labels) or secondary tabs (2px
-- indicator across the tab). The indicator springs to the selected tab's laid-out rect.
-- opts: items { label, icon? }, value (state: tab index), kind ("primary" default | "secondary").
function M.tabs(id, opts)
    local value, items, primary = opts.value, opts.items, opts.kind ~= "secondary"
    local bar = geometry("m3_tabs_" .. id)
    local deps, tabs, tall = { value, bar }, {}, false
    for i, item in ipairs(items) do
        local rect_of = geometry(("m3_tab_%s_%d"):format(id, i))
        deps[#deps + 1] = rect_of
        tall = tall or (primary and item.icon ~= nil)
        local selected = selected_of(value, key_of(item, i))
        local fg = pick(selected, primary and "primary" or "on_surface", "on_surface_variant")
        local kids = {}
        if item.icon then
            kids[1] = icon(item.icon, fg, 24, { align_h = "center", filled = selected })
        end
        kids[#kids + 1] = text(item.label, fg, "title_small", { align_h = "center" })
        tabs[i] = interactive(("tab_%s_%d"):format(id, i), {
            width = "fill",
            height = "fill",
            on_click = function() value:set(key_of(item, i)) end,
            accessible_name = item.label,
            geometry = (not primary) and rect_of or nil,
        }, c.on_surface, column {
            spacing = 2,
            align_h = "center",
            align_v = "center",
            geometry = primary and rect_of or nil,
            children = kids,
        })
    end
    local box = computed(deps, function(v, b, ...)
        local at = 1
        for i, item in ipairs(items) do
            if key_of(item, i) == v then
                at = i
            end
        end
        local g = select(at, ...)
        return { x = g.x - b.x, width = g.width }
    end)
    return rect {
        width = "fill",
        height = tall and 64 or 48,
        geometry = bar,
        children = {
            row { width = "fill", height = "fill", children = tabs },
            rect { width = "fill", height = 1, align_v = "end", background = c.outline_variant, animate = { background = FADE } },
            rect {
                height = primary and 3 or 2,
                align_v = "end",
                radius = primary and { top_left = 3, top_right = 3 } or 0,
                background = c.primary,
                width = box:map(function(b) return b.width end),
                translate = box:map(function(b) return { x = b.x } end),
                animate = { width = motion.spatial_fast, translate = motion.spatial_fast, background = FADE },
            },
        },
    }
end

-- The page of the selected tab, sliding in from the side the tab lies on while the old one fades out.
-- opts: value (the tabs' state), pages (nodes by index), height.
function M.tab_content(id, opts)
    local pages, last = opts.pages, 1
    return rect {
        width = "fill",
        height = opts.height,
        clip = "rounded",
        children = opts.value:map(function(i)
            local dir = i >= last and 1 or -1
            last = i
            return {
                column {
                    id = id .. i,
                    width = "fill",
                    translate = { x = 0 },
                    opacity = 1,
                    animate = {
                        translate = { duration = 300, easing = easing.emphasized_decelerate, from = { x = 32 * dir } },
                        opacity = { duration = 210, delay = 60, easing = easing.standard, from = 0 },
                        exit = { duration = 90, opacity = 0 },
                    },
                    children = { pages[i] },
                },
            }
        end),
    }
end

return M
