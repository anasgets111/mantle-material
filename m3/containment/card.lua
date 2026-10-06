-- Cards: hover lifts one level, press adds the state layer and ripple.
local core = require("m3.core")
local theme = require("m3.theme")
local photo = require("m3.internal.common").photo

local text, interactive, merge = core.text, core.interactive, core.merge
local c, FADE = theme.c, theme.motion.fade

local M = {}

local CARD_STYLE = {
    elevated = { bg = c.surface_container_low },
    filled = { bg = c.surface_container_highest },
    outlined = { bg = c.surface, border = c.outline_variant },
}

-- Container with optional media, text and actions.
---@class m3.CardOpts
---@field kind? "elevated"|"filled"|"outlined" Default "elevated".
---@field media? string Image source across the top.
---@field media_height? number Default 160.
---@field headline? string|Signal<string>
---@field subhead? string|Signal<string>
---@field supporting? string|Signal<string>
---@field actions? Node[] Buttons, right-aligned under the text.
---@field on_click? fun()
---@field props? table Extra node props.
---@field [string] "no such property"

---@param id string
---@param opts m3.CardOpts
---@return Node
function M.card(id, opts)
    local kind = opts.kind or "elevated"
    local over = hover("m3_" .. id)
    local rest = kind == "elevated" and 1 or 0
    local s = CARD_STYLE[kind]
    local body = {}
    if opts.headline then
        body[#body + 1] = text(opts.headline, c.on_surface, "title_large")
    end
    if opts.subhead then
        body[#body + 1] = text(opts.subhead, c.on_surface_variant, "body_medium")
    end
    if opts.supporting then
        body[#body + 1] = text(opts.supporting, c.on_surface_variant, "body_medium", { width = "fill", wrap = "word", margin = { top = 12 } })
    end
    local kids = {}
    if opts.media then
        kids[1] = photo(opts.media, { width = "fill", height = opts.media_height or 160, radius = { top_left = 12, top_right = 12 } })
    end
    kids[#kids + 1] = column { width = "fill", padding = { left = 16, right = 16, top = 16 }, children = body }
    if opts.actions then
        kids[#kids + 1] = row {
            width = "fill",
            align_h = "end",
            spacing = 8,
            padding = { left = 8, right = 16, top = 16, bottom = 16 },
            children = opts.actions,
        }
    end
    return interactive(id, merge({
        width = "fill",
        radius = 12,
        background = s.bg,
        border_width = s.border and 1 or 0,
        border_color = s.border or theme.CLEAR,
        shadows = over:map(function(on) return theme.shadows[on and rest + 1 or rest] end),
        animate = { shadows = { duration = 200 }, background = FADE },
        on_click = opts.on_click,
    }, opts.props), c.on_surface, column { width = "fill", children = kids })
end

return M
