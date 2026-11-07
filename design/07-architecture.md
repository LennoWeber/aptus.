# 07 · Architecture

## 1. Shape of the system

```
                      ┌──────────────────────────── Hyprland session ────────────────────────────┐
 greetd → start-hyprland → Hyprland ── hl.on("hyprland.start") ──► aptus-session start           │
                      │                                              │ 1 recover  2 render        │
                      │                                              │ 3 lease    4 env import    │
                      │                                              │ 5 units    6 exec ↓         │
                      │                                       aptus-supervise ──► qs (the shell)  │
                      │                                                            │ children:    │
                      │                                                            ├ aptus-calc   │
                      │                                                            ├ aptus-agenda │
                      │  apps (launched via Hyprland exec, in app-*.scope)         └ satty, …     │
                      └────────────────────────────────────────────────────────────────────────────┘
 systemd --user:  aptus-guard (transient)  ─ BindsTo ─►  aptus-clipd, aptus-sunset, aptus-lid,
                                                          aptus-rec (while recording)
                  aptus-recover.service (installed, oneshot at user-manager start)
```

Three layers of software:

| Layer | Language | What lives there |
|---|---|---|
| **Shell** | QML on Quickshell 0.3.2 / Qt 6.11 | everything you see, the surface manager, live services, IPC |
| **Session tools** | Python 3 (system interpreter, stdlib + `python3-icalendar`, `python3-dateutil`) | `aptus-session`, `aptus-guard`, `aptus-lease`, `aptus-theme`, `aptus-agenda`, `aptus-calc`, `aptus-clip-store`, `aptus doctor` |
| **Compositor config** | Lua (Hyprland 0.57) | `hypr/*.lua`: look, motion, rules, binds, environment, autostart |

Rules: the shell never writes a leased slot itself (only `aptus-theme` + `aptus-lease` do, under the
flock); session tools never draw anything; Lua never contains colours by hand (it loads the generated
file).

## 2. Repository layout (v2)

```
aptus/
├─ README.md  CLAUDE.md  PHASES.md
├─ design/                      this specification
├─ bin/
│  ├─ aptus                     CLI: msg, doctor, logs, theme, lease, dev, version
│  ├─ aptus-session             start | stop (called by Hyprland and the logout path)
│  ├─ aptus-guard               watches Hyprland's pidfd, releases the lease
│  ├─ aptus-lease               take | update | release | recover | status
│  ├─ aptus-theme               render | apply | targets
│  ├─ aptus-supervise           runs and restarts the shell
│  ├─ aptus-agenda              sync | test (ICS → agenda.json)
│  ├─ aptus-calc                JSON-lines calculator (persistent child of the shell)
│  └─ aptus-clip-store          filter + store one clipboard entry
├─ lib/aptus/                   Python package shared by the tools
│  ├─ paths.py  atomic.py  log.py  hypr.py (IPC socket client)  dbusmin.py
│  ├─ lease/  (journal.py, slots.py, kinds/{file,ini,dconf}.py, recover.py)
│  ├─ theme/  (palette.py, resolve.py, render.py, hooks.py, targets.py)
│  ├─ agenda/ (fetch.py, expand.py)
│  ├─ calc/   (evaluate.py, units.py, dates.py)
│  └─ doctor/ (isolation.py, deps.py, config.py)
├─ shell/                       qs -p shell
│  ├─ shell.qml                 root: ShellRoot, Variants over Quickshell.screens → MonitorShell
│  ├─ core/                     Tokens, Motion, Config, Paths, Log, Format, SurfaceManager, MonitorState,
│  │                            js/ (pure logic: rules, config, colour, resolve, format, bulge, sun)
│  ├─ components/               Bulge (frame/cove path), BulgeSpec, NotchMode, Drawer, Activity, ListRow,
│  │                            List, Button, IconButton, Tile, Slider, Switch, Segmented, Checkbox, Field,
│  │                            Keycap, Ring, Level, Menu, MenuHost, Tooltip, Badge, EmptyState, Glyph,
│  │                            Label, Wash, FocusRing, AppIcon, Thumb, Scrim, RollingDigits, Ellipsis,
│  │                            ErrorLine, PagerDots, Swatch
│  ├─ services/                 one singleton per data source (§6)
│  ├─ surfaces/<name>/          one folder (QML module qs.surfaces.<name>) per surface, owned by one
│  │                            stage: frame, wallpaper, bar, notch (rest, compact, toast, osd, event,
│  │                            card host), spotlight, switcher (SwitcherStrip), overview, deck (+ pages),
│  │                            today, focus, capture, lock (+ veil), session, polkit, gallery, settings
│  │                            (SettingsWindow), keys (KeysSheet), jot (JotSheet)
│  ├─ registry/                 Shortcuts, Ipc, NotchModes, Activities: the id → handler/component tables
│  ├─ windows/                  MonitorShell.qml (the layers of one monitor)
│  ├─ config/                   settings-schema.json, known-binds.json
│  └─ assets/                   fonts/MaterialSymbolsRounded.ttf, emoji.json, sounds/*.oga, icons/
├─ theme/
│  ├─ tokens.json               every token of 03-visual-language (the single source)
│  ├─ targets.toml              the target manifest (08 §4)
│  └─ templates/<target>/…      one template per app target
├─ hypr/                        symlinked to ~/.config/hypr/aptus
│  └─ init.lua env.lua look.lua motion.lua rules.lua binds.lua
├─ systemd/aptus-recover.service
├─ install.sh
└─ tests/  unit/  golden/  e2e/  perf/
```

