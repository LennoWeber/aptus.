# Settings window

## 1. Purpose

Every setting in one searchable place, applied the moment it changes. No Save button, no restart
prompts, and nothing that can only be changed by editing a file (editing the file still works).

## 2. Window

- A real window, not a layer: Quickshell `FloatingWindow`, Wayland app id `aptus-settings`, title
  "aptus Settings". Hyprland rule: floating, 920 × 640, centred on the active monitor, min 720 × 480
  ([09-hyprland.md](../09-hyprland.md) §5). It is a window so it can sit beside the app being
  tuned, be moved to another workspace, and show in the switcher.
- One instance. `Super+S` / `Super+comma`: not open → open; open but not focused → focus it (and
  bring its workspace); focused → close.
- Closes with `Ctrl+W`, `Super+Q`, or `Esc` when no field has the keyboard and no menu is open.
- It draws its own chrome (no title bar; Hyprland has none): the sidebar top doubles as a drag area
  (`Super+LMB` works too).

```
┌────────────────────┬───────────────────────────────────────────────────────────────┐
│ ⌕ Search settings  │ Appearance                                                    │  heading 22
│                    │                                                               │
│ ◐ Appearance     ◀ │ Mode            [ Dark | Light | Auto ]                       │  rows 44, label left,
│ ▭ Bar & frame      │                 Auto follows the night-light schedule         │  control right,
│ ⬭ Notch & alerts   │ Accent          ● ● ● ● ● ● ◌                                 │  description under
│ ⌕ Spotlight        │                 jade                                          │  the label (meta)
│ ▦ Today & calendar │ Glass           ○──                                           │
│ ◎ Focus            │ Text size       [ 100 % | 110 % | 125 % ]                     │
│ ⎙ Capture          │ Contrast        [ Normal | High ]                             │
│ ♪ Sound & display  │ Reduce motion   [ Auto | On | Off ]                           │
│ ⏻ Power & session  │ ──────────────────────────────────────────────                │
│ ⌨ Keys             │ Wallpaper       ▣ forest.jpg      Change…  Fill ▾             │
│ ⇄ Apps & isolation │                                                               │
│ ⓘ About            │                                                               │
└────────────────────┴───────────────────────────────────────────────────────────────┘
  sidebar 220, ground                 content: raised sections on ground, padding 24, max line 640
```

## 3. Pages

| Page | Sections and settings |
|---|---|
| **Appearance** | mode, accent (six swatches + `wallpaper`), glass, text size, contrast, reduce motion; wallpaper (thumbnail, *Change…* opens the gallery, fill mode, rotation, folder) |
| **Bar & frame** | frame edges on/off, workspaces (shown, icons), window title, clock (date), tray (max, order by drag, hidden apps, monitor), battery %, Bluetooth item; Deck (which tiles and their order, open pages directly) |
| **Notch & alerts** | toast timeout, stack window, over-fullscreen policy, hover expand, allowlist (app picker), media players to ignore, history days/max, *Send test notification* |
| **Spotlight** | Super tap, providers (switch and ranking boost per provider), pinned results, aliases (two-column editor), search engine, web shortcuts (editor), preview pane, file roots and excludes, hidden files, clipboard size and ignored apps, launch in scopes |
| **Today & calendar** | calendars (§5), reminder lead time, refresh interval, week numbers, weather location (search) and units, jot file |
| **Focus** | durations, default, break length, auto break, sound, daily goal, end for meetings, quiet bar, DND schedule |
| **Capture** | folders, copy, countdown, record audio, colour format, include shell, file name pattern (live example) |
| **Sound & display** | volume step, allow boost, brightness step, night light (temperature, schedule, location shared with mode `auto`) |
| **Power & session** | dim / lock / screen off timings, screen off while locked, lid action, lid docked, allow suspend, close timeout, lock screen (notification count, media, fingerprint) |
| **Keys** | §6 |
| **Apps & isolation** | §7 |
| **About** | version and git commit, Quickshell/Hyprland versions, *Restart shell*, *Open logs*, *Open config folder*, *Run doctor*, *Replay intro* |

Every row: label (`bodyStrong`), one-line description (`body`, `ink.meta`), the control on the
right. A row whose value differs from the default shows a quiet `restart_alt` icon button (tooltip
"Reset to default · jade") just left of the control. Sections end with nothing; pages end with a
quiet "Reset this page…" (risk, confirms inline).

## 4. Behaviour

- **Live apply.** Every change goes to the `Config` service at once; the shell reacts within a
  frame. Persisting is debounced 300 ms and atomic (temp + rename) into
  `~/.config/aptus/settings.json`, which stores **only values that differ from the defaults**, so
  defaults can improve later without migrations.
