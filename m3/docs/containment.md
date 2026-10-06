# Containment

Cards, lists, the carousel, dividers and the modal layers. Every call is `m3.<name>(id, opts)`; `id` is unique per instance.
Layer openers are `m3.open_<thing>(opts)`; Escape and `m3.overlay.close_all()` close them. Needs `m3.app_window`. Every opener takes `window`, the host's id (default `m3.core.window`, else the first `app_window`).

| Component | What it is |
| :--- | :--- |
| `m3.card` | Elevated, filled or outlined container with media, text and actions; hover lifts it |
| `m3.list_item` | 1-3 line row with a leading icon, avatar or image and a trailing text, checkbox or switch |
| `m3.list` | Scrolling keyed list of rows |
| `m3.carousel` | Multi-browse image carousel that reflows continuously as the wheel scrolls it |
| `m3.divider` | 1px rule, full, inset or middle-inset, horizontal or vertical |
| `m3.open_bottom_sheet` | Modal bottom sheet; drag the handle down to dismiss |
| `m3.open_side_sheet` | Modal side sheet with cancel and confirm |
| `m3.open_fullscreen_dialog` | Full-window dialog closed by its own action |

## card

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `kind` | `"elevated"\|"filled"\|"outlined"` | `"elevated"` | Variant |
| `media` | image path | none | Image across the top |
| `media_height` | number | `160` | Image height |
| `headline`, `subhead`, `supporting` | string or signal | none | Text lines |
| `actions` | node[] | none | Buttons, right-aligned under the text |
| `on_click` | function | none | Press handler |
| `props` | table | none | Extra node props |

```lua
m3.card("trip", { kind = "filled", media = "/path/photo.jpg", headline = "Cabin", supporting = "Winter retreat",
    actions = { m3.button("trip_save", { kind = "text", label = "Save" }) } })
```

## list_item

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `lines` | 1-3 strings or signals | required | Row height follows the count (56, 72, 88) |
| `leading` | `{ icon }`, `{ avatar }`, `{ image }` or `{ node }` | none | Icon name, avatar letter, image path or any node |
| `trailing` | `{ text }`, `{ checkbox }`, `{ switch }` or `{ node }` | none | `checkbox` / `switch` take `true` or your own state signal |
| `on_click` | function | none | Press handler |
| `animated` | boolean | `false` | Move, fade in and exit animation for rows of a `list` |

```lua
m3.list_item("mail", { lines = { "Ada", "Engine notes" }, leading = { avatar = "A" }, trailing = { switch = true } })
```

## list

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `source` | list signal | required | Entries |
| `key` | `fn(entry) -> string` | required | Stable identity for move and exit |
| `item` | `fn(entry) -> node` | required | Usually a `list_item` with `animated = true` |
| `height`, `width` | number or `"fill"` | none, `"fill"` | Size; scrolls inside |

## carousel

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `items` | `{ image, label? }[]` | required | Slides |
| `height` | number | `221` | Row height |
| `controls` | boolean | `true` | Previous / next buttons under the strip; `false` hides them |

The wheel scrolls it smoothly; large, medium and small items follow the live offset. Clicking an item brings it to the front; the buttons step one item, and repeated clicks add up.

```lua
m3.carousel("gallery", { items = { { image = "/a.jpg", label = "A" }, { image = "/b.jpg" } } })
```

## divider

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `kind` | `"full"\|"inset"\|"middle"` | `"full"` | Inset leaves 16px at the start, middle at both ends |
| `vertical` | boolean | `false` | Vertical rule filling its row |

## Layers

| Opener | Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- | :--- |
| `open_bottom_sheet` | `title` | string | none | Heading |
| | `items` | `{ icon, label, on_click }[]` | none | Rows that close the sheet, then run |
| | `content` | nodes or fn returning nodes | none | Extra body |
| `open_side_sheet` | `title`, `content` | as above | none | Heading and body |
| | `confirm`, `cancel` | string | `"Save"`, `"Cancel"` | Button labels |
| | `on_confirm` | function | none | Runs after the sheet closes |
| `open_fullscreen_dialog` | `title`, `content`, `confirm`, `on_confirm` | as above | | Content is centred under the top bar |

```lua
m3.open_bottom_sheet { title = "Share", items = { { icon = "link", label = "Copy link", on_click = copy } } }
m3.open_side_sheet { title = "Settings", content = function() return { m3.text("Hi", m3.theme.c.on_surface) } end }
```

## Basic dialog: `m3.overlay.ask`

`m3.overlay.ask({ icon?, title, body?, actions?, window? })` shows a basic dialog over a 32% scrim; the scrim or Escape dismisses it.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `title` | string | required | Headline |
| `icon` | string | none | Material Symbols name; centres the title |
| `body` | string or node | none | Supporting text, or any node; scrolls when taller than the window allows |
| `actions` | `{ label, kind?, on_click? }[]` | Cancel | Buttons at the end of the row. `kind` is `"text"` (default), `"tonal"` or `"filled"`; each closes the dialog, then runs `on_click` |
| `confirm` | string | none | Shorthand: adds a trailing action that runs `ask`'s second argument |

```lua
m3.overlay.ask({ icon = "delete", title = "Delete draft?", body = "It can't be restored.", actions = {
    { label = "Keep" }, { label = "Delete", kind = "filled", on_click = delete },
} })
```
