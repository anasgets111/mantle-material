-- M3 text field (outlined and filled; also the read-only field the dropdown and pickers use).
-- See docs/inputs.md.
local theme = require("m3.theme")
local core = require("m3.core")
local icon_button = require("m3.actions.icon_button").icon_button

local c, pick, motion = theme.c, theme.pick, theme.motion
local text, icon = core.text, core.icon
local FADE, CLEAR = motion.fade, theme.CLEAR

local M = {}

local LABEL_MOVE = { duration = 200, easing = theme.easing.standard }

-- The right-click Edit menu of an engine textfield: Cut, Copy, Paste and Select All, with Cut and
-- Copy off while nothing is selected. `target` is the field's `focus_target`, `selected` its
-- `has_selection(name)`. Returns the field's `on_click`. Not in the spec: M3 has no context menu.
---@param target FocusHandle
---@param selected Signal<boolean>
---@param window? any
---@return fun(rect: Rect, button: string, pointer: { x: number, y: number })
function M.edit_click(target, selected, window)
    local function act(verb)
        return function()
            target:request()
            target[verb](target)
        end
    end
    return function(r, button, p)
        if button ~= "right" then
            return
        end
        target:request()
        local has = selected:get() == true
        require("m3.selection.menu").open_menu({
            at = { x = r.x + p.x, y = r.y + p.y },
            window = window,
            items = {
                { label = "Cut", icon = "content_cut", shortcut = "Ctrl+X", disabled = not has, on_click = act("cut") },
                { label = "Copy", icon = "content_copy", shortcut = "Ctrl+C", disabled = not has, on_click = act("copy") },
                { label = "Paste", icon = "content_paste", shortcut = "Ctrl+V", on_click = act("paste") },
                { separator = true },
                { label = "Select all", icon = "select_all", shortcut = "Ctrl+A", on_click = act("select_all") },
            },
        })
    end
end

---------------------------------------------------------------------------------------------------
-- Text field: the label rests inside and floats onto the outline (outlined, cutting it with the
-- container colour) or above the text (filled), shrinking to 12px, while focused or filled.

---@class m3.TextFieldHandle
---@field value StateSignal<string>|Signal<string>
---@field focus fun() Takes keyboard focus.
---@field clear? fun() Absent on a read-only field.
---@field set? fun(text: string) Replaces the text; absent on a read-only field.

-- Wrap the call in parentheses to keep only the node, e.g. in a table constructor.
---@class m3.TextFieldOpts
---@field kind? "outlined"|"filled" Default "outlined".
---@field label? string|Signal<string> Floats up while focused or filled.
---@field name? string Accessible name; default the label.
---@field value? StateSignal<string> The text; own if omitted.
---@field container? string|Signal<string> The colour behind an outlined field, which the floating label cuts the outline with.
---@field width? number|"fill" Default "fill".
---@field leading? string Icon name.
---@field trailing? string Icon name.
---@field clear? boolean A clear button while typing.
---@field prefix? string|Signal<string>
---@field suffix? string|Signal<string>
---@field supporting? string Helper text.
---@field validate? fun(text: string): string? An error message, shown in place of the supporting text.
---@field max_length? integer Caps the text; shows an n/max counter.
---@field disabled? boolean|Signal<boolean>
---@field multiline? boolean Wraps and takes newlines; the container grows from `min_lines` to `max_lines`, then the text scrolls.
---@field min_lines? integer Multi-line: the rows the field rests at. Default 1.
---@field max_lines? integer Multi-line: the rows it grows to before scrolling. Default 0, no limit.
---@field submit_key? "ctrl+return"|"return" Multi-line: the chord that calls `on_submit`. Default "ctrl+return"; "return" leaves Shift+Return for the newline.
---@field on_submit? fun(text: string) Enter (multi-line: the submit chord); the field clears.
---@field format? fun(text: string): string Rewrites the text after every edit, e.g. to insert a mask's separators.
---@field on_change? fun(text: string) After every edit, with the formatted text.
---@field autofocus? boolean Takes keyboard focus when it appears.
---@field window? string The window the Edit menu opens in; default the app window.
---@field placeholder? string
---@field display? Signal<string> Read-only mode: the shown text, replacing the input.
---@field on_click? fun() Read-only mode: the click handler.
---@field active? Signal<boolean> Read-only mode: styles the field as focused.
---@field spin? boolean Read-only mode: turn the trailing icon while active.
---@field geometry? Signal<Rect> A `geometry(name)` for the field.
---@field [string] "no such property"