Every path the code uses comes from `paths.py` / `Paths.qml`, which resolve the XDG base
directories once.

QML module order (no import cycles): `core` ← `components` ← `services` ← `surfaces` ← `registry` ←
`windows` ← `shell.qml`. Core gets service data through `Binding`s in `shell.qml`; a surface never
imports the registry (the notch receives its mode and activity components as properties). Names are
chosen so that nothing hides a QtQuick type (`ListRow`, the `Binds` service): `QtQuick.Controls`, if
ever needed, is imported only with a namespace (`import QtQuick.Controls as QQC`).

## 3. Startup

### Sequence and budget

| t (ms, from `hyprland.start`) | Step | Budget | On failure |
|---|---|---|---|
| 0 | `aptus-session start` checks `XDG_CURRENT_DESKTOP=Hyprland` and `HYPRLAND_INSTANCE_SIGNATURE`; else exits 0 | 5 | — |
| 5 | `aptus-lease recover` | 50 | log, continue |
| 55 | `aptus-theme render` (skipped when the input hash is unchanged: tokens + theme settings + accent + mode + template versions) | 300 (cold) / 10 | keep the last good generation |
| 60–360 | `aptus-lease take` (preflight, Noctalia-running check) | 150 | scope-only mode |
| ≤ 510 | `systemctl --user import-environment …` | 30 | log |
| ≤ 540 | `systemd-run` the guard and its bound units | 60 | the shell shows a warning event; theming still works, release then happens at the next login via recover |
| ≤ 600 | `exec aptus-supervise` → `qs -p shell` | — | — |
| ≤ 1100 | the shell's first frame on every monitor, then M-01 | 500 | supervisor (§10) |

Hyprland's own background colour is `ground` (from the generated Lua), so the half second before
the shell's first frame shows the frame colour, not black.

### Shell start order (inside QML)
1. `Config` loads defaults from the schema, then `settings.json`; `Tokens` resolves the palette.
2. `MonitorShell` per screen creates its layers (§4) hidden.
3. Services start lazily on first use, except `Hypr`, `Notifications` (must own the bus name
   before apps send), `Shortcuts`, `Ipc`, `Idle`, `Session` (lock state), `Wallpaper`.
4. If `~/.local/state/aptus/locked` exists: lock immediately (crash restore), no intro.
5. Otherwise, the first start of a Hyprland session (`intro.played` flag in
   `$XDG_RUNTIME_DIR/aptus/` for this Hyprland signature is missing) plays M-01; restarts don't.

