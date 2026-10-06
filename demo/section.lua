-- The showcase's page furniture, not part of the library: a page of titled section cards.
local m3 = require("m3")

local c = m3.theme.c

local M = {}

-- Cards share the page's width two to a row, or take it whole when a row has room for one; a card
-- left alone on its row, and a wide one, fill the row.
local GAP, PAD = 24, 24
local MIN_CARD = 520
local wide = setmetatable({}, { __mode = "k" })
local pages = 0

-- A page: `sections` (from `card`, `wide` ones marked) in order.
---@param sections Node[]
---@return Node
function M.page(sections)
    pages = pages + 1
    local frame = geometry("m3_demo_page_" .. pages)
    local half = frame:map(function(g)
        local inner = (g.width or 0) - 2 * PAD
        -- One per row below two cards' room: the full width as a number, as "fill" cards share a wrapped line.
        return inner >= 2 * MIN_CARD + GAP and math.floor((inner - GAP) / 2) or math.max(0, inner)
    end)
    local blocks, run = {}, nil
    local function close()
        if run and #run.children % 2 == 1 then
            run.children[#run.children].width = "fill"
        end
        run = nil
    end
    for _, s in ipairs(sections) do
        if wide[s] then
            close()
            blocks[#blocks + 1] = s
        else
            if not run then
                run = row { width = "fill", wrap = true, spacing = GAP, line_spacing = GAP, align_v = "start", children = {} }
                blocks[#blocks + 1] = run
            end
            run.children[#run.children + 1] = column { width = half, children = { s } }
        end
    end
    close()
    return column {
        width = "fill",
        geometry = frame,
        padding = { left = PAD, right = PAD, top = 8, bottom = 32 },
        spacing = GAP,
        children = blocks,
    }
end

-- A filled section with a title, then `children`.
---@param title string
---@param children Node[]
---@param props? table Extra node props.
---@return Node
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

-- A full-row section, for content that needs the window's width (a carousel): `wide(title, children,
-- props)` is a `card` on a row of its own; `wide(node)` marks a node built elsewhere.
---@param title string|Node
---@param children? Node[]
---@param props? table
---@return Node
function M.wide(title, children, props)
    local node = type(title) == "string" and M.card(title, children or {}, props) or title --[[@as Node]]
    wide[node] = true
    return node
end

return M
