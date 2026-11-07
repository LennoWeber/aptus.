# Spotlight

## 1. Purpose

One field that reaches everything: apps (and their open windows), files, actions, settings, a
calculator, the clipboard, emoji, quick notes, timers, shell commands and the web. It is the main way
into the shell, so it must open instantly, accept typing from the first frame, and put the right
result first.

## 2. Anatomy

### Empty (no query)

```
                 ────────╮                                                ╭────────     bar
                          ╰──────────────────────────────────────────────╯
                          │ ⌕  Search apps, files, actions…                │   field 52 (sunken, r 12)
                          │                                                │
                          │ ▢    ▢    ▢    ▢    ▢    ▢    ▢    ▢           │   pinned: 8 tiles 64 × 72
                          │ zen  ghostty nemo …                            │   (icon 32, name micro)
                          │                                                │
                          │ ▢  ghostty                  Application  ⌃1   │   recent: 5 rows × 44
                          │ ▤  isolation.md   ~/Code/…/design   File      │
                          │ ◐  Dark mode                   Action         │
                          │ …                                              │
                          │ /  files   :  emoji   v  clipboard   >  run   │   footer 28, keycaps + ink.meta
                          │ +  jot     ?  keys                             │
                          ╰────────────────────────────────────────────────╯
                                         width 640, padding 8
```

### With results and a preview

```
  ╰──────────────────────────────────────────────────────────────────────────────────────╯
  │ ⌕  isol▏                                                                              │
  │ ▤  isolation.md        ~/Code/Projekte/aptus/design   2 h ago   │  # 02 · Session      │
  │ ▤  isolation-test.sh   ~/Code/…/tests                 yesterday │  isolation           │
  │ ◐  Isolation settings  Settings › Isolation                     │  > Umbriel stays…    │
  │ 🌐 Search the web for “isol”                          Web       │                      │
  │ 3 results                         ↵ Open  ⇧↵ Show in folder  ⌃K Actions             │
  ╰─────────────────────────────────────────────────────────────────────────────────────╯
     list 600                                                          preview 320  = 920
```

| Part | Spec |
|---|---|
| Bulge | width 640, or 920 while the result set contains a previewable item (M-11); padding 8 |
| Field | 52 high, `sunken`, radius 12; `search` glyph 20 at 16 px; query in `field` type; placeholder `ink.faint` |
| Scope chip | inside the field before the query when a scope is active: `raised` pill with glyph + "Files" / "Clipboard" / "Emoji" / "Run" / "Jot" / "Keys"; Backspace on an empty query removes it (M-12) |
| Rows | 44 high, radius 8; icon 28; title `bodyStrong` with matched characters in `ink.main` and the rest in `ink.sec`; subtitle `micro` `ink.meta`; trailing: type in `ink.meta`, or a keycap `⌃1`–`⌃9` on the first nine |
| Selection | `current` wash; the first row is selected after every query change |
| Visible rows | 8 (max list height 352), then scrolling; at most 50 results |
| Preview | 320 wide, `raised` card, radius 12, inside the bulge on the right |
| Footer | 28 high: result count left; the selection's actions as keycaps right (`↵ Open`, `⇧↵ …`, `⌃K Actions`) |

## 3. Opening

| Way | Opens |
|---|---|
| `Super` tap, `Super+Space`, `Super+D`, `XF86Dictate` | empty Spotlight |
| `Super+Shift+V` | clipboard scope |
| `Super+period`, `XF86EmojiPicker` | emoji scope |
| typing in the Keys sheet (`Super+K`, [keys-jot.md](keys-jot.md)) | keys scope with the typed text |
| `aptus msg spotlight open [query] [scope]` | with that query and scope |
| Typing `/ : v > + ?` followed by a space (or the prefix alone for `/ : > + ?`) | that scope (see §4) |

The same key again closes it. Opening while another notch mode is open morphs into Spotlight.

## 4. Query grammar

| Typed | Scope | Example |
|---|---|---|
| plain text | everything | `zen`, `isol`, `wifi off`, `12*7` |
| `/` | files | `/ invoice 2026` |
| `:` | emoji and symbols | `:thumbs`, `:arrow` |
| `v ` | clipboard history | `v ssh` |
| `>` | run a shell command | `> btop`, `> claude` |
| `+` | jot a note | `+ call the bank`, `+ [] buy milk` (todo) |
| `?` | keybinds | `? screenshot` |
| `= ` | calculator only | `= 2^32` |
| `ws ` | workspaces | `ws 3`, `ws mail` |
| web shortcut + space | a specific site | `gh quickshell`, `yt lofi`, `w hyprland` (table in settings) |

