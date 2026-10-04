# m3: Material 3 for Mantle

Material 3 (including M3 Expressive) components for a Mantle config, coloured live from one seed.

## Requirements

A Mantle build with the changelog's current Unreleased features: `palette.scheme`/`hct`, `font_variations`,
per-corner `radius`, layered `shadows`, `path` trim, caps, `trim_axis` and `shift`, `textfield` `disabled`/`max_length`/`placeholder_color`/`caret`/`initial_text`, keyframe `spring`,
`image.radius`, `animate.scroll`, `on_escape`. Fonts: Material Symbols Rounded (icons) and any sans
(Inter recommended).

## Setup

Copy (or symlink) `m3/` into your config directory, then:

```lua
fonts { "Inter", "Noto Sans" }          -- any sans; icons use the "Material Symbols Rounded" font
local m3 = require("m3")

m3.theme.seed:set("#6750A4")             -- optional: seed colour, also `m3.theme.dark`, `m3.theme.variant`

return {
    -- Wires the overlay layers (menus, sheets, pickers, tooltips, dialogs, snackbar) and Escape.
    m3.app_window { id = "app", title = "My app", child = column { children = {
        m3.button("save", { label = "Save", on_click = function() m3.overlay.notify("Saved") end }),
    } } },
}
```

Components that open layers need `m3.app_window` (or `m3.overlay.root(child)` as the window
root's `children` plus `on_escape = m3.overlay.escape`).

## Conventions

| Rule | Detail |
| :--- | :--- |
| Call shape | `m3.<name>(id, opts)`. `id` is a string unique per instance; it names the component's own hover/press state. `opts` is a table, every field optional unless the doc says so |
| Values | A component that holds a value takes `opts.value`, a `state(...)` signal it reads and writes (checked, selected, level, text). Pass your own state to observe or drive it |
| Callbacks | `opts.on_<event>` (`on_click`, `on_change`, `on_close`) |
| Signals | Any display field (`label`, `icon`, `disabled`, ...) takes a plain value or a signal |
| Variants | `opts.kind` picks the M3 variant (`"filled"`, `"outlined"`, `"tonal"`, ...); `opts.size` an Expressive size (`"xs"` ... `"xl"`) |
| Colours | Only `m3.theme.c.<role>` signals; components never take raw colours |
| Layers | Openers are functions: `m3.open_<thing>(opts)`; Escape and `m3.overlay.close_all()` close them |

## Theme

`m3.theme.c.<role>` is a live signal of each of the 49 M3 colour roles. `m3.theme.type` / `TYPE_SCALE`
is the full 15-style type scale; `m3.theme.motion` holds the Expressive scheme's six springs (`spatial_fast`, `spatial`, `spatial_slow`, `effects_fast`, `effects`, `effects_slow`), `m3.theme.easing`
the M3 cubic-beziers and `m3.theme.elevation[0..5]` the M3 key + ambient shadow pairs (spread onto a node's props; `m3.theme.shadows[n]` is the bare `shadows` list, for binding). See `theme.lua`.

## Components

One file per component family; `require("m3")` loads them all, `require("m3.<file>")` just one.
`internal/` holds shared helpers and is not public API. Docs are per M3 category in `docs/`.

| Category | Files | Doc |
| :--- | :--- | :--- |
| Core | `core` (`text`, `icon`, `interactive`, `merge`) | |
| Actions | `button`, `icon_button`, `fab`, `button_group`, `split_button`, `segmented_button` | `docs/actions.md` |
| Communication | `badge`, `progress`, `loading_indicator`, `tooltip` | `docs/communication.md` |
| Containment | `divider`, `list`, `card`, `carousel`, `sheet` | `docs/containment.md` |
| Navigation | `tabs`, `navigation_bar`, `navigation_drawer`, `navigation_rail`, `top_app_bar`, `toolbar` | `docs/navigation.md` |
| Selection | `checkbox`, `radio`, `switch`, `chips`, `slider`, `menu`, `date_picker`, `time_picker` | `docs/selection.md` |
| Text inputs | `text_field`, `search` | `docs/inputs.md` |
