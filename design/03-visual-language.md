# 03 · Visual language

All tokens live in `theme/tokens.json` (the single source) and reach QML through the `Tokens`
singleton and every app through the renderer ([08-theming.md](08-theming.md)). No colour, size,
radius or duration is ever typed into a component.

## 1. Character

Warm, quiet, precise. A brown-black (or paper-white) frame like a well-made bezel, cream ink, one
calm accent. Generous spacing inside surfaces, tight and dense in the bar. Rounded, never bubbly.
Nothing glows, nothing pulses, nothing is outlined for decoration.

## 2. Colour

### 2.1 Palettes

Two palettes, one per mode. **Ember** is the default.

| Role | Ember (dark) | Linen (light) | Used for |
|---|---|---|---|
| `ground` | `#191613` | `#f4ede1` | the frame, the bar, every drawer: the one material |
| `raised` | `#231f1b` | `#ebe3d5` | cards, fields, tiles inside drawers |
| `raisedHot` | `#2c2722` | `#e2d8c8` | a raised element under the pointer |
| `sunken` | `#12100e` | `#fbf7f0` | the Spotlight field, text inputs, the lock-screen password pill |
| `line` | `#332d27` | `#d8cdbb` | the one hairline under a header, separators in lists, the frame's inner edge |
| `ink.main` | `#efe6d4` | `#272119` | names, titles, values, the line in focus |
| `ink.sec` | `#d3c8b3` | `#463d32` | body text, secondary values |
| `ink.meta` | `#b8ac99` | `#685d4f` | facts: times, sizes, counts, hints, keycap letters |
| `ink.faint` | `#7f756a` | `#a0948a` | disabled, placeholders, empty workspace numbers |
| `warn` | `#ecbf68` | `#875400` | needs attention: battery low, mic in use, update pending |
| `crit` | `#fa9d86` | `#b03522` | recording, muted, failed, destructive actions, critical notifications |
| `onAccent` | `#11100d` | `#fbf7f0` | text and glyphs on an accent fill |
| `scrim` | `#0d0b09` at 45 % | `#2a241d` at 28 % | dim behind polkit and the session sheet |
| `shadow` | `#000000` at 38 % | `#3b2f20` at 18 % | drawer shadow |

### 2.2 Accents

One accent at a time, chosen in settings (`appearance.accent`). Default **jade**.

| Accent | Ember | Linen | Papirus folder colour (icon theme) |
|---|---|---|---|
| `jade` (default) | `#9acfae` | `#25704f` | `teal` |
| `apricot` | `#efb07f` | `#9a4f1c` | `orange` |
| `sky` | `#94c3dc` | `#1f5f86` | `blue` |
| `iris` | `#b9aeea` | `#5546a8` | `violet` |
| `rose` | `#eba8bd` | `#9b3456` | `pink` |
| `sand` | `#d9c38f` | `#6e5a1c` | `paleorange` |
| `wallpaper` | the curated accent whose hue is nearest the wallpaper's dominant chroma-weighted hue | same | of the chosen accent |

`wallpaper` never invents a colour: it only picks one of the six, so contrast stays guaranteed.

### 2.3 Washes (state layers)

States are `ink.main` laid over the current ground at a fixed amount, not separate colours:

| Wash | Amount | Use |
|---|---|---|
| `hover` | 6 % | a row, button or tile under the pointer |
| `current` | 10 % | the selected row in a list (keyboard or pointer) |
| `currentHover` | 14 % | the selected row under the pointer |
| `pressed` | 18 % | while the button is down |
| `accentWash` | accent at 16 % over ground | an "on" tile's background, the active workspace hover |

### 2.4 Contrast (APCA Lc, measured)

Measured with APCA 0.0.98G on the real values. Targets: main ≥ 85, sec ≥ 70, meta ≥ 55, accent and
signal colours ≥ 60, faint ≈ 25–45 (disabled only), text on an accent ≥ 64.