## 4. Windows per monitor

| Namespace | Layer | Size | Exclusive zone | Keyboard | Input | Purpose |
|---|---|---|---|---|---|---|
| `aptus-wallpaper` | Background | monitor | −1 | none | none | the wallpaper |
| `aptus-reserve` | Top | full width × `bar.height` | `bar.height` | none | none (empty mask) | reserves the bar's space; left/right/bottom frame space is Hyprland's `gaps_out` |
| `aptus-shell` | Overlay | monitor | −1 | none ↔ exclusive | mask: bar + open surfaces; whole monitor while an interactive surface is open (away catcher); a 2 px top strip under a fullscreen window | frame, bar, notch and every drawer, menu, toast, OSD, capture overlay |
| `aptus-veil` | Overlay (above `aptus-shell`) | monitor | −1 | none | none | the unlock handover; created for the unlock, destroyed after |
| `aptus-recframe` | Overlay | monitor | −1 | none | none | the crit frame around a region recording |
| session lock surface | lock | monitor | — | lock | all | lock screen |
| `aptus-settings` | (a window) | 920 × 640 | — | normal | normal | settings |

Why one big Overlay layer: the frame and every drawer are one painted shape; surfaces never resize
their layer (tacit rule, [04-motion.md](04-motion.md) §8); Overlay is above fullscreen windows, so
the fullscreen hot edge, critical toasts and Spotlight work over a fullscreen app; menus are drawn
inside it (via `QsMenuOpener` for tray menus), so they look like the rest of the shell.

Hyprland layer rules for these namespaces: `no_anim` on all; `blur` + `ignore_alpha 0.5` on
`aptus-shell` only when glass is on; `above_lock` never; `no_screen_share` on `aptus-recframe`
([09-hyprland.md](09-hyprland.md) §5).

## 5. Surface manager

`SurfaceManager` (singleton) holds one state record per monitor and is the only code that opens or
closes anything.

```
MonitorState {
  notch:     "rest" | "spotlight" | "switcher" | "today" | "session" | "polkit"
             | "gallery" | "jot" | "keys" | "keysPeek" | "focusPicker" | "card:<activity>"
  passive:   queue of { id, kind: toast|osd|event, payload, priority, born }
  deck:      { open: bool, pages: [ "main", "wifi", … ] }
  overview:  bool
  menu:      null | { anchor, model, owner }
  capture:   null | { mode: region|screen|window|record|colour, args }   (the frozen frames live in
             the capture overlay, not in the state)
  fullscreen: bool          (from Hyprland events, per monitor)
  locked:    bool           (session-wide)
}
```

API (also exposed over IPC): `open(surface, args)`, `close(surface)`, `toggle(surface, args)`,
`back()` (the Esc ladder, [05-interaction.md](05-interaction.md) §3), `post(kind, payload,
priority)` for passive content, `state()`.

Transition rules (enforced here, not in surfaces):

| Request | When | Result |
|---|---|---|
| open a notch mode | another notch mode is open | morph (one timeline from A's shape to B's) |
| open a notch mode | the Deck is open | Deck closes (exit), notch mode opens (hero) |
| open the Deck | an interactive notch mode is open | that mode closes, Deck opens |
| open Overview | anything | everything else closes first (exit timelines run concurrently) |
| open anything | locked | refused, except media keys/OSD, which render on the lock surface |
| open anything except polkit | polkit open | queued until polkit closes |
| post a toast | an interactive notch mode is open | queued; shown on close if younger than 30 s, else Today only |
| post an OSD | anything | OSD wins over toasts (toast pauses its timer and resumes) |
| monitor removed | surfaces open on it | closed without animation |
| active monitor changes | a notch mode open on the old one | closed (Spotlight rule); passive content stays |

