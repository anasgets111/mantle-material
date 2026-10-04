-- The showcase's page furniture, not part of the library: a titled section card.
local m3 = require("m3")

local c = m3.theme.c

local M = {}

-- A filled section with a title, optional one-line description, then `children`.
function M.card(title, children, props)
    table.insert(children, 1, m3.text(title, c.on_surface, "title_medium"))
    return column(m3.merge({
        width = "fill",
        padding = 20,
        spacing = 16,
        radius = 16,
        background = c.surface_container,
        animate = { background = m3.theme.motion.fade },
        children = children,
    }, props))
end

return M