| Ink on → | Ember ground | Ember raised | Ember raisedHot | Linen ground | Linen raised | Linen raisedHot |
|---|---|---|---|---|---|---|
| main | 91 | 90 | 89 | 93 | 87 | 81 |
| sec | 73 | 72 | 70 | 84 | 79 | 73 |
| meta | 57 | 56 | 55 | 72 | 66 | 60 |
| faint | 29 | 28 | 27 | 46 | 40 | 34 |
| accent (jade) | 69 | 68 | 67 | 69 | 64 | 57 |
| warn | 71 | 70 | 68 | 71 | 65 | 59 |
| crit | 62 | 60 | 59 | 70 | 64 | 58 |

Accents as text on Ember ground: jade 69, apricot 66, sky 66, iris 62, rose 65, sand 71; on Linen
ground: 69, 69, 73, 75, 73, 73. `onAccent` on accent fills: Ember 64–72, Linen 80–85.

Rules that follow from the table: in Linen, `ink.meta` is not used on `raisedHot` for text under
12 px; accent text in Linen sits on `ground` or `raised`, never on `raisedHot`.

### 2.5 Meaning

| Colour | Means | Never used for |
|---|---|---|
| accent | the current place (active workspace, selected tab), "on" (a toggle), the default action, what is playing, progress of something you started, the keyboard focus ring | decoration, headings, links in body text |
| warn | something needs your attention soon | "on" states |
| crit | something is recording, muted or failing; an action that destroys | errors you cannot act on (those are plain text) |
| neutral inks | everything else | — |

Colour is never the only signal: a muted mic also shows the slashed glyph; a destructive button
also shows the warning glyph; low battery also shows the number.

### 2.6 Mode switching

`appearance.mode` = `dark` | `light` | `auto`. `auto` follows the night-light schedule: Linen from
sunrise, Ember from sunset (location in [10-settings.md](10-settings.md)). Switching crossfades the
whole shell over 400 ms (every colour token animates, see [04-motion.md](04-motion.md) §6) and
re-renders every app target.

## 3. Material

- **Solid by default.** The frame, the bar and all drawers are `ground` at 100 %. Docked drawers read
  as the frame extending, which only works when they are the same opaque material. Solid is also
  cheapest on the Intel UHD 630, which renders the shell.
- **Glass (setting `appearance.glass`, default off).** `ground` at 86 % with Hyprland's blur behind
  the drawn region only (layer rule with `ignore_alpha`). Text inks stay the same; the contrast
  table must still hold over the blurred wallpaper, so glass also raises `ground` alpha to 92 % when
  the wallpaper's measured luminance is in the mode's wrong half (bright wallpaper in Ember).
- **The frame's inner edge** carries a 1 px `line` at 70 % so the frame separates from bright
  wallpapers. Drawers do not have outlines.
- **Shadow.** Only drawers that open over windows cast one: offset y 6, blur 28, `shadow` colour.
  The frame and the bar never cast shadows.

## 4. Typography

Families (all installed system-wide already, nothing is added):

| Family | Use |
|---|---|
| **Inter** | all UI text |
| **Inter Display** | sizes ≥ 20 px: headings, the lock clock, big numbers |
| **JetBrains Mono** | keycaps, shell commands, clipboard text previews, calculator expressions |

Scale (px / weight / line height / tracking):

| Token | Size | Weight | Line | Tracking | Use |
|---|---|---|---|---|---|
| `micro` | 11 | 500 | 14 | +0.2 % | badges, keycap letters, the date beside the clock |
| `bar` | 12.5 | 500 | 16 | 0 | bar labels, workspace numbers, window title |
| `clock` | 13 | 600 | 16 | 0 | the bar clock (tabular) |
| `body` | 13 | 400 | 19 | 0 | rows, descriptions, notification bodies |
| `bodyStrong` | 13 | 600 | 19 | 0 | row titles, button labels |
| `title` | 15 | 600 | 20 | −0.2 % | drawer section titles, toast titles |
| `field` | 17 | 400 | 24 | −0.2 % | the Spotlight query |
| `heading` | 22 | 600 | 28 | −0.8 % | Today's date, page titles in the settings window |
| `number` | 34 | 300 | 38 | −1.5 % | battery %, temperature, calculator result |
| `display` | 112 | 200 | 112 | −3 % | lock-screen clock |

