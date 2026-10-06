-- M3 search: search_field (inline), and search_bar (a bar that opens a search view; open_search_view).
-- See docs/inputs.md.
local theme = require("m3.theme")
local core = require("m3.core")
local overlay = require("m3.overlay")
local sel = require("m3.internal.selection")
local icon_button = require("m3.actions.icon_button").icon_button
local edit_click = require("m3.inputs.text_field").edit_click

local c, pick, motion = theme.c, theme.pick, theme.motion
local text, icon, interactive = core.text, core.icon, core.interactive
local FADE = motion.fade

local M = {}

-- The caret, the selection ink and the right-click Edit menu of a search field.
local function field_props(name, target)
    return {
        caret = { color = c.primary },
        selection = { background = c.primary:map(function(p) return theme.alpha(p, 0.3) end) }, -- not in the spec: the selection ink
        focus_target = target,
        on_click = edit_click(target, has_selection(name)),
    }
end

---------------------------------------------------------------------------------------------------
-- Search view: grows out of the bar's own rect (height 56 to 281) with the field, and suggestions
-- filtered as you type.

local query = state("m3_search_query", "")
---@type table
local search_spec = {}
local VIEW_H = 57 + 4 * 56

local function suggestion(person)
    local o = search_spec
    return interactive("sug_" .. person, {
        width = "fill",
        height = 56,
        accessible_name = person,
        opacity = 1,
        animate = { move = { duration = 300, easing = theme.easing.emphasized_decelerate }, opacity = { duration = 150, from = 0 }, exit = { duration = 100, opacity = 0 } },
        on_click = function()
            o.value:set(person)
            overlay.close("search")
            if o.on_select then
                o.on_select(person)
            end
        end,
    }, c.on_surface, row {
        width = "fill",
        height = "fill",
        align_v = "center",
        spacing = 16,
        padding = { left = 16, right = 16 },
        children = {
            icon("history", c.on_surface_variant, 24),
            text(person, c.on_surface, "body_large", { width = "fill" }),
            icon("north_west", c.on_surface_variant, 24),
        },
    })
end

