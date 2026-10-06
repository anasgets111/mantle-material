# Actions

`m3.button`, `m3.icon_button`, `m3.fab`, `m3.extended_fab`, `m3.fab_menu`, `m3.button_group`,
`m3.split_button`, `m3.segmented_control`. Buttons spring their corners smaller while pressed.

## button

Common button: seven kinds (`tinted` looks as `secondary`), five Expressive sizes, optional toggle.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `kind` | `"primary"\|"secondary"\|"plain"\|"destructive"\|"tinted"\|"elevated"\|"outlined"` | `"primary"` | Emphasis; `destructive` is `error` / `on_error` |
| `size` | `"xs"\|"s"\|"m"\|"l"\|"xl"` | `"s"` | Height 32 / 40 / 56 / 96 / 136 |
| `shape` | `"round"\|"square"\|"toggle"` | `"round"` | `"toggle"` squares while selected; implied by `value` |
| `label`, `icon` | string or signal | none | Content; `icon` is a shared icon name or a Material Symbols name |
| `name` | string | none | Accessible name |
| `value` | boolean state | none | Makes it a toggle; a click flips it |
| `width` | number | content | Fixed width, content centred |
| `props`, `icon_props` | table | none | Extra node props for the container / icon |
| `on_click` | function | none | Called after the toggle flips |

```lua
local on = state("m3_fav", false)
m3.button("fav", { kind = "secondary", label = "Favourite", icon = "favorite", value = on })
```

## icon_button

One glyph in a square container; a toggle fills its glyph.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `kind` | `"plain"\|"primary"\|"secondary"\|"outlined"` | `"plain"` | Emphasis |
| `size`, `shape`, `value`, `props`, `on_click`, `name` | as `button` | | |
| `icon` | string | required | Symbol name |

```lua
m3.icon_button("share", { kind = "secondary", icon = "share", on_click = share })
```

## fab / extended_fab

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `size` | `"small"\|"fab"\|"large"` | `"fab"` | `fab` only |
| `tone` | `"primary"\|"secondary"\|"tertiary"\|"surface"` | `"primary"` | Container colour |
| `icon`, `label` | string | required | `label` is `extended_fab` only |
| `expanded` | boolean signal | `true` | `extended_fab`: collapses to a FAB when false |
| `props`, `on_click` | | | |

```lua
m3.extended_fab("compose", { icon = "edit", label = "Compose", expanded = expanded })
```

## fab_menu

A toggle FAB that opens a stack of labelled actions, springing in nearest the FAB first. Place it
in a box tall enough for the opened items.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `items` | `{ icon, label, on_click }[]` | required | Menu actions; choosing one closes the menu |
| `value` | boolean state | own state | Open |

```lua
m3.fab_menu("add", { items = { { icon = "mic", label = "Voice", on_click = record } } })
```

## button_group

Related buttons in a row.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `kind` | `"standard"\|"connected"` | `"standard"` | Standard: neighbours of a pressed button squish. Connected: one selection, inner corners small |
| `button_kind` | button `kind` | `"secondary"` | Style of the buttons |
| `items` | `{ label, icon?, on_click? }[]` | required | The buttons |
| `value` | integer state | own state (1) | Connected: selected index |

```lua
m3.button_group("range", { kind = "connected", items = { { label = "Day" }, { label = "Week" } }, value = idx })
```

## split_button

A leading action plus a chevron that opens an overlay menu under the whole button (right-aligned to it) and turns over while the menu shows. Needs `m3.app_window`.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `kind` | button `kind` | `"primary"` | Style |
| `label`, `icon`, `on_click` | | | The leading action |
| `items` | menu items | required | As for `open_menu`: `{ label, icon, on_click }` |
| `width` | number | 224 | Menu width |

```lua
m3.split_button("send", { label = "Send", icon = "send", on_click = send, items = { { label = "Schedule", icon = "schedule_send" } } })
```

## segmented_control

One outlined control of two to five segments; the selected one is tinted and checked.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `items` | `(string \| { label?, icon?, value? })[]` | required | Segments; the key is `value`, else the label, else the icon |
| `multiple` | boolean | `false` | Several segments can be on; `value` is then a set `{ [key] = true }` |
| `value` | state | own state | Selected key, or the set |
| `on_change` | `fun(value)` | none | After a pick, with the new `value` |
| `name` | string | none | Accessible name |
| `width` | number | content | Per-segment width |

```lua
m3.segmented_control("view", { items = { "Day", "Week", "Month" }, value = view, width = 96 })
```
