-- M3 date picker: the month grid slides sideways, today is outlined, the selection is a filled
-- circle and a range adds the in-range band. Modal (with a headline) or docked under its field.
local theme = require("m3.theme")
local core = require("m3.core")
local overlay = require("m3.overlay")
local picker = require("m3.internal.picker")
local sel = require("m3.internal.selection")
local text_field = require("m3.text_field").text_field
local icon_button = require("m3.icon_button").icon_button

local c = theme.c
local text, interactive, merge = core.text, core.interactive, core.merge
local CLEAR, ZERO = theme.CLEAR, sel.ZERO
local modal, actions = picker.modal, picker.actions

local M = {}

local MONTHS = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }
local DAYS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
local CELL_W, CELL_H = 48, 40

local date_default = state("m3_date_default", {})
---@type table
local date_spec = {}
local draft = state("m3_date_draft", {})
---@type StateSignal<boolean>
local ranged = state("m3_date_range", false)
local view = state("m3_date_view", { y = 2026, m = 1, dir = 1 })

local function stamp(y, m, d) return os.time({ year = y, month = m, day = d, hour = 12 }) end
local function short(n)
    local y, m, d = n // 10000, n // 100 % 100, n % 100
    return string.format("%s, %s %d", DAYS[os.date("*t", stamp(y, m, d)).wday], MONTHS[m]:sub(1, 3), d)
end
local function describe(t, empty)
    if not t or not t.a then
        return empty
    end
    return t.b and (short(t.a) .. " – " .. short(t.b)) or short(t.a)
end

local function shift(dir)
    local v = view:get()
    local y, m = v.y, v.m + dir
    if m < 1 then
        y, m = y - 1, 12
    elseif m > 12 then
        y, m = y + 1, 1
    end
    view:set({ y = y, m = m, dir = dir })
end

local function today()
    local now = os.date("*t", (mantle.system:get() or { time = os.time() }).time)
    return now.year, now.month, now.day
end

local function pick_day(d)
    local t = draft:get() or {}
    if ranged:get() and t.a and not t.b and d > t.a then
        draft:set({ a = t.a, b = d })
    else
        draft:set({ a = d })
    end
end

local function day_cell(slot, d, t, now)
    if not d then
        return rect { width = CELL_W, height = CELL_H }
    end
    local a, b = t.a, t.b
    local chosen = d == a or d == b
    local kids = {}
    if a and b and a ~= b and d >= a and d <= b then
        kids[1] = rect {
            width = (d == a or d == b) and CELL_W / 2 or "fill",
            height = "fill",
            align_h = d == a and "end" or "start",
            background = c.secondary_container,
        }
    end
    local is_today = d == now and not chosen
    local fg = chosen and c.on_primary or is_today and c.primary or a and b and d > a and d < b and c.on_secondary_container or c.on_surface
    kids[#kids + 1] = interactive("dp_" .. slot, {
        width = 40,
        height = 40,
        radius = 20,
        align_h = "center",
        background = chosen and c.primary or CLEAR,
        border_width = is_today and 1 or 0,
        border_color = c.primary,
        accessible_name = short(d),
        on_click = function() pick_day(d) end,
    }, fg, text(tostring(d % 100), fg, "body_large", { align_h = "center" }))
    return rect { width = CELL_W, height = CELL_H, children = kids }
end

local function month_grid()
    local ty, tm, td = today()
    local now = ty * 10000 + tm * 100 + td
    return computed({ view, draft }, function(v, t)
        local first = os.date("*t", stamp(v.y, v.m, 1)).wday
        local count = os.date("*t", os.time({ year = v.y, month = v.m + 1, day = 0, hour = 12 })).day
        local rows = {}
        for r = 0, 5 do
            local cells = {}
            for col = 1, 7 do
                local day = r * 7 + col - first + 1
                local valid = day >= 1 and day <= count
                cells[col] = day_cell(r * 7 + col, valid and (v.y * 10000 + v.m * 100 + day) or nil, t or {}, now)
            end
            rows[r + 1] = row { children = cells }
        end
        local W = 7 * CELL_W
        return {
            column {
                id = "grid" .. v.y .. "_" .. v.m,
                width = W,
                translate = { x = 0 },
                opacity = 1,
                animate = {
                    translate = { duration = 300, easing = theme.easing.emphasized_decelerate, from = { x = v.dir * W } },
                    opacity = { duration = 200, from = 0 },
                    exit = { duration = 200, easing = theme.easing.emphasized_accelerate, opacity = 0, translate = { x = -v.dir * W } },
                },
                children = rows,
            },
        }
    end)
