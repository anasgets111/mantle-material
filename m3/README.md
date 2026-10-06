# m3

The `m3` module of [mantle-material](../README.md): Material 3 (including M3 Expressive) components
for a Mantle config, coloured live from one seed.

## Requirements

Mantle v0.4.0 or later. Fonts: Roboto (M3's typeface; `ttf-roboto` on Arch, or Roboto Flex) and Material Symbols Rounded (icons); any sans works in Roboto's place.

## Setup

Copy (or symlink) `m3/` into your config directory, then:

```lua
fonts { "Roboto", "Noto Sans" }          -- Roboto, M3's typeface; icons use the "Material Symbols Rounded" font
local m3 = require("m3")

m3.theme.seed:set("#6750A4")             -- optional: seed colour (default "system": the desktop's accent), also `m3.theme.appearance`, `variant`, `contrast`

return {
    -- Wires the overlay layers (menus, sheets, pickers, tooltips, dialogs, snackbar) and Escape, and
    -- draws the frame (`decorations = "server"` leaves it to the compositor).
    m3.app_window { id = "app", title = "My app", child = column { children = {
        m3.button("save", { label = "Save", on_click = function() m3.overlay.notify("Saved") end }),
    } } },
}
```

Components that open layers need `m3.app_window` (or `m3.overlay.root(child, id)` as the window
root's `children` with `geometry = m3.overlay.bounds(id)`, `on_escape = function() m3.overlay.escape(id) end` and
`on_key = function(key) return m3.overlay.key(id, key) end`). Every opener (`open_menu`, the pickers, sheets, drawer,
`overlay.notify`, `overlay.ask`, tooltips) takes `window`, the id of the window or panel it opens over; default
`m3.core.window`, else the first `app_window` built. A panel returns `m3.overlay.popup(id)` among its surfaces to host layers.

## Conventions

| Rule | Detail |
| :--- | :--- |
| Install | Copy or symlink `m3/` into the config root; modules are `m3.*`, and the engine follows symlinks |
| Call shape | `m3.<name>(id, opts)`. `id` is a string unique per instance; it names the component's own hover/press state. `opts` is a table, every field optional unless the doc says so |
| Values | A component that holds a value takes `opts.value`, a `state(...)` signal it reads and writes (checked, selected, level, text). Pass your own state to observe or drive it |
| Callbacks | `opts.on_<event>` (`on_click`, `on_change`, `on_close`) |
| Signals | Any display field (`label`, `icon`, `disabled`, ...) takes a plain value or a signal |
| Variants | `opts.kind` picks the M3 variant (`"filled"`, `"outlined"`, `"tonal"`, ...); `opts.size` an Expressive size (`"xs"` ... `"xl"`) |
| Colours | Only `m3.theme.c.<role>` signals; components never take raw colours |
| Layers | Openers are functions: `m3.open_<thing>(opts)`; Escape and `m3.overlay.close_all()` close them; `opts.window` picks the host |

## Theme

`m3.theme.c.<role>` is a live signal of each of the 49 M3 colour roles. `m3.theme.type` / `TYPE_SCALE`
is the 15-style type scale and its `<name>_emphasized` variants (M3 Expressive: same size, heavier weight); `m3.theme.motion` holds the Expressive scheme's six springs (`spatial_fast`, `spatial`, `spatial_slow`, `effects_fast`, `effects`, `effects_slow`), `m3.theme.easing`
the M3 cubic-beziers and `m3.theme.elevation[0..5]` the M3 key + ambient shadow pairs (spread onto a node's props; `m3.theme.shadows[n]` is the bare `shadows` list, for binding). See `theme.lua`.
| Types | Every `opts` has a LuaLS class (`m3.<Name>Opts`); the editor completes and `just types` checks them |

## Components

One file per component family, in a folder per M3 category (below); `require("m3")` loads them all, `require("m3.<folder>.<file>")` one.
`internal/` holds shared helpers and is not public API. Every `opts` field is optional unless marked required. Fields marked
"signal" take a plain value or a signal. Per-category docs with examples are in `docs/`.

### Base (root)

Tokens, building blocks, shapes and the overlay host; every component uses them.

#### core.lua (`m3.core`, `m3.merge`, `m3.text`, `m3.icon`, `m3.interactive`, `m3.focusable`, `m3.scroll_ease`)

| Function | Meaning |
| :--- | :--- |
| `merge(into, from)` | Copies `from`'s fields onto `into`, returns `into` |
| `text(content, color, style?, props?)` | Text node; `style` is a `theme.type` key (default `"body_medium"`); `content` and `color` take signals `style` may also be a `<name>_emphasized` key. |
| `icon(name, color, size?, props?)` | Material Symbols glyph by ligature name (default size 24); `props.filled` (boolean or signal) switches the FILL axis |
| `interactive(name, props, ink, content)` | A box with a state layer (hover 8%, focus 10%), a ripple under `content` and the focus ring; returns the node |
| `focusable(name, props)` | M3's focus indicator on a node that takes Tab focus: a 3dp `secondary` ring while keyboard focus is on it (`focus_visible`), added to `props.shadows`; sets `focus_ring = false`. The ring hugs the shape: a shadow can't leave the spec's 2dp gap The ring hugs the shape: a shadow can't paint the spec's 2dp gap (engine request: an outline offset). |
| `scroll_ease()` | The animation of a user scroll column: `animate = { scroll = m3.scroll_ease() }` (critically damped spring, quick under reduced motion) |
| `window` | Field, default `nil`: the id of the window or panel layers open over when an opener gets no `window` |

#### theme.lua (`m3.theme`)

See Theme above.

| Name | Meaning |
| :--- | :--- |
| `seed` | State: a `"#RRGGBB"` seed, or `"system"` (default) for `mantle.appearance.accent`, else the first of `SEEDS` |
| `appearance` | State: `"system"` (default), `"light"` or `"dark"` |
| `dark` | Signal (not a state): whether the colours are dark, from `appearance`, else the desktop's colour scheme (none is light). Flip it with `toggle_dark()` |
| `variant`, `contrast` | States: scheme variant (`VARIANTS`); `"system"` (default: the desktop's high contrast is 1, else 0) or -1..1 |
| `reduced_motion` | Signal: the desktop asks for reduced motion; every spring in `motion` is then quick and critically damped (not in the spec) |
| `next_seed()`, `toggle_dark()` | Step `seed` through `SEEDS`; flip light and dark |
| `scheme` | Signal of the whole role table, for `computed` |
| `c.<role>` | Live colour signal of one role |
| `pick(flag, yes, no)` | Signal of role `yes` or `no` chosen by boolean signal `flag` |
| `alpha(color, a)` | `"#RRGGBB[AA]"` at alpha 0..1 (plain string) |
| `type`, `TYPE_SCALE`, `motion`, `springs`, `easing`, `shadows`, `elevation`, `CLEAR`, `SEEDS`, `VARIANTS` | Tokens. A `motion` spring's `spring` field is a signal (reduced motion), so put an entry in `animate` as it is, or merge it into a table (`{ from = 0, spring = motion.spatial.spring }`); `springs.<name>` has the plain `{ stiffness, damping }`. `motion.scroll` is the wheel ease |

#### shapes.lua (`m3.shapes`)

| Function | Meaning |
| :--- | :--- |
| `commands(name, size)` | Closed path commands of shape `name` (one of `NAMES`) fitting a `size` box, for `animate.commands` morphs |

#### overlay.lua (`m3.overlay`)

Layers over a window or panel (the host), one stack per host. Every opener takes `window` (the host's id).

| Function | opts |
| :--- | :--- |
| `notify(message, opts?)` | Snackbar, one per host. `action` (label) with `on_action`, `close` (trailing close icon), `window`. Leaves after 4 s, 8 s with an action Further messages queue and show after the current one leaves. |
| `ask(spec, confirm?)` | Dialog over a scrim. `spec`: `title`, `icon?`, `body?` (string, or any node: it scrolls when tall), `actions?` (`{ label, kind? ("text" default, "tonal", "filled"), on_click? }[]`, each closes the dialog then runs; default Cancel), `confirm?` (label of a trailing action that runs `confirm`), `window?` |
| `confirm_remove(spec, remove, restore)` | A delete behind a confirm dialog (`spec` as `ask`, `icon` and `confirm` default to a delete's; `message` is the snackbar text), then a snackbar whose Undo calls `restore` |
| `close_dialog()`, `close_all()` | Close the dialog, or every layer and the tooltip |
| `layer(id, build, handlers?)`, `open(id, data?, host?)`, `close(id)`, `is_open(id)` | Register a layer builder (`handlers.escape()`, `handlers.key(key)` for its own Escape and keys), show it on a host, remove it, signal of whether it shows |
| `show_tip(id, anchor_name, build, host?)`, `hide_tip(id)` | One tooltip layer at a time; `build(anchor, bounds)` gets the anchor's and the host's `geometry` |
| `bounds(host?)`, `escape(host?)`, `key(host?, key)`, `on_key(host?, fn)` | The host root's `geometry`; close its top layer; hand it a key; keys no control or layer took (shortcuts) |
| `root(base, host)`, `popup(parent)` | A window root's children signal; the popup surface that hosts a panel's layers |

#### window.lua (`m3.app_window`, `m3.window_controls`, `m3.window_drag`, `m3.window_class`)

| Function | opts |
| :--- | :--- |
| `window_class(window?)` | Signal of the window's M3 size class from its root width: `"compact"` (<600 dp), `"medium"` (600-839), `"expanded"` (840-1199), `"large"` (1200-1599), `"extra_large"` (1600+). One signal per window id; `window` default `core.window`. Reads `"expanded"` before the first layout |
| `app_window(props)` | A `window` with `props.child` wrapped in the overlay root; Escape and keys go to the layers. `decorations` (`"client"` default: the app draws a 28dp-cornered frame (not in the spec) with an elevation 3 shadow band, edge resize grips, corners squared when tiled or maximised, and the window controls at the top end; `"server"`: the compositor's), `controls` (client only, default true; `false` when your top bar carries `window_controls`) |
| `window_controls(id, on_close?)` | Minimise, maximise or restore (follows `toplevel(id):state()`) and close, as standard icon buttons |
| `window_drag(id)` | An `on_press` for a title bar: a left press moves the window, two within 400 ms maximise or restore it, a right press opens the window menu. Put it on a `rect` stacked behind the top app bar, not around it (a button's press would reach the ancestor) |

### Actions (`actions/`)

Buttons, FABs, button groups, split and segmented buttons. Buttons spring their corners smaller while pressed.

#### actions/button.lua (`button`)

Common button: five emphasis levels, five Expressive sizes, optional toggle.

| Function | opts |
| :--- | :--- |
| `button(id, opts)` | `kind` (`"filled"` default, `"tonal"`, `"elevated"`, `"outlined"`, `"text"`), `size` (`"xs"`..`"xl"`, default `"s"`; heights 32 / 40 / 56 / 96 / 136), `shape` (`"round"` default, `"square"`, `"toggle"`; a toggle squares while selected, implied by `value`), `label`, `icon` (Material Symbols name; signals), `value` (boolean state: makes it a toggle, a click flips it), `disabled` (signal: 38% and inert), `width` (fixed, content centred), `padding`, `icon_size` (override the size's), `icon_props`, `props` (extra node props for the container), `radius` (`fun(held, selected)` returning a radius signal; overrides the shape), `held` (pressed state; default its own), `on_click` (after the toggle flips) |

#### actions/icon_button.lua (`icon_button`)

One glyph in a square container; a toggle fills its glyph.

| Function | opts |
| :--- | :--- |
| `icon_button(id, opts)` | `kind` (`"standard"` default, `"filled"`, `"tonal"`, `"outlined"`), `size` (default `"s"`), `shape` (as `button`), `icon` (required; signal), `value` (boolean state: toggle), `disabled` (signal), `props`, `on_click` |

#### actions/fab.lua (`fab`, `extended_fab`, `fab_menu`)

Floating action buttons (elevation 3).

| Function | opts |
| :--- | :--- |
| `fab(id, opts)` | `size` (`"small"` 40, `"fab"` 56 default, `"large"` 96), `tone` (`"primary"` default, `"secondary"`, `"tertiary"`, `"surface"`), `icon` (required; signal), `props`, `on_click` |
| `extended_fab(id, opts)` | `tone`, `icon` (required), `label` (required), `expanded` (boolean state, default true; false collapses it to a plain FAB), `scroll` (the content's scroll signal: collapses on a scroll down, expands on a scroll up), `disabled`, `props`, `on_click` |
| `fab_menu(id, opts)` | `items` (required: `{ icon, label, on_click? }`; picking one closes the menu), `value` (boolean state: open) |

#### actions/button_group.lua (`button_group`)

Buttons in a row.

| Function | opts |
| :--- | :--- |
| `button_group(id, opts)` | `kind` (`"standard"` default: pressing one grows it while its neighbours squish; `"connected"`: one selection, inner corners small, the selected item fully round), `button_kind` (the buttons' `kind`, default `"tonal"`), `items` (required: `{ label?, icon?, on_click? }`), `value` (connected only: state of the selected index, default 1) |

#### actions/split_button.lua (`split_button`)

A leading action and a chevron that opens a menu under the whole button.

| Function | opts |
| :--- | :--- |
| `split_button(id, opts)` | `kind` (as `button`), `label`, `icon`, `on_click` (the leading action), `disabled`, `items` (required: menu items, see `open_menu`), `width` (menu width, default 224) |

#### actions/segmented_button.lua (`segmented_button`)

One outlined pill split into equal segments; the selected one is tinted and checked.

| Function | opts |
| :--- | :--- |
| `segmented_button(id, opts)` | `options` (required: list of strings), `value` (state of the selected option; default the first), `width` (per segment) |

### Communication (`communication/`)

Badges, progress and loading indicators, tooltips.

#### communication/badge.lua (`badge`, `badged`)

A dot or a count pill, and a wrapper that places one on a child's top-end corner.

| Function | opts |
| :--- | :--- |
| `badge(id, opts?)` | `count` (number or signal; omit for a 6px dot, else a 16px pill, `"999+"` past 999, hidden at 0) |
| `badged(id, opts)` | `child` (required; usually an `m3.icon`), `count` (as `badge`), `size` (the icon box the badge is placed against; default 24), `box_top` (where that box starts inside `child`; default `size * 0.1`, an `m3.icon` line box) |

#### communication/progress.lua (`linear_progress`, `circular_progress`)

Determinate and indeterminate, flat and wavy.

| Function | opts |
| :--- | :--- |
| `linear_progress(id, opts)` | `value` (0..1, number or signal; default 0), `indeterminate` (ignores `value`), `wavy`, `width` (default 240) |
| `circular_progress(id, opts)` | `value` (0..1, number or signal; default 0), `indeterminate` (ignores `value`), `wavy`. 48px |

#### communication/loading_indicator.lua (`loading_indicator`, `shape`)

The Expressive loading indicator and a single morphing shape.

| Function | opts |
| :--- | :--- |
| `loading_indicator(id, opts?)` | `contained` (sits it on a 48px primary container circle) |
| `shape(id, opts)` | `name` (string or signal, one of `m3.shapes.NAMES`; default `"circle"`; changing it morphs on a spring), `size` (default 48), `color` (string or signal; default `c.primary`), `props` |

#### communication/tooltip.lua (`tooltip`, `rich_tooltip`)

Drawn in the overlay, so no ancestor clips them.

| Function | opts |
| :--- | :--- |
| `tooltip(id, opts)` | `child` (required; the control), `label` (string or signal), `window`. Shows 500 ms after the pointer rests, above (below without room), inside the window |
| `rich_tooltip(id, opts)` | `child` (required), `title`, `body` (string or signal), `action` (button label), `on_action`, `window`. Shows after 300 ms of hover and stays while the pointer is on it |

### Containment (`containment/`)

Dividers, lists, cards, carousels and sheets.

#### containment/divider.lua (`divider`)

A 1px `outline_variant` rule.

| Function | opts |
| :--- | :--- |
| `divider(id, opts?)` | `kind` (`"full"` default, `"inset"` leaves 16px at the start, `"middle"` at both ends), `vertical` (fills its row) |

#### containment/list.lua (`list_item`, `item_list`, `list`)

1-3 line rows and a scrolling keyed list of them.

| Function | opts |
| :--- | :--- |
| `list_item(id, opts)` | `lines` (1-3 strings or signals; required; height 56, 72, 88), `leading` (`{ icon }` name, `{ avatar }` letter, `{ image }` source or `{ node }`), `trailing` (`{ text }`, `{ checkbox }`, `{ switch }` (`true` or a state signal) or `{ node }`), `on_click`, `animated` (move, fade in and exit, for rows of a `list`) `selected` (signal; the selected container colour), `segment` (`"first"`, `"middle"`, `"last"`, `"only"`: a separate rounded segment), `props`. |
| `item_list(id, opts)` | `items` (`list_item` opts with `key`), `segmented` (2 px-apart rounded segments), `value` (state of the selected `key`), `width`. Up/Down/Home/End move focus |
| `list(id, opts)` | `source` (list signal; required), `key` (`fn(entry) -> string`; required), `item` (`fn(entry) -> node`; required, usually a `list_item` with `animated`), `query` (signal: filters `source` by fuzzy match on `search`, best match first), `search` (`fn(entry) -> string`; required with `query`), `height`, `width` (default `"fill"`) |

#### containment/card.lua (`card`)

Hover lifts one level; press adds the state layer and ripple.

| Function | opts |
| :--- | :--- |
| `card(id, opts)` | `kind` (`"elevated"` default, `"filled"`, `"outlined"`), `media` (image source), `media_height` (default 160), `headline`, `subhead`, `supporting` (string or signal), `actions` (button nodes), `on_click`, `props` |

#### containment/carousel.lua (`carousel`)

Multi-browse carousel that reflows as the wheel scrolls it.

| Function | opts |
| :--- | :--- |
| `carousel(id, opts)` | `items` (`{ image, label? }[]`; required), `height` (default 221), `controls` (previous / next buttons; default true) |

#### containment/sheet.lua (`open_bottom_sheet`, `open_side_sheet`, `open_fullscreen_dialog`)

Modal layers; one of each at a time.

| Function | opts |
| :--- | :--- |
| `open_bottom_sheet(opts?)` | `window`, `title`, `items` (`{ icon?, label, on_click? }[]`; rows that close the sheet, then run), `content` (nodes or a function returning them). Drag the handle down to dismiss `modal` (default true; `false` is a standard sheet with no scrim). The handle drags it: past 100 px or a fling closes it, a shorter release springs back. |
| `open_side_sheet(opts?)` | `window`, `title`, `content`, `confirm` (default `"Save"`), `cancel` (default `"Cancel"`), `on_confirm` (runs after the sheet closes) `modal` (default true; `false`: no scrim, the page stays live). |
| `open_fullscreen_dialog(opts?)` | `window`, `title`, `content`, `confirm` (default `"Save"`), `on_confirm` |

### Layout (`layout/`)

#### layout/adaptive.lua (`adaptive_navigation`, `list_detail`)

Layouts that follow the window size class (`window_class`).

| Function | opts |
| :--- | :--- |
| `adaptive_navigation(id, opts)` | `items` (required: `m3.NavItem[]`, with `label`), `value` (required: state of the selected key), `content` (required: the page; the navigation is placed beside or below it), `window` (whose width picks the layout), `class` (a class signal overriding the window's, for previews), `fab` (`{ icon, label?, on_click? }`, rails only), `drawer` (boolean: from 840 dp a standard drawer instead of the expanded rail). Compact: bottom navigation bar. Medium: collapsed rail. Expanded and up: expanded rail |
| `list_detail(id, opts)` | `list`, `detail` (required nodes), `has_detail` (required state of whether an item is open), `window`, `class` (as above). From 840 dp the panes sit side by side (list 360, 24 gaps and margins, `surface_container`); narrower, the list, or the detail under a back button that sets `has_detail` false |

### Navigation (`navigation/`)

Tabs, bars, drawers and rails. Destinations are selected by `item.name`, or by position when it has none; every `value` is a state holding that key. A destination is `{ name?, label?, icon, badge?, count? }` (`m3.NavItem`).

#### navigation/tabs.lua (`tabs`, `tab_content`)

Primary and secondary tabs with an indicator that springs to the selected tab, and the page of the selected tab.

| Function | opts |
| :--- | :--- |
| `tabs(id, opts)` | `items` (required; `{ name?, label, icon? }`), `value` (required; state: the selected `name` or index), `kind` (`"primary"` default: 3px indicator under the content, icons above labels; `"secondary"`: 2px indicator across the tab) |
| `tab_content(id, opts)` | `value` (required; the tabs' state, an index), `pages` (required; one node per tab), `height`. The page slides in from the side the tab lies on |

#### navigation/navigation_bar.lua (`navigation_bar`)

Three to five destinations along the bottom edge; the pill springs open and the active icon fills.

| Function | opts |
| :--- | :--- |
| `navigation_bar(id, opts)` | `items` (required; destinations, `badge` shows a count), `value` (required; state), `labels` (default true; false is icons only and 64px tall, 80px with labels) |

#### navigation/navigation_drawer.lua (`navigation_drawer`, `open_navigation_drawer`)

Pill items with section headers and dividers. In a frame it slides over a scrim; `open_navigation_drawer` does the same over the whole window (needs `m3.app_window`).

| Function | opts |
| :--- | :--- |
| `navigation_drawer(id, opts)` | `items` (required; destinations with `count`, `{ header = "..." }`, `{ divider = true }`), `value` (state; default its own), `on_select(key)`, `kind` (`"modal"` default: slides over a scrim; `"standard"`: the plain sheet), `open` (state; modal only: whether it is shown) |
| `open_navigation_drawer(opts)` | `items` (required), `value` (state; default its own), `on_select(key)`, `window`, as `navigation_drawer`. Pressing the scrim closes it |

#### navigation/fade_through.lua (`fade_through`)

| Function | opts |
| :--- | :--- |
| `fade_through(key, pages, opts?)` | The page `pages[key]` for the signal `key` (a state also closes the open layers when it changes): the old page fades out in 90 ms, then the new one fades in over 210 ms from 92%. `opts.scroll`: prefix of a named `scroll` per page, which then scrolls with the eased wheel |

#### navigation/navigation_rail.lua (`navigation_rail`)

A side rail for three to seven destinations: optional menu button and FAB, then the destinations. Collapsed (96px) each is a pill with its label below; expanded (220px) horizontal pill items and an extended FAB, the width on a spring.

| Function | opts |
| :--- | :--- |
| `navigation_rail(id, opts)` | `destinations` (required; `{ name, icon, label?, badge? }`), `value` (required; state: the selected name), `fab` (`{ icon, label?, on_click? }`; `label` is shown when expanded), `expanded` (state or boolean, default false), `menu` (boolean; a button that toggles `expanded`, which must then be a state), `modal` (boolean; a scrim beside the expanded rail, pressing it collapses the rail) |

#### navigation/top_app_bar.lua (`top_app_bar`, `top_app_bar_height`)

A 64px bar; medium (112) and large (120) start with a headline that fades into the title row as `scroll` grows, collapsing the bar to 64px. The bar takes surface container once content passes under it.

| Function | opts |
| :--- | :--- |
| `top_app_bar(id, opts)` | `kind` (`"small"` default, `"center"`, `"medium"`, `"large"`), `title` (string or signal), `navigation_icon` (symbol name), `on_navigation`, `actions` (`{ icon, on_click?, label?, menu? }`; `menu` is menu items, or `{ items, width? }`, that open under the button), `scroll` (the content's scroll signal), `window` (a client-side window's id: the bar becomes its title bar, drag, double press and right press, and ends in the window controls), `on_close` (their close button) |
| `top_app_bar_height(kind?)` | Number: the height of a bar of `kind` (default `"small"`), to pad the content that scrolls under it |

#### navigation/toolbar.lua (`toolbar`)

Expressive toolbar of icon actions with an optional FAB; place it at the bottom of a frame.

| Function | opts |
| :--- | :--- |
| `toolbar(id, opts)` | `kind` (`"docked"` default: full-width bar; `"floating"`: a pill that slides away on a scroll down and back on a scroll up), `actions` (`{ icon, on_click?, label? }`), `fab` (`{ icon, label?, on_click? }`), `scroll` (the content's scroll signal; floating only) |

### Selection (`selection/`)

Toggles, chips, slider, menus and pickers. Doc: `docs/selection.md`.

#### selection/checkbox.lua (`checkbox`, `checkbox_group`)

An 18 px box in a 40 px state layer; the tick and dash draw out.

| Function | opts |
| :--- | :--- |
| `checkbox(id, opts)` | `value` (state `true`, `false` or `"indeterminate"`; default own, `false`; a click sets `true`, or `false` when it was `true`), `label`, `error` (signal), `disabled` (signal), `on_change(value)` |
| `checkbox_group(id, opts)` | `items` (labels; required), `label` (the parent's), `value` (state: a set `{ [label] = true }`; default own, the first item), `error`, `disabled`, `on_change(set)`. The parent is checked when all are, indeterminate when some are; clicking it checks or clears all |

#### selection/radio.lua (`radio_group`)

A column of 20 px rings whose dot grows on a spring.

| Function | opts |
| :--- | :--- |
| `radio_group(id, opts)` | `options` (labels; required), `value` (state of the chosen label; default own, the first), `disabled` (signal), `on_change(label)` |

#### selection/switch.lua (`switch`)

A 52x32 track; the thumb grows and slides on a spring.

| Function | opts |
| :--- | :--- |
| `switch(id, opts)` | `value` (state boolean; default own, `false`), `icons` (check on the thumb when on, close when off), `disabled` (signal), `label` (accessible name; with `detail` a settings row), `detail` (second line; the switch trails the row), `on_change(on)` |

#### selection/chips.lua (`chip`, `input_chips`, `suggestion_chips`)

32 px chips with 8 px corners.

| Function | opts |
| :--- | :--- |
| `chip(id, opts)` | `kind` (`"assist"` default, `"filter"`, `"input"`, `"suggestion"`), `label` (required), `icon` (assist), `elevated` (assist, suggestion), `value` (filter: state of selected), `avatar` (input; default the label's first letter), `on_click` (assist, suggestion), `on_change(on)` (filter), `on_remove` (input), `disabled` (assist, filter, suggestion), `appear` (fade in and move when listed) |
| `input_chips(id, opts)` | `value` (state: the list of labels; default own, empty). A horizontal list of removable input chips Left/Right/Home/End move focus. |
| `suggestion_chips(id, opts)` | `options` (labels; required), `value` (state: the list of labels, shared with `input_chips`; required). Lists the options not in `value`; picking one appends it Left/Right/Home/End move focus. |

#### selection/slider.lua (`slider`)

Track in three segments around each 4 px handle, optional ticks, a value bubble over a held handle; the wheel nudges a single thumb.

| Function | opts |
| :--- | :--- |
| `slider(id, opts)` | `kind` (`"continuous"` default, `"discrete"`, `"range"`, `"centered"`), `value` (state 0..1, the high thumb of a range; default own, `0.5`), `low` (state: the range's low thumb; default own, `0.25`), `size` (`"xs"` default, `"s"`, `"m"`, `"l"`, `"xl"`), `steps` (discrete; default 5), `width` (default 300), `format(v)` (bubble text; default percent) |

#### selection/menu.lua (`open_menu`, `menu_open`, `context_menu`, `bind_shortcuts`, `menu_highlighted`, `pick_highlighted`, `dropdown`)

One menu layer under its anchor or at a point, kept inside the window (flipped above or beside, slid back); a click outside, Escape or an item closes it. A selected item shows a check on a tinted row. Up, Down, Home, End, Enter, Right and Left (submenus) and typed letters steer it.

| Function | opts |
| :--- | :--- |
| `open_menu(opts)` | `anchor` (a `geometry(name)` signal; the menu opens under it) or `at` (`{ x, y }` in the window: a context menu touching the pointer), `items` (required; `{ label, icon?, shortcut?, selected? (signal), disabled?, submenu? (items; one level, opens to the side), on_click? }`, `{ divider = true }` or `{ header = "..." }`), `on_pick(item)`, `width` (px or `"anchor"`; default 224), `align` (`"start"` default, `"end"`; `"end"` needs a px width), `vibrant` (Expressive tertiary container), `id` (names the opener, for `menu_open`), `window` Items may be `{ group = {...} }`, or `{ gap = true }` between runs, for an Expressive grouped menu of rounded containers. |
| `menu_open(id)` | Signal: true while the menu opened with `id` shows |
| `context_menu(id, opts)` | Wraps `opts.child` so a right click opens `opts.items` (or a function building them) at the pointer; `on_pick`, `vibrant`, `window` |
| `bind_shortcuts(items, window?)` | Makes the items' `shortcut` strings (`"Ctrl+Shift+N"`, or `⌘⇧N` with ⌘ as Ctrl) run their `on_click` while the window has the keyboard and no layer is open |
| `menu_highlighted()`, `pick_highlighted(id?)` | The item the open menu highlights, or nil; pick it as Enter does (false when none, or not `id`'s menu) |
| `dropdown(id, opts)` | `options` (strings; required), `label`, `value` (state of the chosen option; default own, the first), `kind` (`"outlined"` or `"filled"`), `container` (colour behind an outlined field), `width` (default 280), `on_change(option)`, `window` |

#### selection/date_picker.lua (`open_date_picker`, `date_picker`)

A month grid that slides sideways; modal with a headline, or docked under its field.

| Function | opts |
| :--- | :--- |
| `open_date_picker(opts)` | `value` (state `{ a, b }`: days as `yyyymmdd`, `b` ending a range; default shared), `range` (pick two days), `docked` (a calendar under `anchor` instead of a modal), `anchor` (a `geometry(name)` signal, with `docked`), `on_change(t)` (after OK) `range` with `input`: Start and End typed fields; OK waits for both valid with end >= start. |
| `date_picker(id, opts)` | The docked picker's field: `label`, `value` (default own, empty), `range`, `kind`, `container`, `width` (default 280), `on_change(t)` |

#### selection/time_picker.lua (`open_time_picker`, `time_picker`)

A dial whose hand turns the short way; dragging picks the hour, then the minutes.

| Function | opts |
| :--- | :--- |
| `open_time_picker(opts)` | `value` (state `{ h = 1..12, m = 0..59, pm = boolean }`; default shared), `on_change(t)` (after OK) `h24`: a 24 h dial (inner ring 13-00, picked by radius) and a 0-23 typed hour. Invalid typed fields show the error style and block OK. |
| `time_picker(id, opts)` | The field: `label`, `value` (default own, 10:30 AM), `kind`, `container`, `width` (default 280), `on_change(t)` |

### Inputs (`inputs/`)

Text fields and search.

#### inputs/text_field.lua (`text_field`)

Outlined or filled field. Returns the node and a handle `{ value, clear, set }`: `value` is the text signal, `clear()` empties the field, `set(text)` replaces it (changing the state alone does not update the typed draft). Wrap the call in parentheses to keep only the node, e.g. in a table constructor.

| Function | opts |
| :--- | :--- |
| `text_field(id, opts)` | `kind` (`"outlined"` default, `"filled"`), `label` (floats up while focused or filled; signal), `value` (state of the text; default its own), `container` (colour behind an outlined field, which the floating label cuts the outline with), `width` (number or `"fill"`, default `"fill"`), `leading`, `trailing` (icon names), `clear` (a clear button while typing), `prefix`, `suffix` (text, shown once raised; signals), `supporting` (helper text), `validate` (`fun(text)` returning an error message or nil, shown in place of the supporting text), `max_length` (caps the text; shows an `n/max` counter), `disabled`, `placeholder`. Read-only mode, used by `dropdown` and the pickers: `display` (signal of the shown text, replaces the input), `on_click`, `active` (signal styling the field as focused), `spin` (turn the trailing icon while active), `geometry` (a `geometry(name)` for the field); the handle then has only `value` |

#### inputs/search.lua (`search_bar`, `open_search_view`)

A 56 px pill that opens a search view over suggestions, or an inline editable bar.

| Function | opts |
| :--- | :--- |
| `search_bar(id, opts)` | `kind` (`"view"` default opens a search view; `"inline"` is an editable bar), `placeholder` (default `"Search"`), `on_change` (inline: on every edit, Escape sends `""`), `options` (view: suggestion strings, filtered by the query), `value` (view: state of the last pick, shown in the bar), `on_select` (view: a suggestion or Enter), `trailing` (view: icon, default `"mic"`), `max_length` (caps the typed query) |
| `open_search_view(opts)` | `anchor` (the bar's `geometry(name)` signal; the view grows out of it), `options` (required), `value` (required: state of the last pick), `placeholder`, `max_length`, `on_select`. `search_bar` calls it for you |

## Input and keyboard additions

| Component | Added |
| :--- | :--- |
| `text_field` | `multiline` (grows between `min_lines` and `max_lines`, then scrolls), `submit_key`, `on_submit`, `format(text)`, `on_change(text)`, `autofocus`, `window`. Selection ink is primary at 30%. Right-clicking a text or search field opens an Edit menu (Cut, Copy, Paste, Select all); `m3.edit_click` is the helper |
| Pickers | `open_date_picker { input = true }`: a typed mm/dd/yyyy field that toggles to the calendar (not with range or docked). `open_time_picker { input = true, h24 = true }` and `time_picker(id, { input, h24 })`: typed hour and minute fields |
| Keyboard | Radio groups, tabs, segmented buttons, button groups, the navigation bar and `chip_group` move with the arrows and Home/End (radio and tabs also select). Sliders step with the arrows, leap with PageUp/PageDown, jump with Home/End |
| `slider` | `vertical`, `icon`, `label` |
| `segmented_button` | `multi`; options are strings or `{ label?, icon?, name? }` |
| `icon_button` | `width`: narrow, default or wide |
| `carousel` | `layout`: `multi_browse`, `hero`, `uncontained` or `full_screen`; `item_width` |
| `top_app_bar` | `kind = "flexible"`, `subtitle` |
| `navigation_bar` | `short` |
