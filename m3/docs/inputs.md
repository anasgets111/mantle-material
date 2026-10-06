# Text inputs

`local m3 = require("m3")`.

| Component | What it is |
| :--- | :--- |
| `text_field` | Outlined or filled field with a floating label, validation, supporting text, counter, affixes, icons and clear |
| `search_field` | An inline editable search pill (56 px, elevation 3) |
| `search_bar` | A 56 px pill (elevation 3) that opens a search view over suggestions |
| `open_search_view` | The search view layer, growing out of its bar |

## text_field

`m3.text_field(id, opts)` returns the node and a handle. In a table constructor wrap the call in parentheses to keep only the node.

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `kind` | `"outlined"`, `"filled"` | `"outlined"` | Variant |
| `label` | string | none | Floats up while focused or filled |
| `name` | string | label | Accessible name |
| `value` | state string | own | The text |
| `container` | colour | `surface_container` | Colour behind an outlined field, which the floating label cuts the outline with |
| `width` | number or `"fill"` | `"fill"` | Field width |
| `leading`, `trailing` | icon name | none | Icons at each end |
| `clear` | boolean | `false` | Clear button while there is text |
| `prefix`, `suffix` | string | none | Shown once the field is raised |
| `supporting` | string | none | Helper text |
| `validate` | `fun(text): string?` | none | An error message, shown in place of the supporting text |
| `max_length` | number | none | Caps the text (typing, paste, `set`) and shows an `n/max` counter |
| `disabled` | boolean | `false` | Content at 38%, outline at 12% (filled: container 4%, indicator 38%); takes no keyboard focus or clicks |
| `placeholder` | string | none | Hint while empty |

Read-only mode, used by `dropdown` and the pickers: `display` (a signal of the shown text, replaces the input), `on_click`, `active` (a signal that styles the field as focused), `spin` (turn the trailing icon while active), `geometry` (a `geometry(name)` for the field).

Handle: `{ value, focus, clear, set }`. `value` is the text signal, `focus()` takes keyboard focus, `clear()` empties the field, `set(text)` replaces it (changing the state alone does not update the typed draft). A read-only field has only `value`.

```lua
local field, email = m3.text_field("email", { label = "Email", leading = "mail", clear = true, validate = is_email })
m3.button("reset", { kind = "primary", label = "Reset", on_click = email.clear })
```

## search_field

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `placeholder` | string | `"Search"` | Hint |
| `name` | string | placeholder | Accessible name |
| `on_change` | `fun(text)` | none | On every edit; Escape sends `""` |
| `max_length` | number | none | Caps the typed query |

## search_bar

| Field | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `placeholder` | string | `"Search"` | Hint |
| `name` | string | placeholder | Accessible name |
| `options` | string list | `{}` | Suggestions, filtered by the query |
| `value` | state string | own | The last pick, shown in the bar |
| `on_select` | `fun(text)` | none | A suggestion or Enter |
| `trailing` | icon name | `"mic"` | Icon at the end |
| `max_length` | number | none | Caps the typed query |

```lua
m3.search_field("contacts", { placeholder = "Search contacts", on_change = function(t) query:set(t) end })
m3.search_bar("people", { options = { "Ada", "Alan" }, on_select = print })
```

## open_search_view

`m3.open_search_view({ anchor, options, value, placeholder, max_length, on_select })` opens the view over `anchor` (a `geometry(name)` signal), growing out of it. `search_bar` calls it for you.
