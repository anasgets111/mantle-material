# Communication

`m3.badge`, `m3.linear_progress`, `m3.circular_progress`, `m3.loading_indicator`, `m3.shape`,
`m3.tooltip`, `m3.rich_tooltip`. Snackbars are `m3.overlay.notify(message, opts)`. Shape
geometry is `m3.shapes` (`NAMES`, `commands(name, size)`).

## badge

A 6px dot, or a 16px pill showing a count ("999+" past 999, hidden at 0); each new count springs in.
Position it yourself on its host's corner.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `count` | number or signal | none | Omit for the dot |

```lua
m3.badge("inbox_badge", { count = unread })
```

## badged

`child` with a badge on its top-end corner, placed as M3 specifies (Material Components' `Widget.Material3.Badge`): a 6px dot whose top meets the icon box's top and whose end meets its end; a 16px count pill 4px above the icon box with its start edge at the box's centre. The badge is laid out, not translated, so no clipping ancestor cuts it. Prefer it to placing `badge` yourself.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `child` | node | required | What the badge sits on, usually a 24px `m3.icon` |
| `count` | number or signal | none | Without it, a 6px dot; with it, a count pill (999+ above 999), hidden at 0 |
| `size` | number | `24` | The icon box the badge is placed against |
| `box_top` | number | `size * 0.1` | Where that box starts inside `child` (an `m3.icon`'s line box puts its glyph box 10% down) |

```lua
m3.badged("inbox", { child = m3.icon("mail", m3.theme.c.on_surface_variant, 24), count = unread })
```

## linear_progress / circular_progress

Determinate or indeterminate, flat or wavy, after Compose's M3 values. Linear is 4px tall (10px wavy: 40px wavelength, 3px amplitude); circular sits in a 48px box (a 40px ring, or a wavy one with 1.6px amplitude and nine waves). Track gap and stop dot are 4px. A wave flattens at or below 10% and from 95%, crossfading over 500 ms. Indeterminate linear runs two lines on 1750 ms head and tail curves; circular grows its arc from 10% to 87% while it turns.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `value` | 0..1 number or signal | 0 | Progress |
| `indeterminate` | boolean | `false` | Ignores `value` |
| `wavy` | boolean | `false` | Wavy active indicator |
| `width` | number | 240 | Linear only |

```lua
m3.linear_progress("upload", { value = progress, wavy = true, width = 280 })
m3.circular_progress("spin", { indeterminate = true })
```

## loading_indicator

Expressive 38px shape that morphs to the next of seven every 650 ms on a spring, turning 90 degrees per morph and once per 4.666 s.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `contained` | boolean | `false` | Sits on a 48px primary container circle |

```lua
m3.loading_indicator("busy", { contained = true })
```

## shape

One Expressive shape that morphs on a spring when `name` changes.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `name` | string or signal | `"circle"` | One of `m3.shapes.NAMES` |
| `size` | number | 48 | Box size |
| `color` | signal | `c.primary` | Fill |
| `props` | table | none | Extra node props |

```lua
m3.shape("blob", { name = hovered:map(function(h) return h and "sunny" or "cookie_9" end) })
```

## tooltip / rich_tooltip

Wrap a control; the tip shows above it, 4px clear. Plain (24px min height, 8px sides, 4px radius, inverse surface) after 500 ms of hover; rich (320px, 16px sides, 12px radius, surface container at elevation 2, title small, body medium) after 300 ms and stays while the pointer is over it. The tip flips below the control when the window has no room above, and slides to stay inside it.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `child` | node | required | The control |
| `label` | string | required | Plain: the text |
| `title`, `body` | string | required | Rich: heading and supporting text |
| `action`, `on_action` | string, function | none | Rich: the action button |
| `width`, `height` | number | 40 | The control's size |
| `window` | string | `m3.core.window` | The window or panel it shows over |

```lua
m3.tooltip("edit_tip", { label = "Edit", child = m3.icon_button("edit", { icon = "edit" }) })
```
