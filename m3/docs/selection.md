# Selection

`local m3 = require("m3")`. Every component is `m3.<name>(id, opts)`; `id` is unique per instance. A `value` is a `state(...)` signal the component reads and writes; omit it and the component keeps its own. `disabled` and `error` take a boolean or a signal.

| Component | What it is |
| :--- | :--- |
| `checkbox` | One box: unchecked, checked or indeterminate; the tick and dash are round-capped strokes that draw out with `trim_end` |
| `checkbox_group` | A parent checkbox over a list of children |
| `radio_group` | One choice from a list; the dot grows on a spring |
| `switch` | 52x32 toggle with optional icons; with a detail line, a settings row |
| `chip` | Assist, filter, input or suggestion chip |
| `input_chips` / `suggestion_chips` | A removable list of chips and the options not yet picked |
| `slider` | Continuous, discrete, range or centered, with a value bubble |
| `open_menu` / `menu_open` | An M3 menu layer under an anchor |
| `dropdown` | Exposed dropdown: a read-only field that opens a menu |
| `date_picker` / `open_date_picker` | Date field with a docked calendar; modal or docked picker |
| `time_picker` / `open_time_picker` | Time field; modal dial |

## checkbox

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `value` | state `true`, `false` or `"indeterminate"` | own, `false` | Checked state; a click sets `true`, or `false` when it was `true` |
| `label` | string | none | Text beside the box |
| `error` / `disabled` | boolean or signal | `false` | Error colours; dimmed and inert |
| `on_change` | `fun(value)` | none | After a click |

```lua
local agree = state("agree", false)
m3.checkbox("agree", { value = agree, label = "I agree", error = agree:map(function(v) return not v end) })
```

## checkbox_group

`m3.checkbox_group(id, { label, items, value, error, disabled, on_change })`. `items` is a list of labels; `value` is a state holding a set `{ [label] = true }` (default: the first item). The parent is checked when all are, indeterminate when some are; clicking it checks or clears all. `on_change(set)`.

## radio_group

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `options` | string list | required | Labels |
| `value` | state of the chosen label | own, first option | Selection |
| `disabled` | boolean or signal | `false` | Inert |
| `on_change` | `fun(label)` | none | After a pick |

```lua
m3.radio_group("plan", { options = { "Monthly", "Yearly" }, value = plan })
```

## switch

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `value` | state boolean | own, `false` | On or off |
| `icons` | boolean | `false` | Check on the thumb when on, close when off |
| `disabled` | boolean or signal | `false` | Inert |
| `label`, `detail` | string | none | Both set: returns a row, label over detail, the switch trailing |
| `on_change` | `fun(on)` | none | After a toggle |

```lua
m3.switch("wifi", { value = wifi, label = "Wi-Fi", detail = "Connected to Home" })
```

## chip

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `kind` | `"assist"`, `"filter"`, `"input"`, `"suggestion"` | `"assist"` | Variant |
| `label` | string | required | Text |
| `icon` | string | none | Leading icon (assist) |
| `elevated` | boolean | `false` | Elevated look (assist, suggestion) |
| `value` | state boolean | own | Selected (filter) |
| `avatar` | string | first letter | Avatar text (input) |
| `on_click` / `on_change(on)` / `on_remove` | callbacks | none | Assist and suggestion / filter / input |
| `appear` | boolean | `false` | Fade in and move when listed |

```lua
m3.chip("rated", { kind = "filter", label = "Top rated", value = rated })
```

`m3.input_chips(id, { value })` is a horizontal list of removable input chips over `value`, a state list of labels. `m3.suggestion_chips(id, { options, value })` lists the `options` not in `value` (the same state); picking one appends it.

## slider

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `kind` | `"continuous"`, `"discrete"`, `"range"`, `"centered"` | `"continuous"` | Variant |
| `value` | state 0..1 | own, `0.5` | The value; the high thumb of a range |
| `low` | state 0..1 | own, `0.25` | The low thumb (range) |
| `size` | `"xs"`, `"s"`, `"m"`, `"l"`, `"xl"` | `"xs"` | Track height 16, 24, 40, 56, 96; handle 44, 44, 44, 68, 108 |
| `steps` | number | `5` | Divisions and ticks (discrete) |
| `width` | number | `300` | Px |
| `format` | `fun(v): string` | percent | Bubble text |

```lua
m3.slider("volume", { value = volume, width = 340 })
```

The mouse wheel nudges a single thumb.

## open_menu, menu_open

`m3.open_menu(opts)` shows the menu layer; Escape, a click outside or an item closes it.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `anchor` | `geometry(name)` signal | required | The menu opens just under it |
| `items` | list | required | `{ label, icon?, selected? (signal: check and tint), on_click? }` or `{ divider = true }` |
| `width` | number or `"anchor"` | `224` | Px, or the anchor's width |
| `align` | `"start"`, `"end"` | `"start"` | Which edge of the anchor it lines up with (`"end"` needs a px width) |
| `id` | string | `""` | Names the opener |

`m3.menu_open(id)` is a signal, true while the menu opened with that `id` shows.

```lua
local more = geometry("more")
m3.icon_button("more", { icon = "more_vert", props = { geometry = more }, on_click = function()
    m3.open_menu({ anchor = more, align = "end", items = { { label = "About", icon = "info", on_click = about } } })
end })
```

## dropdown

`m3.dropdown(id, { label, options, value, kind, container, width, on_change })`: `options` strings, `value` a state of the chosen one (default: the first), `kind` `"outlined"` or `"filled"`, `container` the colour behind an outlined field, `width` default `280`. Returns the field.

```lua
m3.dropdown("sort", { kind = "filled", label = "Sort by", options = { "Relevance", "Newest" }, value = sort })
```

## date_picker, open_date_picker

`m3.date_picker(id, { label, value, range, kind, container, width, on_change })` is the field; it opens a docked calendar under itself. `m3.open_date_picker(opts)` opens one directly.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `value` | state `{ a, b }` | shared | Days as `yyyymmdd`; `b` ends a range |
| `range` | boolean | `false` | Pick two days |
| `docked` | boolean | `false` | Calendar under `anchor` (a `geometry(name)` signal) instead of a modal |
| `on_change` | `fun(t)` | none | After OK |

```lua
m3.button("pick", { label = "Pick a range", on_click = function() m3.open_date_picker({ range = true, value = trip }) end })
```

## time_picker, open_time_picker

`m3.time_picker(id, { label, value, kind, container, width, on_change })` is the field; it opens the dial. `m3.open_time_picker({ value, on_change })` opens it directly. `value` is a state `{ h = 1..12, m = 0..59, pm = boolean }`; the dial picks the hour, then the minutes.

```lua
m3.time_picker("alarm", { label = "Alarm", value = alarm })
```

