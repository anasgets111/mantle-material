# Actions

`m3.button`, `m3.icon_button`, `m3.fab`, `m3.extended_fab`, `m3.fab_menu`, `m3.button_group`,
`m3.split_button`, `m3.segmented_button`. Buttons spring their corners smaller while pressed.

## button

Common button: five emphasis levels, five Expressive sizes, optional toggle.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `kind` | `"filled"\|"tonal"\|"elevated"\|"outlined"\|"text"` | `"filled"` | Emphasis |
| `size` | `"xs"\|"s"\|"m"\|"l"\|"xl"` | `"s"` | Height 32 / 40 / 56 / 96 / 136 |
| `shape` | `"round"\|"square"\|"toggle"` | `"round"` | `"toggle"` squares while selected; implied by `value` |
| `label`, `icon` | string or signal | none | Content |
| `value` | boolean state | none | Makes it a toggle; a click flips it |
| `width` | number | content | Fixed width, content centred |
| `props`, `icon_props` | table | none | Extra node props for the container / icon |
| `on_click` | function | none | Called after the toggle flips |

```lua
local on = state("m3_fav", false)
m3.button("fav", { kind = "tonal", label = "Favourite", icon = "favorite", value = on })
```

## icon_button

One glyph in a square container; a toggle fills its glyph.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `kind` | `"standard"\|"filled"\|"tonal"\|"outlined"` | `"standard"` | Emphasis |
| `size`, `shape`, `value`, `props`, `on_click` | as `button` | | |
| `icon` | string | required | Symbol name |

```lua
m3.icon_button("share", { kind = "tonal", icon = "share", on_click = share })
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
| `button_kind` | button `kind` | `"tonal"` | Style of the buttons |
| `items` | `{ label, icon?, on_click? }[]` | required | The buttons |
| `value` | integer state | own state (1) | Connected: selected index |

```lua
m3.button_group("range", { kind = "connected", items = { { label = "Day" }, { label = "Week" } }, value = idx })
```

## split_button

A leading action plus a chevron that opens an overlay menu under the whole button (right-aligned to it) and turns over while the menu shows. Needs `m3.app_window`.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `kind` | button `kind` | `"filled"` | Style |
| `label`, `icon`, `on_click` | | | The leading action |
| `items` | menu items | required | As for `open_menu`: `{ label, icon, on_click }` |
| `width` | number | 224 | Menu width |

```lua
m3.split_button("send", { label = "Send", icon = "send", on_click = send, items = { { label = "Schedule", icon = "schedule_send" } } })
```

## segmented_button

One outlined control of two to five options; the selected one is tinted and checked.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `options` | string[] | required | Segment labels |
| `value` | state | own state | Selected option |
| `width` | number | content | Per-segment width |

```lua
m3.segmented_button("view", { options = { "Day", "Week", "Month" }, value = view, width = 96 })
```