overlay.layer("search", function()
    local o = search_spec
    local target = focus_target("m3_search_view")
    local anchor = o.anchor
    return rect {
        id = "search",
        width = "fill",
        height = "fill",
        cursor = "default",
        focus_ring = false,
        on_click = function() overlay.close("search") end,
        animate = { exit = { duration = 200, opacity = 0 } },
        children = {
            core.merge(column {
                -- Grows out of its bar when given one, else sits centred near the top.
                width = anchor and anchor:map(function(r) return r and r.width or 0 end) or 720,
                height = VIEW_H,
                radius = 28,
                clip = "rounded",
                align_h = anchor and "start" or "center",
                background = c.surface_container_high,
                margin = anchor and anchor:map(function(r) return r and { left = r.x, top = r.y } or {} end) or { top = 72 },
                on_click = function() end,
                cursor = "default",
                focus_ring = false,
                animate = { height = { duration = 400, easing = theme.easing.emphasized_decelerate, from = 56 } },
                children = {
                    row {
                        width = "fill",
                        height = 56,
                        align_v = "center",
                        spacing = 4,
                        padding = { left = 4, right = 4 },
                        children = {
                            icon_button("search_back", { kind = "plain", icon = "arrow_back", on_click = function() overlay.close("search") end, props = { align_v = "center" } }),
                            textfield(core.merge({
                                width = "fill",
                                height = "fill",
                                font_size = 16,
                                letter_spacing = theme.type.body_large[4],
                                foreground = c.on_surface,
                                placeholder = o.placeholder,
                                placeholder_color = c.on_surface_variant,
                                max_length = o.max_length,
                                accessible_name = o.placeholder,
                                autofocus = true,
                                focus_ring = false,
                                on_change = function(t) query:set(t) end,
                                on_submit = function(t)
                                    o.value:set(t)
                                    overlay.close("search")
                                    if o.on_select then
                                        o.on_select(t)
                                    end
                                end,
                            }, field_props("m3_search_view", target))),
                            icon_button("search_clear", {
                                kind = "plain",
                                icon = "close",
                                on_click = function()
                                    target:set_text("")
                                    query:set("")
                                end,
                                props = {
                                    align_v = "center",
                                    opacity = query:map(function(q) return q ~= "" and 1 or 0 end),
                                    hittable = query:map(function(q) return q ~= "" end),
                                    animate = { opacity = { duration = 100 } },
                                },
                            }),
                        },
                    },
                    rect { width = "fill", height = 1, background = c.outline },
                    list {
                        width = "fill",
                        height = "fill",
                        limit = 4,
                        source = query:map(function(q)
                            local hits = {}
                            for _, person in ipairs(o.options) do
                                if person:lower():find((q or ""):lower(), 1, true) then
                                    hits[#hits + 1] = person
                                end
                            end
                            return hits
                        end),
                        key = function(person) return person end,
                        itemfn = suggestion,
                    },
                },
            }, theme.elevation[3]),
        },
    }
end)

-- Opens the search view layer.
---@class m3.SearchViewOpts
---@field anchor? Signal<Rect> The bar's `geometry(name)` signal; the view grows out of it.
---@field options string[] Suggestions, filtered by the query.
---@field value StateSignal<string> The last pick.
---@field placeholder? string
---@field max_length? integer
---@field on_select? fun(text: string)
---@field window? string The window or panel it opens over; default `m3.core.window`.
---@field [string] "no such property"

---@param opts m3.SearchViewOpts
function M.open_search_view(opts)
    search_spec = opts
    query:set("")
    overlay.open("search", nil, opts.window)
end

-- An inline editable search pill.
---@class m3.SearchFieldOpts
---@field placeholder? string Default "Search".
---@field name? string Accessible name; default the placeholder.
---@field label? string|Signal<string> Text above the pill.
---@field value? StateSignal<string> The query; default its own.
---@field width? number|"fill" Default "fill".
---@field disabled? boolean|Signal<boolean> Dimmed to 38% and inert.
---@field on_change? fun(text: string) On every edit; Escape sends "".
---@field on_submit? fun(text: string) Enter; the field clears.
---@field max_length? integer Caps the typed query.
---@field [string] "no such property"

---@param id string
---@param opts? m3.SearchFieldOpts
---@return Node node
---@return m3.TextFieldHandle handle
function M.search_field(id, opts)
    opts = opts or {}
    local placeholder = opts.placeholder or "Search"
    local value = opts.value or state("m3_search_field_" .. id, "")
    local target = focus_target("m3_search_in_" .. id)
    local function set(t)
        target:set_text(t)
        value:set(t)
    end
    local pill = core.merge(rect {
        width = opts.width or "fill",
        opacity = sel.disabled_look(opts.disabled),
        hittable = sel.enabled(opts.disabled),
        height = 56,
        radius = 28,
        background = c.surface_container_high,
        animate = { background = FADE },
        children = {
            row {
                width = "fill",
                height = "fill",
                align_v = "center",
                spacing = 16,
                padding = { left = 16, right = 16 },
                children = {
                    icon("search", c.on_surface, 24),
                    textfield(core.merge({
                        width = "fill",
                        height = "fill",
                        font_size = 16,
                        letter_spacing = theme.type.body_large[4],
                        foreground = c.on_surface,
                        placeholder = placeholder,
                        placeholder_color = c.on_surface_variant,
                        max_length = opts.max_length,
                        accessible_name = opts.name or type(opts.label) == "string" and opts.label or placeholder,
                        focus_ring = false,
                        initial_text = value,
                        disabled = opts.disabled,
                        on_submit = opts.on_submit,
                        on_change = function(t)
                            value:set(t)
                            if opts.on_change then
                                opts.on_change(t)
                            end
                        end,
                        on_cancel = function() if opts.on_change then opts.on_change("") end end,
                    }, field_props("m3_search_in_" .. id, target))),
                },
            },
        },
    }, theme.elevation[3])
    local node = pill
    if opts.label then
        node = column { width = opts.width or "fill", spacing = 4, children = { text(opts.label, c.on_surface_variant, "body_small"), pill } }
    end
    return node, { value = value, focus = function() target:request() end, clear = function() set("") end, set = set }
end

-- A pill that opens a search view over `options`.
---@class m3.SearchBarOpts
---@field placeholder? string Default "Search".
---@field name? string Accessible name; default the placeholder.
---@field options? string[] Suggestions.
---@field value? StateSignal<string> The last pick, shown in the bar.
---@field on_select? fun(text: string) A suggestion or Enter.
---@field trailing? string Icon name, default "mic".
---@field max_length? integer Caps the typed query.
---@field [string] "no such property"

---@param id string
---@param opts? m3.SearchBarOpts
---@return Node
function M.search_bar(id, opts)
    opts = opts or {}
    local placeholder = opts.placeholder or "Search"
    local value = opts.value or state("m3_search_" .. id, "")
    local anchor = geometry("m3_search_" .. id)
    local picked = value:map(function(r) return r ~= "" end)
    return interactive("search_" .. id, core.merge({
        width = "fill",
        height = 56,
        radius = 28,
        geometry = anchor,
        background = c.surface_container_high,
        accessible_name = opts.name or placeholder,
        on_click = function()
            M.open_search_view({ anchor = anchor, options = opts.options or {}, value = value, placeholder = placeholder, max_length = opts.max_length, on_select = opts.on_select })
        end,
    }, theme.elevation[3]), c.on_surface, row {
        width = "fill",
        height = "fill",
        align_v = "center",
        spacing = 16,
        padding = { left = 16, right = 16 },
        children = {
            icon("search", c.on_surface, 24),
            text(value:map(function(r) return r ~= "" and r or placeholder end), pick(picked, "on_surface", "on_surface_variant"), "body_large", { width = "fill" }),
            icon(opts.trailing or "mic", c.on_surface_variant, 24),
        },
    })
end

return M
