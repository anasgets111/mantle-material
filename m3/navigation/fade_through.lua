-- M3 fade through for top-level destinations: the old page fades out in 90 ms, then the new one
-- fades in over 210 ms while scaling up from 92%.
local theme = require("m3.theme")
local overlay = require("m3.overlay")

local easing = theme.easing

local M = {}

---@class m3.FadeThroughOpts
---@field scroll? string Prefix of a named `scroll` per page: each page then scrolls under the eased wheel (`scroll(prefix .. key)`).

-- The page for `key`'s current value, switching with a fade through. Any change of `key` also closes
-- the layers open over the old page. `pages` maps each key to its content, built once.
---@param key Signal<string>|StateSignal<string>
---@param pages table<string, Node>
---@param opts? m3.FadeThroughOpts
---@return Node
function M.fade_through(key, pages, opts)
    opts = opts or {}
    if key.on_change then
        key:on_change(overlay.close_all)
    end
    return rect {
        width = "fill",
        height = "fill",
        children = key:map(function(name)
            return {
                column {
                    id = name,
                    width = "fill",
                    height = "fill",
                    scroll = opts.scroll and scroll(opts.scroll .. name) or nil,
                    opacity = 1,
                    scale = 1,
                    origin = { x = 0.5, y = 0 },
                    animate = {
                        scroll = opts.scroll and theme.motion.scroll or nil,
                        opacity = { duration = 210, delay = 90, easing = easing.standard, from = 0 },
                        scale = { duration = 300, delay = 90, easing = easing.emphasized_decelerate, from = 0.92 },
                        exit = { duration = 90, easing = easing.emphasized_accelerate, opacity = 0 },
                    },
                    children = { pages[name] },
                },
            }
        end),
    }
end

return M