Cards and the Keys peek are notch states but not *interactive* surfaces: they do not queue toasts
or catch outside clicks, and a pinned card yields to OSD, toasts and events (arbitration of
[notch.md](surfaces/notch.md) §9). A card opened by click takes the keyboard (for `Tab`, `←/→` and
its buttons); one opened by hover does not.

Keyboard: when an interactive surface opens, `aptus-shell` on that monitor switches to
`keyboardFocus: Exclusive`; on close back to `None`, and Hyprland returns focus to the window that
had it. The manager records the previously focused window address for paste-back and for the away
catcher's focus replay.

## 6. Services

Singletons in `shell/services/`. Each exposes properties (bindable) and methods; none touches the UI.

| Service | Responsibility | Source | Updates |
|---|---|---|---|
| `Hypr` | monitors, workspaces, toplevels, active window, fullscreen, urgent, special, submap | `Quickshell.Hyprland` + `rawEvent` | events |
| `Switcher` | Alt+Tab MRU order, threshold, commit | `Hypr` | events |
| `Progress` | progress activities (downloads, copies) from notification hints | `Notifications` | events |
| `Apps` | desktop entries, icons, running-app lookup | `DesktopEntries` | on change |
| `Audio` | sinks, sources, streams, volumes, mute | `Quickshell.Services.Pipewire` | events |
| `Brightness` | eDP-1 backlight, keyboard LED if present | `/sys/class/backlight/*` (FileView watch), `brightnessctl` to write | events |
| `NightLight` | temperature, schedule, sun times | `hyprsunset` via `hyprctl hyprsunset`; sunrise/sunset computed locally from `weather.location` (NOAA formula) | minute tick while scheduled |
| `Network` | devices, Wi-Fi list, connect, VPN | `Quickshell.Networking` (P-13), `nmcli` | events |
| `Bt` | adapter, devices, pairing | `Quickshell.Bluetooth` | events |
| `Power` | battery, power profile | `Quickshell.Services.UPower`, `powerprofilesctl` | events |
| `Media` | players, the active player rule | `Quickshell.Services.Mpris` | events |
| `Notifications` | server, toasts, history, held queue, interruption policy | `Quickshell.Services.Notifications` | events |
| `Clipboard` | history, pins, paste-back | `cliphist -db-path …`, `wl-copy`, `wtype` | on open + `aptus-clipd` signal file |
| `Agenda` | events, reminders, meeting links | `agenda.json` (FileView), runs `aptus-agenda sync` every `calendar.refreshMinutes` | file change |
| `Weather` | current, 12 h, notable change | Open-Meteo forecast API, only when `weather.location` is set, every 30 min; cache `~/.cache/aptus/weather.json` | timer |
| `Focus` | focus state machine, log, stats | `focus.json`, `focus-log.jsonl` | 1 Hz while running |
| `Dnd` | modes, schedule, summary | `dnd.json` | events |
| `Timers` | timers, alarms, stopwatch | `timers.json` (absolute end times) | 1 Hz while any runs |
| `Capture` | freeze, crop, save, record, colour | `ScreencopyView`, `grabToImage`, `wf-recorder` unit | on demand |
| `Wallpaper` | resolution, thumbnails, analysis, rotation | `wallpaper.json`, `FolderListModel` | events |
| `Theme` | mode, accent, glass, auto schedule, render requests | `Config`, `NightLight` sun times; runs `aptus-theme apply` | on change |
| `Idle` | dim, lock, screen off, keep awake | `IdleMonitor`, `IdleInhibitor`, `systemd-inhibit` | events |
| `Session` | lock state, PAM, fingerprint, logout path, polkit agent, lid (logind inhibitor) | `WlSessionLock`, `PamContext`, `PolkitAgent`, logind D-Bus | events |
| `Privacy` | mic, camera, screencast in use | Pipewire nodes, Hyprland `screencast` | events |
| `Binds` | bind table, descriptions, overrides (`binds.local.lua`), conflicts | `hyprctl binds -j`, `shell/config/known-binds.json` | `config.reloaded` |
| `Jot` | inbox read/append/edit | `jot.file` (FileView) | file change |
| `Frecency` | launch history, ranking | `frecency.json` | on use |
| `Files` | recent files, search | `recently-used.xbel`, `plocate`, `fd` | on query |
| `Calc` | the persistent `aptus-calc` child | `Process` with stdin/stdout | on query |
| `Lease` | isolation status for the bar's warning and the settings page | `lease/journal.json` (FileView, read-only) | file change |