---@param id string
---@param opts m3.TextFieldOpts
---@return Node node
---@return m3.TextFieldHandle handle
function M.text_field(id, opts)
    local name = "m3_tf_" .. id
    local filled = opts.kind == "filled"
    local display = opts.display
    local value = display or opts.value or state(name, "")
    local focus = opts.active or focused(name)
    local target = focus_target(name)
    local multi = opts.multiline and not display
    local over = hover(name .. "_hover")
    local off = type(opts.disabled) == "userdata" and opts.disabled or theme.scheme:map(function() return opts.disabled or false end)
    local dim = off:map(function(d) return d and 0.38 or 1 end)
    local has_trailing = opts.trailing or opts.clear or opts.validate
    local invalid = value:map(function(v)
        if (v or "") == "" then
            return false
        end
        return opts.validate and opts.validate(v) or false
    end)
    local raised = computed({ focus, value }, function(f, v) return f or (v or "") ~= "" end)
    local tint = computed({ focus, invalid, theme.scheme }, function(f, err, s)
        return err and s.error or f and s.primary or s.on_surface_variant
    end)
    local function set(t)
        local cut = opts.max_length and utf8.offset(t, opts.max_length + 1)
        t = cut and t:sub(1, cut - 1) or t
        target:set_text(t)
        value:set(t)
    end
    local function clear() set("") end
    local function take_focus() target:request() end

    local function side(label)
        return text(label, c.on_surface_variant, "body_large", {
            opacity = computed({ raised, off }, function(up, d) return up and (d and 0.38 or 1) or 0 end),
            animate = { opacity = { duration = 150 }, foreground = FADE },
        })
    end
    local input = display and text(value, c.on_surface, "body_large", { width = "fill", hittable = false })
        or textfield {
            width = "fill",
            height = not multi and "fill" or nil,
            font_size = 16,
            letter_spacing = theme.type.body_large[4],
            foreground = c.on_surface,
            placeholder = opts.placeholder,
            placeholder_color = c.on_surface_variant,
            caret = { color = tint },
            selection = { background = c.primary:map(function(p) return theme.alpha(p, 0.3) end) }, -- not in the spec: the selection ink
            on_click = M.edit_click(target, has_selection(name), opts.window),
            multiline = multi,
            min_lines = multi and opts.min_lines or nil,
            max_lines = multi and opts.max_lines or nil,
            submit_key = multi and opts.submit_key or nil,
            on_submit = not display and opts.on_submit or nil,
            initial_text = value,
            disabled = opts.disabled,
            max_length = opts.max_length,
            accessible_name = opts.name or type(opts.label) == "string" and opts.label or nil,
            focus_ring = false,
            focus_target = target,
            autofocus = opts.autofocus,
            on_change = function(t)
                local f = opts.format and opts.format(t) or t
                if f ~= t then
                    target:set_text(f)
                end
                value:set(f)
                if opts.on_change then
                    opts.on_change(f)
                end
            end,
        }
    local parts = { input }
    if opts.prefix then
        table.insert(parts, 1, side(opts.prefix))
    end
    if opts.suffix then
        parts[#parts + 1] = side(opts.suffix)
    end
    local entry = row {
        width = "fill",
        height = not multi and "fill" or nil,
        align_v = multi and "start" or "center",
        margin = multi and { top = filled and 24 or 16, bottom = filled and 8 or 16 } or { top = filled and 16 or 0 },
        opacity = dim,
        children = parts,
    }

    local function shown(fn) return computed({ value, invalid }, fn) end
    local function fade(v) return v and 1 or 0 end
    local trailing = rect {
        width = 48,
        height = 48,
        align_v = multi and "start" or "center",
        opacity = dim,
        children = {
            opts.trailing and icon(opts.trailing, c.on_surface_variant, 24, {
                align_h = "center",
                hittable = false,
                opacity = shown(function(v, err) return fade(not err and not (opts.clear and (v or "") ~= "")) end),
                rotate = opts.spin and focus:map(function(on) return on and 180 or 0 end) or 0,
                animate = { opacity = { duration = 100 }, rotate = LABEL_MOVE, foreground = FADE },
            }) or rect {},
            opts.clear and icon_button("tf_clear_" .. id, {
                kind = "plain",
                icon = "close",
                on_click = clear,
                props = {
                    opacity = shown(function(v, err) return fade(not err and (v or "") ~= "") end),
                    hittable = shown(function(v, err) return not err and (v or "") ~= "" end),
                    animate = { opacity = { duration = 100 } },
                },
            }) or rect {},
            icon("error", c.error, 24, {
                align_h = "center",
                hittable = false,
                opacity = invalid:map(fade),
                animate = { opacity = { duration = 100 }, foreground = FADE },
            }),
        },
    }

    local lead = opts.leading
    local middle = rect {
        width = "fill",
        height = not multi and "fill" or nil,
        children = {
            rect {
                align_v = multi and "start" or "center",
                margin = multi and { top = 16 } or nil,
                padding = { left = 4, right = 4 },
                opacity = dim,
                hittable = false,
                background = filled and CLEAR or computed({ raised, opts.container or c.surface_container }, function(up, bg) return up and bg or CLEAR end),
                translate = raised:map(function(up)
                    return { x = (not filled and up and lead) and -32 or -4, y = up and (filled and -12 or -28) or 0 }
                end),
                scale = raised:map(function(up) return up and 0.75 or 1 end),
                origin = { x = 0, y = 0.5 },
                animate = { translate = LABEL_MOVE, scale = LABEL_MOVE },
                children = { text(opts.label, tint, "body_large") },
            },
            entry,
        },
    }
    local line = computed({ focus, invalid, over, off, theme.scheme }, function(f, err, hov, dis, s)
        if dis then
            return theme.alpha(s.on_surface, 0.38)
        end
        return err and (hov and not f and s.on_error_container or s.error) or f and s.primary or hov and s.on_surface or filled and s.on_surface_variant or s.outline
    end)
    local indicator = filled and rect {
        width = "fill",
        height = focus:map(function(f) return f and 2 or 1 end),
        align_v = "end",
        background = line,
        animate = { height = { duration = 150 }, background = FADE },
    } or nil
    local outline = computed({ off, line, theme.scheme }, function(d, l, s) return d and theme.alpha(s.on_surface, 0.12) or l end)

    local layout = { middle }
    if lead then
        table.insert(layout, 1, rect { width = 48, height = 48, align_v = multi and "start" or "center", opacity = dim, children = { icon(lead, c.on_surface_variant, 24, { align_h = "center" }) } })
    end
    if has_trailing then
        layout[#layout + 1] = trailing
    end
    local counter = opts.max_length and text(value:map(function(v) return (utf8.len(v or "") or 0) .. "/" .. opts.max_length end), c.on_surface_variant, "body_small") or nil
    local node = column {
        width = opts.width or "fill",
        spacing = 4,
        children = {
            rect {
                width = "fill",
                height = not multi and 56 or nil,
                min_height = multi and 56 or nil,
                focused = focus,
                hover = over,
                geometry = opts.geometry,
                hittable = off:map(function(d) return not d end),
                accessible_name = display and (opts.name or type(opts.label) == "string" and opts.label or nil) or nil,
                radius = filled and { top_left = 4, top_right = 4, bottom_right = 0, bottom_left = 0 } or 4,
                background = filled and computed({ off, theme.scheme }, function(d, s) return d and theme.alpha(s.on_surface, 0.04) or s.surface_container_highest end) or CLEAR,
                border_width = filled and 0 or focus:map(function(f) return f and 2 or 1 end),
                border_color = filled and CLEAR or outline,
                animate = { border_color = FADE, border_width = { duration = 150 }, background = FADE },
                on_click = opts.on_click or take_focus,
                children = {
                    row {
                        width = "fill",
                        height = not multi and "fill" or nil,
                        align_v = multi and "start" or "center",
                        padding = { left = lead and 0 or 16, right = has_trailing and 0 or 16 },
                        children = layout,
                    },
                    indicator,
                },
            },
            row {
                width = "fill",
                padding = { left = 16, right = 16 },
                children = {
                    text(invalid:map(function(err) return err or opts.supporting or "" end), pick(invalid, "error", "on_surface_variant"), "body_small", { width = "fill", wrap = "word", opacity = dim }),
                    counter,
                },
            },
        },
    }
    return node, { value = value, focus = take_focus, clear = not display and clear or nil, set = not display and set or nil }
end

return M