Plain-text patterns recognised in the everything scope (they produce a top-hit row; nothing happens
until Enter):

| Pattern | Result |
|---|---|
| arithmetic `12*(3+4)`, `2^10`, `sqrt 2`, `15% of 80` | calculator row with the result in `number` type |
| units `5 km in mi`, `20c to f`, `3 gib in mb`, `90 min in h` | conversion row |
| bases `0x1f`, `255 in hex`, `0b1010` | conversion row |
| dates `days until 24 dec`, `today + 90 days`, `week 12` | date row |
| time zones `14:00 in tokyo`, `time in new york` | time row |
| colours `#9acfae`, `rgb(154 207 174)` | colour row with swatch; preview lists hex/rgb/hsl/oklch to copy |
| durations `10m`, `timer 25 min tea`, `alarm 7:30` | timer/alarm row |
| `focus`, `focus 40`, `focus 40 write the spec` | focus session row |
| a URL `https://…`, `github.com/x/y` | open link row |
| a path `~/Code/…`, `/etc/…` | open path row |
| action words (`wifi off`, `dark`, `lock`, `restart`) | the matching action rows |

## 5. Providers

Every provider returns rows of the same shape. "Budget" is the time from keystroke to rows.

| Provider | Finds | Enter | Shift+Enter | Ctrl+Enter | Budget | Data |
|---|---|---|---|---|---|---|
| **Apps** | name, generic name, keywords, executable, aliases (`spotlight.aliases`) | not running: launch; running: focus its most recent window ("Switch to", subtitle "Running · 2 windows") | launch a new instance | open the action menu at the app's desktop actions | 4 ms | `DesktopEntries.applications` (desktop files, refreshed on change) |
| **Windows** | title, class, workspace name | focus (switches workspace) | move it to the current workspace and focus | — (`Ctrl+Delete`: close) | 2 ms | `Hyprland.toplevels` |
| **Actions** | the action catalogue (§5.1) by name and keywords, with arguments | run (destructive: Enter twice) | the action's alternative (e.g. "Focus 50" → choose an intent) | — | 2 ms | built in |
| **Settings** | every setting's label, description, page | open the settings window at it | booleans: toggle inline (the row shows a switch) | — | 3 ms | `settings-schema.json` |
| **Calculator** | §4 patterns | copy the result, close | paste the result into the previous window | copy the expression = result | 5 ms (async) | `aptus-calc` helper (persistent, see §9) |
| **Files** | recent files; then a name search under `files.roots` | open with the default app | show in folder (FileManager1 `ShowItems`) | open with… menu | recent 3 ms; search ≤ 150 ms (async) | `recently-used.xbel`; `plocate`; `fd` fallback |
| **Clipboard** | history entries (scope `v` or `Super+Shift+V`; in everything scope only when the query is ≥ 4 chars and matches text) | copy, close | copy and paste into the previous window | — (`Ctrl+P` pin, `Ctrl+Delete` delete) | 5 ms | `Clipboard` service (§9) |
| **Emoji** | CLDR names and keywords, symbols, kaomoji | type it into the previous window | copy only | choose a skin tone | 3 ms | bundled `emoji.json` |
| **Jot** | `+ text` | append to the inbox file, show "Jotted" event | append and open Today | — | 1 ms | `Jot` service |
| **Timers** | durations, alarms, `stopwatch` | start | start with a label prompt | — | 1 ms | `Timers` service |
| **Commands** | `> cmd`, with history of earlier commands | run in a new terminal window that stays open | run in the background; toast with exit status and the last output line | run in the scratch terminal | 1 ms | command history in frecency store |
| **Workspaces** | `ws`, numbers, names | go | move the focused window there | — | 1 ms | Hyprland |
| **Keys** | `?` and the keybind table | perform the bound action | — | — | 1 ms | `hypr/binds.lua` metadata |
| **Web** | always the last row for queries ≥ 2 characters; web shortcuts | open the search in the browser | copy the search URL | open in a private window | 0 ms | `spotlight.searchEngine`, `spotlight.webShortcuts` |

No provider ever makes a network request while you type.

### 5.1 Action catalogue