- **Undo.** `Ctrl+Z` / `Ctrl+Shift+Z` walk a 50-step history of this window's changes; a toast-free
  footer line "Changed Accent · Undo" shows for 4 s after each change.
- **Search** (`Ctrl+F` or just typing while the sidebar has focus): matches labels, descriptions and
  keywords from the schema; results replace the content area as rows "Page › Section › Setting";
  `Enter` jumps there, scrolls the row to the upper third and pulses it with the `hover` wash
  (600 ms). Spotlight's Settings provider opens the window at the same spot.
- **Hand edits.** `settings.json` is watched; external edits apply live. Unknown keys are kept
  (never deleted) and listed under About › "Unknown keys". Invalid values fall back to the default
  for that key only, with one toast ("settings.json: bar.tray.max must be 0–6 — using 3").
  A file that is not valid JSON is ignored as a whole (the last good values stay) with a toast that
  names the line and column; the window shows a banner with *Open file*.
- **Keyboard.** `↑ ↓` in the sidebar change page; `Tab` moves into the content; inside, `Tab` walks
  controls, `Space` toggles, `← →` move segmented controls and sliders; `Ctrl+1…9` jump to pages.

## 5. Calendars editor

A list of sources: colour dot (menu of the six accents and the two neutrals `ink.sec` and `ink.meta`), name, kind (URL or file),
the address shown masked (`https://calendar.google.com/…/basic.ics` → host + "…"), an eye to reveal,
last sync status ("Synced 2 min ago · 41 events", "Failed: 401 Unauthorized"), and a ⋯ menu (Edit,
Sync now, Remove (risk)). *Add calendar* expands a form: name, URL or *Choose file…*, colour, and
*Test*, which fetches once through `aptus-agenda --test` and reports the event count or the error
before saving. Writes `~/.config/aptus/calendars.json` with mode 0600.

## 6. Keys page

- The bind table from `hyprctl binds -j`, grouped by the group in each bind's description
  ([09-hyprland.md](../09-hyprland.md) §7): description, keycaps, and an edit (✎) button.
- **Edit** turns the keycaps into "Press a shortcut…"; the window grabs the next chord (modifiers +
  key, `Esc` cancels, `Backspace` removes the bind). A conflict with another bind shows inline:
  "Super+B is Browser — Replace / Cancel".
- Changes are written to `~/.local/state/aptus/hypr/binds.local.lua` (a generated table of
  overrides that `binds.lua` applies last), then `hyprctl reload config-only`. Lenno's own binds
  outside the aptus block are shown read-only with "Defined in hyprland.lua".
- *Reset all keys* (risk) deletes the overrides file.

## 7. Apps & isolation page

- **Status line:** "Lease held since 09:12 · 31 slots · generation 37" (or "Scope-only: another
  session is open", or "Released").
- **Targets table:** every row of [02-isolation.md](../02-isolation.md) §4 that exists on this
  machine: app, mechanism chip (Leased, Scoped, Own, Baked, Stays Noctalia, Not covered), state
  ("Applied", "Next start", "Not installed"), and *Reload* where a hook exists.
- **Bake opt-ins** (Spotify, LibreOffice): switches, each with the explanation "Changes this app in
  Umbriel too until you switch back" and the condition "Spotify must be closed".
- **Coverage:** Noctalia templates without an aptus renderer, if any, with "These apps keep
  Noctalia's colours in Hyprland".
- *Run doctor* shows `aptus doctor` output inline (monospace, scrollable); *Re-render apps* runs the
  renderer and every hook; *Show journal* opens `journal.json` read-only.

## 8. Data

`Config` service ([07-architecture.md](../07-architecture.md) §6) with the schema
`shell/config/settings-schema.json`: for each key its type, default, range or enum (with labels),
page, section, label, description, keywords, and `visibleIf` (e.g. `power.lidDocked` only when
`power.lidAction = lock`). The settings window is generated from the schema; only the calendars
editor, the keys page, the isolation page and the wallpaper row are hand-built.

## 9. Edge cases

- The window is open when the shell restarts: it closes with the shell and is reopened at the same
  page (`~/.local/state/aptus/ui.json`).
- Two edits racing (a hand edit while the window has unsaved debounce): the window's change wins
  for the keys it changed; other keys take the file's values.
- A setting that needs Hyprland (gaps follow `frame.edge`, border colours follow the accent):
  applied at once with `hyprctl eval 'hl.config({…})'`, and persisted in the generated
  `~/.local/state/aptus/hypr/generated.lua`, which the aptus block loads at the next start
  ([09-hyprland.md](../09-hyprland.md) §2).