Rules:
- Every number that changes in place uses tabular figures (`font.features: { "tnum": 1 }`).
- Titles truncate at the end with "…"; file paths truncate in the middle ("~/Code/…/main.qml").
- No uppercase labels, no letter-spaced captions. Hierarchy comes from size, weight and ink.
- UI language: English. Time: 24 h (`14:32`). Dates: `Sat 7 Nov`, `Saturday, 7 November`. Week starts
  Monday. Numbers use a decimal point in the UI (`4.2 GB`).

## 5. Icons

- **Glyphs:** Material Symbols Rounded (variable font, Apache 2.0), bundled at
  `shell/assets/fonts/MaterialSymbolsRounded.ttf` and loaded with `FontLoader`.
- Axes: `opsz` follows the size; `wght` 400 at rest, 500 when active; `FILL` 0 at rest, 1 when "on";
  `GRAD` 0 in Ember, −25 in Linen (dark-on-light glyphs look heavier). `FILL` and `wght` animate
  (probe P-17; fallback: crossfade between the two glyph states).
- Sizes: 16 in the bar, 18 in rows and tiles, 20 in drawer headers, 24 in toasts, 40 in empty states.
- **App icons** come from desktop entries (`IconImage`, theme `aptus-icons-*`), sizes 16 (bar), 20
  (rows), 24 (toasts, [notch.md](surfaces/notch.md) §6), 28 (Spotlight rows), 32 (switcher), 48 (overview cards). A missing icon falls back
  to a `raised` rounded square with the app name's first letter in `ink.sec`.

## 6. Geometry

### 6.1 The frame and the windows

| Token | Value | Notes |
|---|---|---|
| `frame.edge` | 6 | left, right, bottom thickness (0 hides them) |
| `bar.height` | 32 | the top edge of the frame, including its 6 px share |
| `window.radius` | 10 | Hyprland `decoration.rounding` |
| `window.gap` | 8 | from the frame's inner edge to windows; between windows `gaps_in` 4 + 4 |
| `frame.innerRadius` | 18 | = `window.radius` + `window.gap`: concentric with every window corner |
| `cove` | 14 | the concave radius where a drawer meets the frame |
| `surface.radius` | 18 | a drawer's convex outer corners (= content radius 10 + padding 8) |
| `card.radius` | 12 | cards and fields inside drawers |
| `row.radius` | 8 | list rows and small buttons |
| `pill` | height / 2 | workspace pills, chips, the status cluster |
| `keycap.radius` | 4 | |

**Concentric rule:** an inner shape's radius = outer radius − padding between them. Every nested
shape in the shell obeys it.

### 6.2 Coves and bulges

A drawer that hangs from the bar is one path: the bar's bottom edge runs to `x − cove`, curves down
into the drawer's side with a concave quarter circle of radius `cove`, runs down the side, turns with
a convex `surface.radius` corner, crosses the bottom, and mirrors on the other side. Drawers docked
into a corner (Deck) have a cove where they meet the bar and a cove where they meet the side of the
frame, and one convex corner.

```
 bar  ───────────────╮         ╭──────────────── bar
                      ╰─┐     ┌─╯   ← coves (r 14), concave
                        │     │
                        ╰─────╯     ← convex corners (r 18)
```

The cove radius animates from 0 to 14 while a drawer opens, so a growing drawer peels out of the bar
rather than appearing under it.