Network use, complete list: Open-Meteo forecast (only with a location), Open-Meteo geocoding (only
while searching a location in settings), calendar URLs Lenno added. Nothing else ever leaves the
machine.

## 7. IPC

### Global shortcuts
Quickshell `GlobalShortcut { appid: "aptus"; name: … }`; Hyprland binds `hl.dsp.global("aptus:<name>")`.

| Name | Does |
|---|---|
| `spotlight`, `spotlight-clipboard`, `spotlight-emoji` | open/toggle Spotlight (plain / scope) |
| `super-tap`, `keys-peek` | Super released alone (opens Spotlight, or ends a peek) / Super held 1 s ([keys-jot.md](surfaces/keys-jot.md) §1) |
| `overview`, `overview-open`, `overview-close` | toggle / open / close Overview (the last two for touchpad gestures) |
| `switcher-next`, `switcher-prev`, `switcher-commit` | Alt+Tab ([overview.md](surfaces/overview.md) §1) |
| `deck`, `today`, `jot`, `keys`, `gallery`, `session`, `settings` | toggle that surface |
| `lock`, `logout` | lock; graceful logout without countdown |
| `theme-toggle` | light ↔ dark (explicit) |
| `focus`, `dnd`, `quiet-bar` | as in [focus.md](surfaces/focus.md) |
| `capture-region`, `capture-screen`, `record`, `colour` | capture modes |
| `vol-up`, `vol-down`, `vol-up-fine`, `vol-down-fine`, `mute`, `mic-mute` | audio + OSD |
| `bright-up`, `bright-down`, `bright-up-fine`, `bright-down-fine` | backlight + OSD |
| `kbd-up`, `kbd-down`, `kbd-toggle` | keyboard light + OSD (inert without an LED) |
| `media-toggle`, `media-next`, `media-prev` | the active player |

### `aptus msg`
`aptus msg <target> <function> [args…]` wraps `qs -p <repo>/shell ipc call …` (Quickshell
`IpcHandler`s). It is the fallback for every shortcut (probe P-01) and the scripting surface:

| Target | Functions |
|---|---|
| `shell` | `state` (JSON of every MonitorState and service summary, for tests), `restart`, `reloadConfig`, `log <level>` |
| `surface` | `open <name> [json-args]`, `close <name>`, `toggle <name>`, `back` |
| `spotlight` | `open [query] [scope]` |
| `notch` | `event <text> [glyph]`, `toast <json>` (test only, through the real policy) |
| `theme` | `mode dark|light|auto|toggle`, `accent <name>`, `glass on|off` |
| `wallpaper` | `set <path> [monitor]`, `next` |
| `focus` | `start <minutes> [intent]`, `stop`, `pause`, `resume`, `extend <minutes>` |
| `dnd` | `on`, `off`, `for <duration>` (the handler function is `forDuration`, since `for` is reserved in JavaScript; `aptus msg` maps the name), `until <HH:MM>` |
| `capture` | `region`, `screen`, `window`, `record`, `stop`, `colour` |
| `session` | `lock`, `logout`, `reboot`, `poweroff`, `sheet` |
| `jot` | `add <text>`, `todo <text>` |
| `settings` | `open [page|key]` |

### Signals into the shell
- `aptus-clipd` touches `$XDG_RUNTIME_DIR/aptus/clip.changed` after each store; the shell watches
  it.
- `aptus-guard` writes `$XDG_RUNTIME_DIR/aptus/guard.state` (`ok` / `scope-only` / `failed`).
- `aptus-theme apply` writes `~/.local/state/aptus/theme/current` (a symlink swap) and the shell
  watches `current/shell.json` for palette values when changed outside the shell.