| Group | Actions (keywords in brackets) |
|---|---|
| Session | Lock [lock, sperren], Log out [logout, exit], Restart [reboot], Shut down [poweroff, shutdown], Suspend (only if `power.allowSuspend`) |
| Network | Wi-Fi on/off, Bluetooth on/off, Airplane mode, Connect VPN *name*, Disconnect VPN |
| Attention | Do not disturb on/off/for *duration*, Focus *n* [*intent*], Stop focus, Quiet bar |
| Look | Dark mode, Light mode, Auto mode, Accent *name*, Next wallpaper, Wallpaper gallery, Glass on/off |
| Display | Night light on/off, Night light *K*, Brightness *n*, Caffeine on/off (keep awake) |
| Sound | Volume *n*, Mute, Unmute, Mic mute, Output *device*, Input *device* |
| Power | Performance / Balanced / Power saver |
| Capture | Screenshot region / window / screen, Record region / screen, Stop recording, Colour picker |
| Shell | Settings, Settings › *page*, Keys, Restart shell, Reload Hyprland, Doctor (opens a terminal with `aptus doctor`) |
| Windows | Close window, Force quit *window* (risk), Float/Tile, Fullscreen, Rename workspace, Move window to *n* |
| Files | Home, Downloads, Documents, Pictures, Screenshots, Recordings, Empty trash (risk) |

Destructive actions (Log out, Restart, Shut down, Force quit, Empty trash): the first Enter turns the
row into "Press Enter again to restart" with a `warning` glyph in `crit`; a second Enter within 3 s
runs it; anything else cancels.

### 5.2 Action menu (`Ctrl+K` or right click on a row)

A menu anchored to the selected row's right edge listing every action of that result with its key.
Examples:

| Result | Menu |
|---|---|
| App | Open / Switch to, New window, desktop actions (e.g. "New private window"), Pin to Spotlight / Unpin, Hide from results, Show desktop file |
| File | Open, Open with ▸, Show in folder, Copy path, Copy file, Open in terminal (folder), Move to trash (risk) |
| Window | Switch to, Move here, Float/Tile, Close, Force quit (risk) |
| Clipboard entry | Copy, Paste, Pin / Unpin, Delete, Delete all… (risk) |

## 6. Ranking

For each result:

```
score = 100 · match  +  typeBias  +  frecency  +  context
```

- **match** (0–1): exact name 1.0 · name prefix 0.9 · word-start or acronym (`vsc` → *Visual Studio
  Code*) 0.8 · substring 0.6 · fuzzy subsequence 0.3–0.5 (fewer gaps scores higher). Matches on
  keywords/generic name × 0.85; on descriptions or paths × 0.5. Case- and diacritic-insensitive.
- **typeBias**: apps +8, actions +5 (+15 when the query starts with the action's verb: `wifi off`),
  windows +6, settings +2, files 0, clipboard −5, web −1000 (always last); plus 5 × the provider's
  `spotlight.providers.<id>.boost` (−2 … +2).
- **frecency**: what you chose before for this query. For each earlier choice of this result after
  typing a query with the same first two characters: weight `0.5^(age_days / 7)`; boost
  `30 · (1 − e^(−Σ weights))`. A global per-result frecency adds up to +10.
- **context**: windows on the current workspace +2; files used in the last 24 h +5; the running app
  of the focused window −3 (you are already there).

Ties: type order (apps, windows, actions, settings, files, others), then name.

**Stability.** In-memory providers answer synchronously on each keystroke. Slow results (files,
calculator) arriving later than 120 ms after the keystroke may not take the first row and never
reorder rows above the current selection; they insert below it. A selection the user moved by hand
keeps its result even if the list grows around it.

## 7. Preview

Shown for the selected row when it has one; the bulge widens only when the result set has any
previewable row (so moving through results never changes the width).

| Result | Preview |
|---|---|
| Image file, image in clipboard | the image, contained, on `sunken` |
| Text or code file | the first 40 lines in JetBrains Mono `micro`, no highlighting |
| PDF | first-page thumbnail (`pdftoppm` if available, else icon + size) |
| Folder | item count, the first 12 entries |
| Other file | big file-type icon, size, type, modified, path |
| Clipboard text | the full text, wrapped, mono when it looks like code (≥ 2 of: `{};=()` at line ends, leading indentation) |
| Window | live thumbnail (`ScreencopyView`, live only while selected) |
| Colour | large swatch + hex, rgb, hsl, oklch rows; Enter on one copies it |
| Calculator | the expression, the exact result, and the result in other units/bases |

`Space` with a previewable selection enlarges the preview into a 900 × 600 bulge (Quick Look);
`Space` or `Esc` returns.

## 8. Motion

### Open (M-09)

| t (ms) | What happens |
|---|---|
| 0 | the shortcut fires; the layer takes the keyboard **now**, the invisible field already receives keys |
| 0 → 380 | bulge springs from rest to 640 × 68 (`spring.notch`); coves 0 → 14 during 0–120 |
| 0 → 80 | clock, date and compact activities fade out |
| 60 → 220 | search glyph fades in, scale 0.8 → 1 |
| 100 → 260 | placeholder fades in, rising 4 px (skipped if a key was typed) |
| 140 → 300 | empty state: pinned tiles stagger 18 ms apart, then recent rows |
| 300 | caret starts blinking (1.06 s period; solid while typing) |

### Typing
Rows update synchronously; the list height follows with `spring.gentle` (M-10); new rows stagger only
if they were not visible before.

### Close
| t (ms) | What happens |
|---|---|
| 0 | keyboard released; focus returns to the previous window at once |
| 0 → 100 | content fades out |
| 40 → 300 | bulge springs back to rest |
| 180 → 300 | clock and compact activities fade back in |

Launching an app closes Spotlight with the same timeline; the new window maps whenever it is ready.

## 9. Backends

- **`aptus-calc`**: a Python helper (stdlib only) started on the first Spotlight open and kept
  running; JSON lines on stdin/stdout. Safe evaluation via `ast` (numbers, operators, a fixed
  function list), `decimal` for exact results, a units table (length, mass, temperature, data,
  time, speed, area, volume), base conversion, `zoneinfo` for time zones, date arithmetic. Requests
  carry the keystroke's sequence number; stale answers are dropped. No currency (it would need the
  network).
