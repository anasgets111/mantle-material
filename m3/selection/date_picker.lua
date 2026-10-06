-- M3 date picker: the month grid slides sideways, today is outlined, the selection is a filled
-- circle and a range adds the in-range band. Modal (with a headline) or docked under its field.
local theme = require("m3.theme")
local core = require("m3.core")
local overlay = require("m3.overlay")
local picker = require("m3.internal.picker")
local sel = require("m3.internal.selection")
local text_field = require("m3.inputs.text_field").text_field
local icon_button = require("m3.actions.icon_button").icon_button

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
---@type StateSignal<boolean>
local typing = state("m3_date_input", false)
local typed = state("m3_date_input_text", "")
local typed_end = state("m3_date_input_end", "")

local function stamp(y, m, d) return os.time({ year = y, month = m, day = d, hour = 12 }) end
local function short(n)
    local y, m, d = n // 10000, n // 100 % 100, n % 100
    return string.format("%s, %s %d", DAYS[os.date("*t", stamp(y, m, d)).wday], MONTHS[m]:sub(1, 3), d)
end
-- `brief`: month and day only, so a range fits the modal's header beside its mode icon.
local function describe(t, empty, brief)
    if not t or not t.a then
        return empty
    end
    local day = brief and function(n) return short(n):match(", (.*)") end or short
    return t.b and (day(t.a) .. " – " .. day(t.b)) or day(t.a)
end

-- The input mode's mm/dd/yyyy: a mask over the digits, and the day it spells (yyyymmdd) if real.
local function mask(t)
    local d = (t:gsub("%D", "")):sub(1, 8)
    if #d > 4 then
        return d:sub(1, 2) .. "/" .. d:sub(3, 4) .. "/" .. d:sub(5)
    end
    return #d > 2 and d:sub(1, 2) .. "/" .. d:sub(3) or d
