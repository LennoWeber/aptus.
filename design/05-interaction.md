# 05 · Interaction model

## 1. The spatial model

Where a surface lives decides where it grows from. Learn the three places and you can predict every
surface.

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ① SPACES                          ② NOW + INTENT                    ③ MACHINE    │
│ workspaces · active window        notch (clock)                 tray · status    │
├──────────────╮                 ╭──────────────╮                 ╭────────────────┤
│              │                 │              │                 │                │
│  Overview    │                 │  Spotlight   │                 │   Deck         │
│  (whole top  │                 │  Today       │                 │   (top-right   │
│   edge drops)│                 │  Switcher    │                 │    corner)     │
│              │                 │  Toasts, OSD │                 │                │
│              │                 │  Session     │                 │                │
│              │                 │  Polkit      │                 │                │
│              │                 │  Gallery     │                 │                │
│              │                 │  Jot, Keys   │                 │                │
```

| Place | Surfaces | Opened by |
|---|---|---|
| ① left of the bar | Overview | `Super+Tab`, click on the workspace strip's empty area, Spotlight |
| ② the notch | Spotlight, Switcher, Today, toasts, OSD, live-activity cards, Session sheet, Polkit prompt, Gallery, Jot, Keys | their keys; click the clock for Today; rest the pointer for an activity card |
| ③ the top-right corner | Deck (with its pages) | `Super+C`, click on the status cluster (opens on the clicked item's section) |
| floating, anchored | menus (tray, window menu, context menus), tooltips | right click, click on a tray icon |
| full screen | Lock, Capture selection | `Super+L`, idle; `Print` |

## 2. Surface stack and keyboard

Per monitor, the **surface manager** ([07-architecture.md](07-architecture.md) §5) allows:

- at most **one notch mode** (Spotlight, Switcher, Today, Session, Polkit, Gallery, Jot, Keys) at a
  time. Opening another notch mode **morphs** the notch from one to the other; it never closes and
  reopens.
- the **Deck** at the same time as a passive notch state (toast, OSD, activity), but not at the same
  time as an interactive notch mode: opening one closes the other (the opened one gets the hero
  timeline, rule 8 in [04-motion.md](04-motion.md)).
- **Overview** alone: opening it closes everything else.
- **Lock** above everything; **Polkit** above everything except Lock.

Keyboard focus:

| Surface | Keyboard |
|---|---|
| Bar, notch at rest, toasts, OSD, activity cards opened by hover | never takes the keyboard |
| Spotlight, Switcher (once visible), Today, Deck, Overview, Session, Gallery, Jot, Keys, Polkit | exclusive while open (`WlrLayershell.keyboardFocus: Exclusive`), released on close |
| Menus | exclusive while open |
| Lock | session lock (compositor-enforced) |

## 3. Ways out

Every surface closes with:

1. **Esc**, one level at a time: a menu → its surface; a Deck page → the Deck; a Today day view → Today
   overview; a Spotlight scope → plain Spotlight; then the surface itself.
2. **A click outside it.** Implemented with an *away catcher* region on the monitor's shell layer
   (the input mask covers the whole monitor except the open surface while an interactive surface is
   open), because Hyprland drops focus grabs on small layer windows.
3. **Its own key again** (toggle): `Super+Space` closes Spotlight, `Super+C` closes the Deck, etc.
4. **Activating something** in it that leaves the shell (launching an app, focusing a window,
   copying a clipboard entry) closes it.

A click outside closes the surface **and** is delivered to what was clicked (the catcher replays
focus to the window under the pointer by issuing `focuswindow` for it), so closing never costs an
extra click.

## 4. Pointer rules

- **Nothing opens under a passing pointer.** Hover gives a wash (120 ms) and, after 600 ms, a tooltip.
- **Three exceptions**, all needing the pointer to rest, none taking the keyboard:
  - resting 300 ms on a *compact live activity* in the notch expands its card (M-08); it collapses
    400 ms after the pointer leaves it (`notch.hoverExpand`);
  - resting 600 ms on the quiet bar shows its hidden items until the pointer leaves
    ([surfaces/focus.md](surfaces/focus.md) §4);
  - over a fullscreen window, pushing against the top edge for 400 ms slides the bar back
    ([surfaces/bar.md](surfaces/bar.md) §7).
- Scroll on the bar: on the workspace strip, previous/next workspace; on the status cluster's volume
  glyph, volume ±5 %; on the battery, brightness ±5 %; on the clock, nothing.
- Middle click: on a workspace pill, move the focused window there; on a window in the overview or a
  switcher card, close it; on a toast, dismiss it.
- Right click: context menu wherever there is one (workspace pill, window title, tray icons, toast,
  notifications in Today, Spotlight rows). Everything in a context menu is also reachable otherwise.
- **TrackPoint:** no gesture depends on speed or precision; targets are ≥ 28 px; drag thresholds are
  6 px; scrolling via the middle button works everywhere a list scrolls.
- Touchpad: Hyprland's 3-finger horizontal swipe switches workspaces (kept from the current config);
  a 3-finger swipe down opens the overview, up closes it (`hl.gesture`).

## 5. Keyboard grammar

The same keys mean the same thing in every surface:

| Key | Meaning |
|---|---|
| `Esc` | back one level / close |
| `Enter` | the default action of the selection |
| `Shift+Enter` | the alternative action (shown in the row's trailing hint) |
| `Ctrl+Enter` | the secondary action (open containing folder, open in new window…) |
| `↑ ↓` (also `Ctrl+P` / `Ctrl+N`) | move the selection |
| `← →` | between columns, cards, segments; in a text field: the caret |
| `Tab` / `Shift+Tab` | to the next/previous section (or column) |
| `PageUp` / `PageDown`, `Home` / `End` | jump in lists (`Home`/`End` move the caret while a field has text) |
| `Ctrl+1` … `Ctrl+9` | pick the n-th result directly |
| `Ctrl+Backspace` | clear the field |
| `Ctrl+C` | copy the selection's value (path, hex colour, result, text) |
| `Delete` / `Ctrl+Delete` | dismiss / delete the selection (notification, clipboard entry) |
| `Space` | toggle the selected switch or tile; in a list with a preview: open the preview larger |
| `F2` | rename (workspace name in the overview) |
| `?` | show the keys for the current surface (inline overlay) |

## 6. Global keymap

Lenno's existing binds are kept; aptus replaces their Noctalia targets and adds a few. "Kept" means
the key and its meaning stay as they are in today's `hyprland.lua`.

### Shell surfaces

| Key | Action | Status |
|---|---|---|
| `Super` (tap, alone) | Spotlight | new, setting `spotlight.superTap` (probe P-02) |
| `Super+Space`, `Super+D` | Spotlight | kept |
| `XF86Dictate` (MX Keys F6) | Spotlight | kept |
| `Super+Tab` | Overview | new |
| `Alt+Tab` / `Alt+Shift+Tab` | Switcher: next / previous window (MRU) | new |
| `Super+C` | Deck | kept |
| `Super+N` | Today | kept (was notifications) |
| `Super+Shift+N` | Jot | new |
| `Super+X` | Session sheet | kept |
| `Super+L`, `XF86ScreenSaver` | Lock | kept |
| `Super+M` | Log out (graceful) | kept (now graceful) |
| `Super+S`, `Super+comma` | Settings window | kept |
| `Super+W` | Wallpaper gallery | kept |
| `Super+T` | Toggle light/dark | kept |
| `Super+K` | Keys cheatsheet | new |
| `Super+period`, `XF86EmojiPicker` | Spotlight, emoji scope | new / kept |
| `Super+Shift+V` | Spotlight, clipboard scope | new |
| `Super+Shift+F` | Focus session: start (opens the duration picker) / stop | new |
| `Super+Shift+D` | Do not disturb on/off | new |
| `Super+Shift+B` | Quiet bar on/off (the M-31b state, without a focus session) | new |
| `Super+Shift+S`, `Print` | Capture region | kept |
| `Shift+Print` | Capture the focused monitor | new |
| `Super+Shift+R` | Record: start (region picker) / stop | new |
| `Super+Shift+C` | Colour picker | new |
| `Super+minus` | Scratch terminal (special workspace) show/hide | new |
| `Super+Shift+minus` | Move the focused window to the scratch workspace | new |

### Windows and workspaces (unchanged from today unless marked)

| Key | Action |
|---|---|
| `Super+Return` | terminal (`ghostty`, else `kitty`) |
| `Super+Q` | close window |
| `Super+E` | file manager (`nemo`) |
| `Super+B` | browser (`zen-browser`) |
| `Super+Y` | yazi in the terminal |
| `Super+V` | toggle floating |
| `Super+P` | pseudotile |
| `Super+J` | toggle split |
| `Super+F` | fullscreen |
| `Super+R` | laptop rotation script |
| `Super+←↑→↓` | focus in a direction |
| `Super+Shift+←↑→↓` | move the window in a direction (new) |
| `Super+Ctrl+← / →` | previous / next workspace on this monitor (new) |
| `Super+1…0` | go to workspace 1–10 |
| `Super+Shift+1…0` | move the window to workspace n and follow |
| `Super+Alt+1…0` | move the window to workspace n, stay |
| `Super+Alt+← / →` | move the current workspace to the left/right monitor |
| `Super+wheel` | next/previous existing workspace |
| `Super+LMB drag` / `Super+RMB drag` | move / resize |

### Hardware keys (all through aptus, all `locked` so they work on the lock screen)

| Key | Action |
|---|---|
| `XF86AudioRaiseVolume` / `Lower` / `Mute` | volume ±5 % (`Shift`: ±1 %) / mute, OSD |
| `XF86AudioMicMute` | mic mute, OSD, ThinkPad mic LED follows (kernel does it) |
| `XF86MonBrightnessUp` / `Down` | brightness ±5 % (`Shift`: ±1 %), OSD; never below 1 % |
| `XF86KbdBrightnessUp` / `Down` / `XF86KbdLightOnOff` | keyboard backlight, OSD |
| `XF86AudioPlay` / `Pause` / `Next` / `Prev` | the active media player (see [surfaces/notch.md](surfaces/notch.md) §5) |
| Caps Lock, layout change | OSD only |

All shell binds go through Hyprland's `global` dispatcher to Quickshell `GlobalShortcut`s
(`aptus:<name>`), so a keypress never forks a process (probe P-01; fallback: `aptus msg …`).

## 7. Multi-monitor

- Every monitor has its own frame, bar, wallpaper and overview; the bar's workspace strip shows only
  that monitor's workspaces (today's `auto-workspace-monitors.sh` keeps 1–5 external, 6–10 on eDP-1).
- The **active monitor** is the one Hyprland reports as focused. Spotlight, Today, Deck, Switcher,
  Session, Gallery, Jot, Keys and toasts open there. Compact live activities show in every
  monitor's notch (so a glance works on either screen); expanded cards only on the active monitor.
- OSD shows on the active monitor; brightness OSD on the monitor whose brightness changed (eDP-1).
- Plugging a monitor in or out rebuilds that monitor's shell windows without touching the others;
  open surfaces on a removed monitor close.
- The lock covers every monitor; the password field is on the active one, the others show only the
  clock.

## 8. Interruption policy

What may interrupt, and how much:

| Event | Normal | Do not disturb | Focus session | Fullscreen window |
|---|---|---|---|---|
| Notification, urgency low | Today only + unread dot | Today only | held | Today only |
| Notification, normal | toast 5 s | held, unread dot | held, counted | held (setting `notch.overFullscreen`) |
| Notification, critical | toast until dismissed | toast | toast | toast over fullscreen |
| Allowlisted app (setting) | toast | toast | toast | as normal |
| Calendar reminder (10 min, start) | compact activity + toast | compact activity | compact activity (no toast) | held |
| Timer/alarm finished | toast until dismissed, sound | same | same | over fullscreen |
| Battery ≤ 15 % / ≤ 7 % | warn toast once / crit toast until plugged | same | same | over fullscreen |
| OSD | yes | yes | yes | small, over fullscreen |

"Held" notifications are kept in Today and summarised when DND or the focus session ends: one toast
"7 notifications while you were focused" that opens Today.

## 9. Accessibility

- Every action is reachable by keyboard; the focus ring appears on the first keyboard navigation in
  a surface and stays until the pointer moves.
- Every icon-only control has a tooltip and an accessible name (`Accessible.name`).
- Text scale setting (`appearance.textScale` 1.0 / 1.1 / 1.25) scales the type tokens and the bar
  height (32 → 35 → 40); geometry around text follows.
- Reduced motion ([04-motion.md](04-motion.md) §7).
- Contrast meets the APCA targets in both modes; `appearance.contrast = high` raises `ink.sec` and
  `ink.meta` one step toward `ink.main` (≈ +10 Lc).
- Sounds are optional and never the only signal.