- **Files**: `plocate --ignore-case --limit 200 --basename` restricted to `files.roots`, filtered by
  `files.exclude` and hidden files (unless `files.showHidden`), cancelled (SIGTERM) on the next
  keystroke, debounced 120 ms. When plocate returns fewer than 5 results, `fd --max-depth 6
  --max-results 50` runs over the same roots with a 300 ms timeout. Recent files: GTK's
  `~/.local/share/recently-used.xbel` (shared user data, read only) plus files aptus opened.
- **Clipboard**: `aptus-clipd` (a transient unit bound to the guard) runs
  `wl-paste --watch aptus-clip-store` for text and images. `aptus-clip-store` skips entries offered
  with `x-kde-passwordManagerHint: secret` or from a window class in `clipboard.ignoreClasses`
  (default: KeePassXC, Bitwarden), then stores with
  `cliphist -db-path ~/.local/state/aptus/clipboard.db store`, max `clipboard.maxItems` (500).
  Images are decoded to `~/.cache/aptus/clip/` thumbnails on first preview. Pins live in
  `~/.local/state/aptus/clip-pins.json` (pinned entries are re-stored if cliphist trims them).
- **Paste into the previous window**: Spotlight records the focused window's address when it opens.
  After closing, it waits for that window to regain focus (≤ 150 ms), then sends `Ctrl+V` with
  `wtype` (`Ctrl+Shift+V` for terminal classes in `clipboard.terminalClasses`: kitty, ghostty, foot,
  Alacritty).
- **Launching**: through Hyprland's `exec` dispatcher (so apps are children of Hyprland, inherit its
  scoped environment, and survive a shell restart), wrapped in `systemd-run --user --scope
  --slice=app.slice --unit=app-aptus-<desktop-id>-<random>` when `apps.launchInScopes` is on.
  Terminal apps run as `<terminal> -e <exec>`.
- **Frecency store**: `~/.local/state/aptus/frecency.json`
  `{ "v": 1, "results": { "<id>": [t1, t2, …] }, "prefixes": { "<2 chars>": { "<id>": [t…] } } }`,
  keeping the last 20 timestamps per entry and dropping entries older than 90 days; written 2 s after
  the last change (atomic).

## 10. Edge cases

| Case | Behaviour |
|---|---|
| No results | one row "No results for “xyz”" (`ink.meta`, not selectable), then "Search files for “xyz”" (switches to the files scope), then the web row |
| A pasted multi-line or > 200 character query | only calculator (if it parses), "Jot this", and web |
| plocate missing or its database older than 7 days | file search uses fd only; `aptus doctor` reports it |
| A desktop file changes while open | the apps index rebuilds in the background; results update on the next keystroke |
| The previous window closed before paste | copy only, event "Copied" |
| Opened over a fullscreen window | Spotlight shows on the overlay layer; the bar stays hidden |
| A second monitor | opens on the active monitor; moving focus to the other monitor while open closes it |
| `Enter` before results exist (typed fast) | runs the first result of the final query once it is computed (≤ 16 ms) |

## 11. Settings

`spotlight.superTap`, `spotlight.pinned`, `spotlight.aliases`, `spotlight.searchEngine`,
`spotlight.webShortcuts`, `spotlight.providers.*`, `spotlight.preview`, `files.roots`,
`files.exclude`, `files.showHidden`, `clipboard.maxItems`, `clipboard.ignoreClasses`,
`clipboard.terminalClasses`, `apps.launchInScopes`, `power.allowSuspend`. Defaults in
[10-settings.md](../10-settings.md).