### 6.3 Hit targets

At least 28 × 28 in the bar (the visual pill can be smaller; the input area is not), 36 px row
height in lists, 44 px in Spotlight. The keyboard focus ring is 2 px `accent` drawn 2 px outside the
element, with the element's radius + 2 (concentric), shown only after keyboard navigation.

## 7. Spacing

Base 4 px. Tokens: `s1` 2 · `s2` 4 · `s3` 6 · `s4` 8 · `s5` 12 · `s6` 16 · `s7` 20 · `s8` 24 ·
`s9` 32 · `s10` 48.

| Context | Padding | Gaps |
|---|---|---|
| Bar | 8 from the frame edge (content starts 14 px from the screen edge, [bar.md](surfaces/bar.md) §2) | 8 between items, 16 between zones |
| Drawers | 16 | 12 between sections, 8 inside a section |
| Rows | 8 horizontal, icon-to-text 12 | |
| Tiles | 12 | |
| Toast | 12 | 12 icon-to-text |

## 8. States

| State | Look |
|---|---|
| Rest | ground or raised, ink by role |
| Hover | `hover` wash, 120 ms |
| Pressed | `pressed` wash, buttons ≥ 32 px also scale to 0.98 (60 ms) |
| Keyboard focus | focus ring (§6.3) |
| Selected / current | `current` wash only (accent stripes are a banned pattern, §10); a selected row's glyph turns `FILL` 1 |
| On (toggle) | `accentWash` fill, glyph `FILL` 1 in accent, label stays `ink.main` |
| Disabled | ink `faint`, no wash on hover, cursor not changed, tooltip says why ("Bluetooth is off") |
| Loading | the value is replaced by a 3-dot ellipsis in `ink.meta` that fades in after 300 ms (fast loads never flash it) |
| Error | one line of `ink.sec` text saying what happened and what to do, plus a "Retry" plain button; crit colour only if the user's action failed destructively |

## 9. Components

| Component | Spec |
|---|---|
| **Button, primary** | height 32, radius 8, 12 horizontal padding, accent fill, `onAccent` label `bodyStrong`; one per surface at most |
| **Button, plain** | height 32, radius 8, 12 horizontal padding, `raised` fill, `ink.main` label |
| **Button, quiet** | height 28, no fill until hover, `ink.sec` label |
| **Button, risk** | plain button with crit label and a leading `warning` glyph; never the default |
| **Icon button** | 28 × 28 (bar) or 32 × 32 (drawers), radius 8, glyph 18, tooltip required |
| **Toggle tile** | 88 × 64, radius 12, `raised`; glyph top-left, label bottom-left `bodyStrong`, state line under it in `meta` ("Home Wi-Fi", "Off"); chevron area right 24 px opens its page |
| **Switch** | 36 × 20 track, 16 thumb; off: `line` track; on: accent track, `onAccent` thumb |
| **Slider** | 4 px track (`line`), filled part accent, thumb 16 round `ink.main`; glyph at the start changes with level (volume glyphs per 0/33/66/100); value label at the end in `meta`, tabular |
| **Segmented control** | height 28, radius 8, `sunken` track, selected segment `raised` with a 120 ms sliding indicator |
| **List row** (`ListRow`) | 36 high (44 in Spotlight), radius 8, leading icon, title `bodyStrong`/`body`, trailing meta or keycap; selected = `current` wash |
| **Field** | `sunken`, radius 12, 40 high (52 in Spotlight), caret 2 px accent |
| **Keycap** | JetBrains Mono `micro`, `raised` fill, radius 4, 18 high, 6 padding |
| **Ring** | 2 px track `line`, 2 px arc accent (or warn/crit), round caps; used for focus sessions, timers, battery in the deck |
| **Level** | the OSD bar: 6 px high, radius 3, accent fill, animates with the snappy spring |
| **Menu** | floating, `raised`, radius 12, 6 padding, rows 30 high, shadow; separators are 1 px `line` inset 8 |
| **Tooltip** | `raised`, radius 8, `body` `ink.main`, 6 × 8 padding, 600 ms delay, 0 ms when moving between tooltipped items within 1 s |
| **Badge** | 6 px dot (unread), or a 16 px high pill with a count in `micro` |
| **Empty state** | glyph 40 in `ink.faint`, one line `ink.sec`, optional one action |
| **Checkbox** | 18 × 18, radius 4; off: 1.5 px `ink.meta` outline; on: accent fill with a `check` glyph in `onAccent` (Today and Jot todos) |
| **Rolling digits** | tabular figures; only changed digits roll: the old one rises 6 px and fades, the new one rises from below (`fade`, M-34) — clock, battery figure, tile state lines (M-18) |
| **Ellipsis** | the loading state of §8: three 4 px dots in `ink.meta`, 3 px apart, fading in after 300 ms |
| **Error line** | the error state of §8: one line in `ink.sec` and a plain "Retry" button |
| **Pager dots** | 6 px dots 6 apart, `ink.faint`, current `ink.sec` (notch cards, Deck media) |
| **Swatch** | a 20 px colour dot; selected: a 2 px ring in `ink.main` 2 px outside; the six accents and the two neutrals `ink.sec` and `ink.meta` (accent setting, calendar colours, colour card) |