## 8. Configuration

- `~/.config/aptus/settings.json`: only values that differ from defaults (see
  [surfaces/settings.md](surfaces/settings.md) §4). `{"v": 2, "appearance.accent": "sky", …}`
  (flat dotted keys).
- `~/.config/aptus/calendars.json` (0600).
- Schema: `shell/config/settings-schema.json`, the single place a setting is declared; the settings
  window, validation, Spotlight's Settings provider, `aptus doctor config` and
  [10-settings.md](10-settings.md) are generated from or checked against it (a test fails if the
  reference document and the schema differ).
- Versioning: `v` bumps only for renames; a migration table in `Config` maps old keys to new ones
  on load and rewrites the file once.

## 9. Persistence

| File | Owner (writer) | Format | Written |
|---|---|---|---|
| `~/.config/aptus/settings.json` | Config | JSON | debounced 300 ms, atomic |
| `~/.config/aptus/calendars.json` | settings window | JSON, 0600 | on save, atomic |
| `~/.local/state/aptus/lease/…` | aptus-lease | see [02](02-isolation.md) §5 | under flock |
| `~/.local/state/aptus/theme/gen-<n>/`, `current` → | aptus-theme | rendered files | atomic dir + symlink swap; last 3 generations kept |
| `~/.local/state/aptus/scope/…` | aptus-theme | mirrors (kitty, yazi), `starship.toml` | on render |
| `~/.local/state/aptus/hypr/generated.lua`, `binds.local.lua` | aptus-theme / settings window | Lua | atomic |
| `~/.local/state/aptus/wallpaper.json`, `workspaces.json`, `focus.json`, `dnd.json`, `timers.json`, `ui.json` | their service | JSON | on change, atomic |
| `~/.local/state/aptus/focus-log.jsonl` | Focus | JSON lines | append |
| `~/.local/state/aptus/notifications.json` | Notifications | JSON (≤ 200) | 2 s after change, atomic |
| `~/.local/state/aptus/frecency.json` | Frecency | JSON | 2 s after change, atomic |
| `~/.local/state/aptus/clipboard.db`, `clip-pins.json` | aptus-clip-store, Clipboard | cliphist db (0600), JSON | per entry |
| `~/.local/state/aptus/agenda.json` | aptus-agenda | JSON | per sync, atomic |
| `~/.local/state/aptus/colours.json`, `jot-draft.txt`, `locked` | Capture, Jot, Session | small files | on change |
| `~/.cache/aptus/` (`notif/`, `clip/`, `wall-thumbs/`, `weather.json`, `bat/`, `agenda-http/`) | various | caches | may be deleted at any time |
| `$XDG_RUNTIME_DIR/aptus/` | session tools | runtime flags | per session |

Atomic means: write to a temp file in the same directory, `fsync`, `rename`. Every reader tolerates
a missing or corrupt file by using defaults and logging once.

## 10. Supervisor and failure handling