end

local function date_layer(id)
    local o = date_spec
    local weekdays = {}
    for i, name in ipairs({ "S", "M", "T", "W", "T", "F", "S" }) do
        weekdays[i] = rect { width = CELL_W, height = CELL_H, children = { text(name, c.on_surface, "body_large", { align_h = "center" }) } }
    end
    local body = {
        row {
            width = "fill",
            align_v = "center",
            padding = { left = 12 },
            children = {
                text(view:map(function(v) return MONTHS[v.m] .. " " .. v.y end), c.on_surface_variant, "label_large", { width = "fill" }),
                icon_button("dp_prev", { kind = "standard", icon = "chevron_left", on_click = function() shift(-1) end, props = { align_v = "center" } }),
                icon_button("dp_next", { kind = "standard", icon = "chevron_right", on_click = function() shift(1) end, props = { align_v = "center" } }),
            },
        },
        row { children = weekdays },
        rect { width = 7 * CELL_W, height = 6 * CELL_H, clip = "box", children = month_grid() },
        actions(id, "dp", function()
            local t = draft:get() or {}
            o.value:set(t)
            if o.on_change then
                o.on_change(t)
            end
        end),
    }
    if o.docked then
        return rect {
            id = id,
            width = "fill",
            height = "fill",
            cursor = "default",
            focus_ring = false,
            on_click = function() overlay.close(id) end,
            animate = { exit = { duration = 100, opacity = 0 } },
            children = {
                column(merge({
                    width = 7 * CELL_W + 24,
                    padding = { left = 12, right = 12, top = 8, bottom = 12 },
                    spacing = 4,
                    radius = 16,
                    background = c.surface_container_high,
                    margin = o.anchor:map(function(r)
                        r = r or ZERO
                        return { left = r.x, top = r.y + r.height + 4 }
                    end),
                    origin = { x = 0.5, y = 0 },
                    scale = 1,
                    opacity = 1,
                    on_click = function() end,
                    cursor = "default",
                    focus_ring = false,
                    animate = { scale = { duration = 300, easing = theme.easing.emphasized_decelerate, from = { x = 1, y = 0.6 } }, opacity = { duration = 150, from = 0 } },
                    children = body,
                }, theme.elevation[3])),
            },
        }
    end
    return modal(id, 7 * CELL_W + 24, { left = 12, right = 12, bottom = 12 }, {
        column {
            height = 120,
            padding = { left = 12, right = 12, top = 16 },
            spacing = 36,
            children = {
                text(ranged:map(function(r) return r and "Select dates" or "Select date" end), c.on_surface_variant, "label_large"),
                text(computed({ draft, ranged }, function(t, r) return describe(t, r and "Start – End" or "Pick a day") end), c.on_surface_variant, "headline_large", { font_size = ranged:map(function(r) return theme.type[r and "title_large" or "headline_large"][1] end) }),
            },
        },
        rect { width = "fill", height = 1, background = c.outline_variant },
        table.unpack(body),
    })
end
overlay.layer("date", function() return date_layer("date") end)
overlay.layer("date_docked", function() return date_layer("date_docked") end)

-- opts: value (state { a, b }: days as yyyymmdd, `b` ending a range), range (pick two days),
-- docked (a calendar under `anchor`, a `geometry(name)` signal, instead of a modal), on_change(t).
function M.open_date_picker(opts)
    date_spec = merge({ value = date_default }, opts)
    local t = date_spec.value:get() or {}
    local y, m, d = today()
    local focus = t.a or (y * 10000 + m * 100 + d)
    draft:set(t)
    ranged:set(opts.range == true)
    view:set({ y = focus // 10000, m = focus // 100 % 100, dir = 1 })
    overlay.open(opts.docked and "date_docked" or "date")
end

-- The docked picker's field. opts: label, value (as `open_date_picker`), range, kind, container,
-- width, on_change.
function M.date_picker(id, opts)
    local value = opts.value or state("m3_date_" .. id, {})
    local anchor = geometry("m3_date_" .. id)
    return (text_field(id, {
        kind = opts.kind,
        label = opts.label,
        container = opts.container,
        width = opts.width or 280,
        display = value:map(function(t) return describe(t, "") end),
        trailing = "calendar_today",
        geometry = anchor,
        active = overlay.is_open("date_docked"),
        on_click = function() M.open_date_picker({ docked = true, anchor = anchor, value = value, range = opts.range, on_change = opts.on_change }) end,
    }))
end

return M
