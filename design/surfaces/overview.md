# Switcher, overview and the scratch terminal

## 1. Switcher (`Alt+Tab`)

### Purpose
Jump between recently used windows without thinking about workspaces.

### Behaviour

| Input | Result |
|---|---|
| `Alt+Tab` pressed and Alt released within 150 ms | focus the previous window (MRU position 2) with **no UI** |
| `Alt+Tab` held longer than 150 ms | the switcher appears with position 2 selected |
| `Tab` / `Shift+Tab` (Alt held) | next / previous card |
| `←` / `→` (Alt held) | same |
| `` Alt+` `` (`Alt+^` on German layout) | cycle only windows of the selected card's app |
| `Q` (Alt held) | close the selected window; the card leaves (M-21 style), selection moves right |
| `Esc` (Alt held) | cancel, focus stays |
| Release Alt | focus the selected window (switching workspace/monitor as needed) |
| Pointer click on a card | focus it, close the switcher |

MRU order is kept by aptus from Hyprland `activewindowv2` events (the newest first), across all
workspaces of the **current monitor** (`switcher.scope`: `monitor` default | `all`). Windows in the
scratch workspace are included with a `terminal` badge.

### Anatomy

```
 ────╮                                                                      ╭────
     ╰──────────────────────────────────────────────────────────────────────╯
     │ ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
     │ │ thumb    │  │ thumb    │  │ thumb    │  │ thumb    │  │ thumb    │ │   cards 176 × 140
     │ │ 160 × 96 │  │          │  │          │  │          │  │          │ │   thumbnail 160 × 96, r 8
     │ └──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘ │
     │  ▢ zen         ▢ ghostty     ▢ nemo        ▢ zen         ▢ kitty      │   icon 20 + app (bodyStrong)
     │  Design rev…   ~/C/aptus     Downloads     Mail – …      btop         │   title (micro, ink.meta)
     ╰──────────────────────────────────────────────────────────────────────╯
```

- Bulge width = cards × 184 + 16, at most 1400; beyond that the strip scrolls so the selection stays
  centred.
- Selected card: `current` wash, thumbnail lifts 2 px; workspace number badge (`micro`) at the
  thumbnail's top-left on every card when windows span workspaces.
- Thumbnails: `ScreencopyView` of the toplevel, captured once when the switcher opens (not live) to
  keep it light (probe P-09); minimised/hidden windows show the app icon on `raised`.

### Implementation of Alt
Hyprland binds `ALT, Tab` → `global aptus:switcher-next` and `ALT SHIFT, Tab` →
`global aptus:switcher-prev`, and a release bind on `Alt_L` → `global aptus:switcher-commit`. The
shell measures the 150 ms threshold itself. While the switcher is visible it also holds the keyboard
so `Q`, `Esc` and arrows reach it (probe P-10).

### Motion
M-13: the bulge grows with `spring.notch`; cards stagger 15 ms; the selection wash moves with
`spring.snappy`. Commit: the bulge collapses (`exit`) while Hyprland focuses the window.

## 2. Overview (`Super+Tab`)

### Purpose
See every workspace of this monitor with its windows, find a window by typing, move windows between
workspaces, name workspaces.

### Anatomy

```
 ┌───────────────────────────────────────────────────────────────────────────────────────────┐
 │ [▣] (1)(2)(3)(5)   …                          14:32                         status       │ bar
 │╭─────────────────────────────────────────────────────────────────────────────────────────╮│
 ││  ⌕ Type to find a window…                                                              ││ field 40, centred, 480 wide
 ││                                                                                         ││
 ││  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐  ┌──────┐  ││ workspace cards 16:9
 ││  │ ▭▭  ▭         │  │ ▭▭▭           │  │               │  │ ▭      ▭▭     │  │  +   │  ││ 304 × 171 (scale ≈ 0.16)
 ││  │ ▭▭            │  │               │  │   (empty)     │  │               │  │      │  ││ windows drawn at their real
 ││  └───────────────┘  └───────────────┘  └───────────────┘  └───────────────┘  └──────┘  ││ positions, live thumbnails
 ││   1 · Code          2 · Web            3                  5 · Mail           new        ││ number · name (bodyStrong)
 │╰─────────────────────────────────────────────────────────────────────────────────────────╯│
```

- The bar's lower edge drops to 330 px across the whole monitor width; the workspace pills morph
  into the cards (M-14, shared elements).
- Cards: used workspaces of this monitor plus the active one, in id order, then one "new" card. Card
  size: 304 × 171 at 1920 px (monitor aspect × 0.158), 16 px apart; more than 5 cards scroll
  horizontally with the selected card kept visible.
- Inside a card, each window is drawn at its real position and size × the card scale, as a live
  `ScreencopyView` (live while the overview is open, probe P-09) with radius 10 × scale (min 4).
  Floating windows above tiled ones, as on screen.
- The active workspace's card has a 2 px accent ring; the focused window inside it a 1.5 px accent
  ring.

### Interactions

| Input | Action |
|---|---|
| Typing | filters windows by title, class, workspace name: non-matching windows dim to 25 %, matching ones get a ring; cards with no match dim; the first match is selected |
| `← →` | previous/next card |
| `↑ ↓` | move between windows inside the selected card (in reading order) |
| `Enter` | go to the selected window (or card), close the overview |
| `Shift+Enter` | move the focused window to the selected card's workspace |
| `F2` | rename the selected workspace: the label becomes a field; Enter saves, Esc cancels; empty removes the name |
| `Ctrl+Delete`, middle click on a window | close that window |
| `1`–`0` (no text typed yet) | go to that workspace |
| Click a card / window | go there |
| Drag a window onto another card | move it there (M-15); onto "new": move it to the first free workspace of this monitor |
| Drag a card | not supported (workspace ids are fixed by Lenno's binds) |
| `Esc`, `Super+Tab`, click on the dimmed area below | close |

### Motion
M-14 open: the bar edge drops (`spring.notch`), pills grow into cards, thumbnails fade in from 80 ms,
the field fades in at 120 ms. Close: the reverse; the selected card shrinks back into its pill.

### Data
`Hyprland.workspaces`, `Hyprland.toplevels` with their `lastIpcObject` geometry (`at`, `size`,
`floating`, `workspace`), refreshed on `openwindow`, `closewindow`, `movewindowv2`,
`changefloatingmode`, and `windowtitlev2` events, and once on open via `hyprctl clients -j`.
Workspace names: `~/.local/state/aptus/workspaces.json`, applied with `renameworkspace`.

### Edge cases
- 10 used workspaces on one monitor: horizontal scroll, selection kept centred.
- A window on a workspace of another monitor is not shown (that monitor's overview shows it); window
  search with no match here offers "3 matches on DP-1" (Enter jumps there).
- A fullscreen window: drawn filling its card, with a `fullscreen` badge.
- Thumbnail capture failing (protocol missing): app icon centred on the window's rectangle.

## 3. Scratch terminal (`Super+minus`)

Hyprland's special workspace `scratch`, styled by aptus:

- `Super+minus` toggles it; the first time it starts the terminal in it (`ghostty --class=aptus.scratch`).
- Window rule: floating, 70 % × 60 % of the monitor, centred horizontally, its top edge 8 px below
  the bar, so it reads as dropping out of the bar (animation `specialWorkspace`, slide down).
- `Super+Shift+minus` sends the focused window to `scratch`; the bar shows the scratch pill while it
  has windows ([bar.md](bar.md) §3).
- Spotlight's Ctrl+Enter on a command runs it in the scratch terminal.