`aptus-supervise` (Python, inside Hyprland's process tree):
- Starts `qs -p <repo>/shell --no-duplicate`, stdout/stderr piped to `systemd-cat -t aptus-shell`.
- Exit code 0 with `$XDG_RUNTIME_DIR/aptus/restart` present: restart at once (a requested restart).
- Any other exit: restart after 0.5 s, 1 s, 2 s. Three crashes within 10 s: if the `locked` marker
  exists, start `hyprlock -c ~/.local/state/aptus/hyprlock.conf` immediately; then `hyprctl notify` "aptus keeps crashing — Super+Return
  opens a terminal, `aptus logs` shows why", and retry every 30 s.
- Binds that need the shell (`global aptus:*`) do nothing while it is down; window management,
  terminal and browser binds keep working. Locking is the exception: `Super+L` and
  `XF86ScreenSaver` are bound to `aptus msg session lock || hyprlock -c <aptus hyprlock.conf> || hyprlock`,
  the only aptus bind that forks a process, so locking works even with the shell down. `aptus msg`
  exits non-zero when no shell runs, when it does not answer within 2 s, and when it answers
  `error: …` (as `session lock` does while the shell has no lock screen); `qs ipc call` itself
  exits 0 for most errors, so `aptus msg` reads its output.
- Quickshell file watching is off in normal runs and on with `aptus dev` (live reload while
  developing, probe P-23).

## 11. Logging

- Shell: `Log.qml` with categories (`surface`, `service.<name>`, `ipc`, `perf`) and levels; level
  from `APTUS_LOG` (default `info`) or `aptus msg shell log debug`. Goes to journald via the
  supervisor pipe, tag `aptus-shell`.
- Tools: Python `logging` to stderr; inside units it reaches the journal with the unit name.
- `aptus logs [-f] [component]`: the tags `aptus-shell`, `aptus-session`, `aptus-supervise` and the
  units `aptus-*`, merged by time. journalctl ANDs `-t` with `-u`, so these are two queries
  (`journalctl --user -t … -o json` and `journalctl --user -u 'aptus-*' -o json`).
- `aptus-session` and `aptus-supervise` are started by Hyprland, not by a unit, so they write to
  journald's socket themselves (`SYSLOG_IDENTIFIER`); inside units, stderr reaches the journal.
- No log line ever contains notification bodies, clipboard content, passwords, calendar URLs or
  window titles above `debug`.

## 12. Performance budgets

| Measure | Budget | How it's checked |
|---|---|---|
| Shell RSS at rest, two monitors | ≤ 260 MB | `tests/perf/rss.sh` after 10 min idle |
| CPU at rest | < 0.3 % average over 5 min; ≤ 2 wakeups/s | `perf stat`, `powertop` |
| First frame after start | ≤ 500 ms from `qs` exec | timestamps in the log |
| Spotlight: key to first frame | ≤ 1 frame (16.7 ms) | perf category log |
| Spotlight: keystroke to rows (in-memory providers) | ≤ 8 ms | same |
| Overview open | first frame ≤ 16.7 ms; thumbnails ≤ 120 ms | same |
| Any shell animation | 60 fps on eDP-1, Hyprland frame time < 8 ms | `HYPRLAND_TRACE`/`hyprctl` frame stats + 60 fps recording (P-21) |
| Theme switch | shell crossfade 400 ms; all app targets re-rendered and reloaded ≤ 1.5 s, in the background | timestamps |
| Battery | no measurable drain difference vs. Hyprland with no shell (± 0.3 W at idle) | `upower` energy rate over 10 min |

## 13. Testing

| Level | What | How |
|---|---|---|
| Unit (Python) | lease kinds and journal transitions (crash at every step), INI section surgery, dconf adapter, renderer, agenda recurrence (RRULE/EXDATE/RECURRENCE-ID/all-day/DST), calculator, clip filter | `pytest` with a temporary `HOME`; dconf through a fake adapter; no real user files |
| Golden | every theme target for both palettes and six accents | rendered output compared byte-for-byte with `tests/golden/` |
| Shell logic | SurfaceManager transitions, interruption policy, ranking, toast timing | `qmltestrunner` on the core singletons with fake services |
| End-to-end | real surfaces, binds, IPC | a **nested** Hyprland (`Hyprland --config tests/e2e/hyprland.lua` in a window) with `APTUS_TEST=1`: `HOME` points to a temporary directory, the lease and all units are disabled, scripts drive `hyprctl dispatch` + `aptus msg` and assert on `aptus msg shell state`; screenshots with `grim` of the nested output for visual review |
| Isolation | the round-trip test of [02-isolation.md](02-isolation.md) §10 | manual, on the laptop, part of acceptance |
| Performance | §12 | scripts in `tests/perf/` |

`APTUS_TEST=1` is the hard rule that makes testing safe: with it, no tool writes outside the
temporary `HOME`, and `aptus-lease` refuses to run.