end
local function slashed(n) return n and string.format("%02d/%02d/%04d", n // 100 % 100, n % 100, n // 10000) or "" end
local function parse(t)
    local m, d, y = t:match("^(%d%d)/(%d%d)/(%d%d%d%d)$")
    if not m then
        return nil
    end
    m, d, y = tonumber(m), tonumber(d), tonumber(y)
    if y < 1900 then
        return nil
    end
    local real = os.date("*t", stamp(y, m, d))
    return real.day == d and real.month == m and y * 10000 + m * 100 + d or nil
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
    local calendar = {
        row {
            width = "fill",
            align_v = "center",
            padding = { left = 12 },
            children = {
                text(view:map(function(v) return MONTHS[v.m] .. " " .. v.y end), c.on_surface_variant, "label_large", { width = "fill" }),
                icon_button("dp_prev", { kind = "plain", icon = "chevron_left", on_click = function() shift(-1) end, props = { align_v = "center" } }),
                icon_button("dp_next", { kind = "plain", icon = "chevron_right", on_click = function() shift(1) end, props = { align_v = "center" } }),
            },
        },
        row { children = weekdays },
        rect { width = 7 * CELL_W, height = 6 * CELL_H, clip = "box", children = month_grid() },
    }
    local function commit()
        local t = draft:get() or {}
        o.value:set(t)
        if o.on_change then
            o.on_change(t)
        end
    end
    local body = { table.unpack(calendar) }
    body[#body + 1] = actions(id, "dp", commit)
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
    local calendar_col = column { children = calendar }
    local function field(name, label, value, validate, on_change, width)
        return (text_field(name, {
            label = label,
            placeholder = "mm/dd/yyyy",
            supporting = "mm/dd/yyyy",
            container = c.surface_container_high,
            value = value,
            width = width,
            autofocus = value == typed,
            format = mask,
            validate = validate,
            on_change = on_change,
        }))
    end
    local function bad_date(t) return #t == 10 and not parse(t) and "Invalid date" or nil end
    local fields
    if o.range then
        -- A range's input mode is two fields; the end must be a real day on or after the start.
        local function sync()
            local a, b = parse(typed:get()), parse(typed_end:get())
            draft:set({ a = a, b = a and b and b >= a and b or nil })
        end
        fields = row {
            spacing = 12,
            children = {
                field("dp_input", "Start", typed, bad_date, sync, 150),
                field("dp_input_end", "End", typed_end, function(t)
                    local a, b = parse(typed:get()), parse(t)
                    return bad_date(t) or (a and b and b < a and "Before start") or nil
                end, sync, 150),
            },
        }
    else
        fields = field("dp_input", "Date", typed, bad_date, function(t)
            local n = parse(t)
            if n then
                draft:set({ a = n })
            end
        end)
    end
    local input_col = column { width = "fill", padding = { left = 12, right = 12, top = 16, bottom = 12 }, children = { fields } }
    local toggle = icon_button("dp_mode", {
        kind = "plain",
        icon = typing:map(function(on) return on and "calendar_today" or "edit" end),
        on_click = function()
            local t = draft:get() or {}
            if typing:get() then
                if t.a then
                    view:set({ y = t.a // 10000, m = t.a // 100 % 100, dir = 1 })
                end
            else
                typed:set(slashed(t.a))
                typed_end:set(slashed(t.b))
            end
            typing:set(not typing:get())
        end,
        props = { align_v = "center" },
    })
    return modal(id, 7 * CELL_W + 24, { left = 12, right = 12, bottom = 12 }, {
        column {
            width = "fill",
            height = 120,
            padding = { left = 12, right = 12, top = 16 },
            spacing = 36,
            children = {
                text(computed({ ranged, typing }, function(r, on) return r and "Select dates" or on and "Enter date" or "Select date" end), c.on_surface_variant, "label_large"),
                row {
                    width = "fill",
                    align_v = "center",
                    children = {
                        text(computed({ draft, ranged }, function(t, r) return describe(t, r and "Start – End" or "Pick a day", r) end), c.on_surface_variant, "headline_large", { width = "fill", font_size = ranged:map(function(r) return theme.type[r and "title_large" or "headline_large"][1] end) }),
                        toggle,
                    },
                },
            },
        },
        rect { width = "fill", height = 1, background = c.outline_variant },
        rect { width = 7 * CELL_W, children = typing:map(function(on) return { on and input_col or calendar_col } end) },
        actions(id, "dp", commit, computed({ typing, typed, typed_end }, function(on, a, b)
            local sa, sb = parse(a), parse(b)
            return o.range and on and not (sa and sb and sb >= sa)
        end)),
    })
end
overlay.layer("date", function() return date_layer("date") end)
overlay.layer("date_docked", function() return date_layer("date_docked") end)

---@class m3.DateRange
---@field a? integer A day as yyyymmdd.
---@field b? integer The range's end.

-- Opens the calendar, modal or docked under `anchor`.
---@class m3.OpenDatePickerOpts
---@field value? StateSignal<m3.DateRange> Default shared.
---@field range? boolean Pick two days.
---@field input? boolean Modal: start in input mode, a text field with a mm/dd/yyyy mask (`range`: Start and End fields, the end a real day on or after the start; OK waits for both). The header's icon toggles it.
---@field docked? boolean A calendar under `anchor` instead of a modal.
---@field anchor? Signal<Rect> A `geometry(name)` signal; with `docked`.
---@field on_change? fun(t: m3.DateRange) After OK.
---@field window? string The window or panel it opens over; default `m3.core.window`.
---@field [string] "no such property"

---@param opts? m3.OpenDatePickerOpts
function M.open_date_picker(opts)
    opts = opts or {}
    date_spec = merge({ value = date_default }, opts)
    local t = date_spec.value:get() or {}
    local y, m, d = today()
    local focus = t.a or (y * 10000 + m * 100 + d)
    draft:set(t)
    ranged:set(opts.range == true)
    typing:set(opts.input == true and not opts.docked)
    typed:set(slashed(t.a))
    typed_end:set(slashed(t.b))
    view:set({ y = focus // 10000, m = focus // 100 % 100, dir = 1 })
    overlay.open(opts.docked and "date_docked" or "date", nil, opts.window)
end

-- A day as the shared `{ year, month, day }`, and as the picker's yyyymmdd range.
---@class m3.Date
---@field year integer
---@field month integer 1..12
---@field day integer

local function range_of(date)
    return date and date.year and { a = date.year * 10000 + date.month * 100 + date.day } or {}
end

-- The docked picker's field. A single day takes and gives `m3.Date`, as `glass.date_picker` does; with
-- `range` the value stays the native `m3.DateRange`.
---@class m3.DatePickerOpts
---@field label? string|Signal<string>
---@field name? string Accessible name; default the label.
---@field value? StateSignal<m3.Date|false>|StateSignal<m3.DateRange> Default own, empty. With `range`, an `m3.DateRange`.
---@field range? boolean Pick two days; `value` and `on_change` then use `m3.DateRange`.
---@field kind? "outlined"|"filled"
---@field container? string|Signal<string> Colour behind an outlined field.
---@field width? number Default 280.
---@field disabled? boolean|Signal<boolean>
---@field window? string The window or panel the picker opens over; default `core.window`.
---@field on_change? fun(value: m3.Date|m3.DateRange) After OK.
---@field [string] "no such property"

---@param id string
---@param opts? m3.DatePickerOpts
---@return Node
function M.date_picker(id, opts)
    opts = opts or {}
    local range = opts.range
    local value = opts.value or state("m3_date_" .. id, range and {} or false)
    local draft = state("m3_date_draft_" .. id, {})
    local anchor = geometry("m3_date_" .. id)
    local function open()
        local picked = value
        local on_change = opts.on_change
        if not range then
            draft:set(range_of(value:get()))
            picked = draft
            on_change = function(t)
                local date = t.a and { year = t.a // 10000, month = t.a // 100 % 100, day = t.a % 100 } or false
                value:set(date)
                if opts.on_change then
                    opts.on_change(date --[[@as any]])
                end
            end
        end
        M.open_date_picker({ docked = true, anchor = anchor, value = picked, range = range, on_change = on_change, window = opts.window })
    end
    return (text_field(id, {
        kind = opts.kind,
        label = opts.label,
        name = opts.name,
        container = opts.container,
        width = opts.width or 280,
        disabled = opts.disabled,
        display = value:map(function(t) return describe(range and t or range_of(t), "") end),
        trailing = "calendar_today",
        geometry = anchor,
        active = overlay.is_open("date_docked"),
        on_click = open,
    }))
end

return M
