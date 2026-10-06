# Navigation

`m3.tabs`, `m3.tab_content`, `m3.navigation_bar`, `m3.navigation_drawer`, `m3.open_navigation_drawer`,
`m3.navigation_rail`, `m3.top_app_bar`, `m3.top_app_bar_height`, `m3.toolbar`.
Items are selected by `item.name or index`; every `value` is a state holding that key.

## tabs / tab_content

Tabs with an indicator that springs to the selected tab's rect; `tab_content` slides the selected page in from the tab's side.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `items` | `{ name?, label, icon?, content? }[]` | required | Tabs; with any `content`, the selected tab's page shows under the bar |
| `on_change` | `fun(key)` | none | After a tab is picked |
| `name` | string | none | Accessible name |
| `value` | state | required | Selected tab index (shared by both) |
| `kind` | `"primary"\|"secondary"` | `"primary"` | 3px indicator under the content, or 2px across the tab |
| `pages` | node[] | required | `tab_content`: one page per tab |
| `height` | number | content | `tab_content` height |

```lua
local tab = state("m3_tab", 1)
column { children = {
    m3.tabs("trips", { items = { { label = "Flights", icon = "flight" }, { label = "Trips", icon = "luggage" } }, value = tab }),
    m3.tab_content("trips", { value = tab, pages = { flights, trips }, height = 200 }),
} }
```

## navigation_bar

Three to five destinations along the bottom; the pill springs open and the active icon fills.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `items` | `{ label, icon, badge? }[]` | required | Destinations |
| `value` | state | required | Selected index |
| `labels` | boolean | `true` | `false` is icons only (64px tall; 80px with labels) |

```lua
m3.navigation_bar("main", { items = { { label = "Home", icon = "home" }, { label = "Chat", icon = "chat", badge = 3 } }, value = page })
```

## navigation_drawer / open_navigation_drawer

Pill items with section headers and dividers. In a frame it slides over a scrim; `open_navigation_drawer` does the same over the whole window (needs `m3.app_window`).

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `items` | list | required | `{ label, icon, count? }`, `{ header = "Mail" }`, `{ separator = true }` |
| `value` | state | required | Selected item's `name` or position |
| `on_select` | function(key) | none | Called after a selection |
| `kind` | `"modal"\|"standard"` | `"modal"` | `"standard"` is the plain sheet, no scrim |
| `open` | boolean state | own state | Modal only: whether it is shown |

```lua
local open = state("m3_drawer", false)
frame_children = { m3.navigation_drawer("mail", { items = items, value = sel, open = open }) }
m3.open_navigation_drawer({ items = items, value = sel })   -- over the window
```

## navigation_rail

Side rail of three to seven destinations: optional menu button and FAB, then the destinations. Collapsed (96px) a pill with a label each; expanded (220px) horizontal pill items and an extended FAB, the width on a spring.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `destinations` | `{ name, icon, label?, badge? }[]` | required | `name` is the key and the default label |
| `value` | state | required | Selected `name` |
| `fab` | `{ icon, label, on_click }` | none | FAB slot |
| `expanded` | boolean state | `false` | Expanded variant |
| `menu` | boolean | `false` | Menu button that toggles `expanded` (must be a state) |
| `modal` | boolean | `false` | Scrim beside the expanded rail; pressing it collapses |

```lua
m3.navigation_rail("app", { destinations = { { name = "Home", icon = "home" }, { name = "Mail", icon = "mail" } }, value = page })
```

## top_app_bar

64px bar; medium (112) and large (120) start with a headline that fades into the title row as `scroll` grows and collapse to 64px; the bar takes surface container once content passes under it. Pad the scrolling content by `m3.top_app_bar_height(kind)` and give it `animate = { scroll = 160 }`, so wheel notches ease and the collapse follows frame by frame.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `kind` | `"small"\|"center"\|"medium"\|"large"` | `"small"` | Variant |
| `title` | string or signal | none | Title |
| `navigation_icon`, `on_navigation` | symbol name, function | none | Leading button |
| `actions` | `{ icon, on_click, label?, geometry? }[]` | none | Trailing icon buttons (`geometry` anchors a menu) |
| `scroll` | scroll signal | none | The content's scroll; collapses and tints the bar |

```lua
local offset = scroll("m3_inbox")
column { scroll = offset, animate = { scroll = 160 }, padding = { top = m3.top_app_bar_height("large") }, children = rows }
m3.top_app_bar("inbox", { kind = "large", title = "Inbox", navigation_icon = "menu", scroll = offset })
```

## toolbar

Expressive toolbar of icon actions with an optional FAB. Place it at the bottom of a frame.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `kind` | `"docked"\|"floating"` | `"docked"` | Full-width bar, or a pill that slides away on a scroll down and back on a scroll up |
| `actions` | `{ icon, on_click, label? }[]` | none | Icon buttons |
| `fab` | `{ icon, label, on_click }` | none | Trailing FAB |
| `scroll` | scroll signal | none | Floating only: drives the hide |

```lua
m3.toolbar("edit", { kind = "floating", actions = { { icon = "edit" }, { icon = "share" } }, fab = { icon = "add", label = "Add" }, scroll = offset })
```