Behaviour settled while building the library (S1), binding for every surface:
- **Controlled inputs.** Switch, Checkbox, Segmented and Slider never write their own value; they
  emit `toggled`/`selected`/`moved` and the owner writes the value back (a Slider shows its own
  value only while dragging). `Field.text` is an alias of the input, so an owner's binding survives
  typing; the caret does not blink; `Ctrl+Backspace` clears.
- **Disabled with a reason.** Button, IconButton and Tile take `disabledReason`: faint, no wash,
  but hover stays so the tooltip says why (`enabled: false` would kill hover).
- **Filled controls** (primary button, an "on" tile or icon button): hover and pressed are
  `onAccent` at the wash amounts over the accent; over `accentWash`, `ink.main` at the hover amount.
- **Tile** content: glyph top-left, label `bodyStrong`, state line `micro` in `ink.meta`; padding
  `padTile` horizontally and `s4` vertically (64 px holds no more). Labels are the short forms of
  the Deck diagram (deck.md §3). Right click opens the page; a disabled tile still opens it.
- **Menu.** Submenus open on click, `Enter` or `→`, never under a passing pointer (05 §4); hover
  moves the current row; `↑ ↓` wrap and skip separators; a checked row ends in an accent `check`; a
  risk row leads with a crit `warning`; key hints are `micro` `ink.meta` text; an inline confirm
  row waits `spotlight.destructiveConfirmMs`. A press outside reaches what is under the pointer,
  then the menu closes; focus returns where it was. Rows have radius 6 (12 − 6, concentric).
- **Tooltip.** Centred below the target, above it when there is no room, `s2` gap, `s4` from the
  window edges; hidden while the target is pressed.
- **List** forwards keys through `navigate(key, modifiers)`, so a surface whose Field keeps the
  focus (Spotlight) drives the list; the highlight follows on `spring.snappy`.
- **Smaller points:** Badge shows "99+" above 99; AppIcon's letter fallback has radius size / 4;
  a selected Thumb has the focus-ring geometry in `accent`; Ellipsis dots stand still.

## 10. Banned patterns

From tacit's list, plus aptus's own:
- accent stripes on the left of selected rows or cards;
- cards with hairline borders;
- small uppercase or letter-spaced labels;
- rows of outlined pills;
- captions that repeat what a button says;
- gradients (except the wallpaper), glows, neon, inner shadows;
- spinners that run while nothing is loading;
- icons without a tooltip or label;
- text over images without a scrim;
- more than one primary button in one surface.
