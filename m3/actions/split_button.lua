-- M3 Expressive split button: a leading action and a trailing chevron that opens a menu.
local internal = require("m3.internal.button")
local menu = require("m3.selection.menu")

local button = internal.button

local M = {}

-- Split button: a leading action and a trailing chevron that opens `items` as an overlay menu under
-- the whole button and turns over while it shows. Inner corners stay small and spring to 12 while
-- pressed; the open chevron button becomes round.
---@class m3.SplitButtonOpts
---@field kind? m3.ButtonKind Default "primary".
---@field label? string|Signal<string>
---@field icon? string|Signal<string> Material Symbols name.
---@field on_click? fun() The leading action.
---@field disabled? boolean|Signal<boolean> Dimmed to 38% and inert.
---@field items m3.MenuItem[] Menu items, see `open_menu`.
---@field width? number Menu width, default 224.
---@field [string] "no such property"

---@param id string
---@param opts m3.SplitButtonOpts
---@return Node
function M.split_button(id, opts)
    local owner = "split_" .. id
    local open = menu.is_menu_open(owner)
    local anchor = geometry("m3_" .. owner)
    return row {
        spacing = 2,
        geometry = anchor,
        children = {
            button(id .. "_main", {
                kind = opts.kind,
                disabled = opts.disabled,
                label = opts.label,
                icon = opts.icon,
                padding = { left = 16, right = 12 },
                on_click = opts.on_click,
                radius = function(held)
                    return held:map(function(down)
                        local inner = down and 12 or 4
                        return { top_left = 20, bottom_left = 20, top_right = inner, bottom_right = inner }
                    end)
                end,
            }),
            button(id .. "_menu", {
                kind = opts.kind,
                disabled = opts.disabled,
                icon = "keyboard_arrow_down",
                icon_size = 22,
                width = 48,
                on_click = function()
                    menu.open_menu({ id = owner, anchor = anchor, items = opts.items, width = opts.width or 224, align = "end" })
                end,
                icon_props = { rotate = open:map(function(on) return on and 180 or 0 end) },
                radius = function(held)
                    return computed({ held, open }, function(down, on)
                        local inner = on and 20 or down and 12 or 4
                        return { top_left = inner, bottom_left = inner, top_right = 20, bottom_right = 20 }
                    end)
                end,
            }),
        },
    }
end

return M
