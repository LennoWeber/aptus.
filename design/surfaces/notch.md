# Notch

## 1. Purpose

The notch is the shell's voice. At rest it is the clock. When something happens it says so in the
smallest shape that fits, then goes quiet again. When you ask for something (Spotlight, Today, the
switcher …), the same shape becomes that surface. One place to look, one shape that changes.

## 2. States

```
rest                      rest + compact activities              toast / event / OSD (bulge)
───── 14:32 Sat 7 • ─────  ──── ▣ 14:32 ◔ 24:10 ────              ────╮               ╭────
                                                                     ╰─ ▢ Title      ─╯
                                                                        body…
activity card (bulge)      interactive modes (bulge, see their own documents)
───╮                 ╭───  Spotlight · Today · Switcher · Session · Polkit · Gallery · Jot · Keys
   ╰ ▣ Track  ◁ ▷▷ ⏸ ╯
```

| State | Shape | Keyboard |
|---|---|---|
| `rest` | no bulge; clock, date, unread dot inline in the bar | no |
| `rest + compact` | no bulge; compact activities in a left and a right slot beside the clock | no |
| `event` | bulge 260–360 × 36 | no |
| `osd` | bulge 300 × 44 | no |
| `toast` | bulge 420 × 72–132 | no (except an opened reply field) |
| `card` | bulge 420 × 96–140, the expanded activity | no when opened by hover; yes when opened by click (for its buttons) |
| interactive mode | its own geometry | exclusive |
| `hidden` | under a fullscreen window: nothing, except critical toasts, OSD and recording (setting `notch.overFullscreen`) | — |

The bulge always hangs from the bar's bottom edge, centred on the monitor, with coves of 14 and
bottom corners of 18. Its width and height move with `spring.notch`, so a toast that becomes a card,
or a card that becomes Spotlight, morphs without closing.

## 3. Rest

- Clock `HH:mm` in `clock` type, tabular, `ink.main`; minute changes roll (M-34).
- Date `Sat 7 Nov` in `micro`, `ink.meta`, 6 px after the clock (`bar.clock.showDate`).
- Unread dot: 6 px `ink.sec` dot 6 px after the date while Today has unread notifications (M-35).
  `accent` instead of `ink.sec` when one of them is from an allowlisted app.
- **Click** the clock: Today. **Right click**: menu with Do not disturb ▸ (1 h, until tomorrow, until
  I turn it off), Start focus ▸ (25, 50, 90 min), Open calendar settings.
- **Hover** the clock: tooltip "Saturday, 7 November · week 45".

## 4. Compact live activities

Two slots flank the clock. Each shows at most one activity; others wait by priority.

| Slot | Activity | Compact look | Priority |
|---|---|---|---|
| left | meeting starting within 10 min | `event` glyph + "in 9 min" (`micro`, `warn` under 2 min) | 90 |
| left | media playing | 18 px cover (radius 4); paused: cover at 40 % ink.faint overlay | 60 / 20 (paused, hidden after 10 min) |
| right | recording | 8 px `crit` dot (M-24) + elapsed `mm:ss` | 100 |
| right | timer ringing | `alarm` glyph in `warn` | 95 |
| right | focus session | 14 px ring (accent) + minutes left "24" | 80 |
| right | timer running | 14 px ring + `mm:ss` | 70 |
| right | progress (download, copy, export) | 14 px ring + "42 %" | 50 |

There is no perpetual animation in compact form. Media is a still cover, not an equaliser.

The clock slides aside to make room (shared element, M-05). The whole centre group never exceeds
480 px; when it would, the lower-priority slot gives way.

| Input on an activity | Action |
|---|---|
| Hover 300 ms | its card, transient (collapses 400 ms after the pointer leaves) |
| Click | its card, pinned (stays until Esc, a click outside, or 8 s without the pointer over it) |
| Middle click | media: play/pause; timer ringing: stop; others: nothing |
| Right click | menu: Hide until it changes (media), Stop (timer, recording, focus), Open in Today |

## 5. Cards

All cards: bulge width 420, padding 12, `card` content laid out in a 2-row grid. A pager (6 px dots,
`ink.faint`, current `ink.sec`) at the bottom when more than one activity is live; `Tab` and `←/→`
switch while the card has the keyboard.

| Card | Contents | Buttons |
|---|---|---|
| **Media** (420 × 132) | cover 88 (radius 10), title (`title`), artist · album (`body`, `ink.meta`), app icon 16 + player name, seekable progress (4 px track, accent, drag or click to seek), `0:42` / `−2:18` tabular `micro` | previous, play/pause (36 round primary), next; shuffle and loop only if the player supports them |
| **Timer** (420 × 96) | label ("Tea"), remaining in `number` type, 40 px ring | +1 min, pause/resume, stop (risk-free, plain) |
| **Focus** (420 × 96) | intent ("Write the isolation spec"), minutes left, ring | +10 min, Break now, Stop |
| **Recording** (420 × 96) | elapsed, what is recorded ("Region 1280 × 720", "eDP-1"), mic state | Mic on/off, Stop (crit) |
| **Meeting** (420 × 110) | title, `14:00–14:30`, calendar colour dot, location or link host | Join (primary, if a meeting link exists), Snooze 5 min, Dismiss |
| **Progress** (420 × 80) | name, percent, rate and remaining if known | Cancel (only if the source offers it) |

**Media keys** act on the *active player*: the player that most recently entered `Playing`; if none
plays, the one that played last. Players listed in `media.ignore` are never active. `XF86AudioPlay`
with no player at all shows the event "Nothing to play".

## 6. Toasts

### Content

```
╭──────────────────────────────────────────────╮
│ ▢  App name · now                        ✕   │   app icon 24, app + time in micro ink.meta,
│    Title of the notification                 │   close appears on hover
│    Body, at most two lines, ellipsised…  ▣   │   image thumbnail 48 (radius 8) if the notification has one
│    [ Reply ]  [ Mark as read ]               │   up to 3 action buttons (quiet buttons)
╰──────────────────────────────────────────────╯
```

- Title `title`, body `body` `ink.sec`, at most 2 lines (body markup reduced to bold/italic/links).
- Height: 72 without actions, 104 with actions, 132 with an image and actions.
- Urgency critical: a `warning` glyph before the title in `crit`; no timeout.

### Timing
- Normal: `clamp(4 s + 40 ms × characters(title + body), 4 s, 9 s)`, +3 s when there are actions.
- The countdown pauses while the pointer is over the toast and resumes with at least 2 s left.
- The countdown pauses while an OSD temporarily replaces the toast.
- After the toast closes, the notification stays in Today (unread).

### Arrival rules
1. One toast at a time. Arrivals queue (FIFO).
2. Two or more arrivals within 2 s become one **stack** toast: overlapping app icons, "3 notifications",
   the newest title. Click opens Today.
3. A notification that replaces another (`replaces_id`) updates the visible toast in place (content
   crossfade, M-06 not replayed) and restarts its countdown.
4. A notification with a progress hint (`value` 0–100) becomes a *progress* activity instead of a
   toast, and a toast only when it completes or fails.
5. The interruption policy ([05-interaction.md](../05-interaction.md) §8) decides whether a toast
   shows at all.

### Interactions
| Input | Action |
|---|---|
| Click the body | default action (or, without one, focus the app's window: desktop-entry hint → toplevel class), then dismiss |
| Click a button | that action; dismiss unless the notification is `resident` |
| Click ✕, middle click | dismiss (it stays in Today as read) |
| Right click | menu: Mute *App* for 1 hour, Turn on Do not disturb, Notification settings |
| Reply (inline-reply action) | a field opens in the button row and takes the keyboard; Enter sends, Esc returns; countdown stopped; while it is open an OSD does not cover the toast (the level still changes) |

## 7. Events

Short statements, 1.6 s, bulge 260–360 × 36, glyph + one line: "Headphones connected · 70 %",
"Charging", "Wi-Fi off", "Copied", "Dark", "Focus ended", "Screenshot saved". They never queue
behind toasts; an event shown during a toast appears after it, and events older than 4 s are dropped.

## 8. OSD

```
╭─────────────────────────────────────╮
│  ◢   ███████████████░░░░░░░   45  │   glyph 20 · level 180 × 6 · value (tabular, ink.meta)
╰─────────────────────────────────────╯   device name replaces the value for 1 s on device change
```

| Kind | Glyph | Level | Value |
|---|---|---|---|
| Volume | by level; `volume_off` (crit) when muted | 0–100 (up to 150 if `audio.allowBoost`; the part over 100 in `warn`) | % |
| Microphone | `mic` / `mic_off` (crit) | — | "Muted" / "On" + device |
| Brightness | `light_mode` / `brightness_low` | 1–100 | % |
| Keyboard light | `keyboard` | 3 dots (off, low, high) | — |
| Caps Lock | `keyboard_capslock` | — | "Caps Lock on" / "off" |

Collapses 1 200 ms after the last change. OSD takes priority over a visible toast (the toast resumes
after). It never shows while an interactive notch mode is open; when the Deck is open, its slider
moves instead.

## 9. Arbitration summary

```
interactive mode open  → OSD suppressed, events dropped, toasts queued, compact activities hidden
  (also while Overview or Capture is open; the Deck is no blocker, 05 §2)
otherwise:
  OSD active           → shows (toast paused underneath)
  else toast queued    → shows
  else event queued    → shows
  else card pinned     → shows
  else                 → rest (+ compact activities)
```

## 10. Motion

M-05 compact enter/leave · M-06 toast · M-07 OSD · M-08 card · M-24 recording dot · M-34 clock ·
M-35 unread dot. Transitions between bulge states (toast → OSD → toast, card → Spotlight) morph:
the geometry retargets the spring, old content fades out over 110 ms, new content fades in from
60 ms.

## 11. Data

| Data | Source |
|---|---|
| Notifications | aptus's own `NotificationServer` (`Quickshell.Services.Notifications`), with `actionsSupported`, `imageSupported`, `bodyMarkupSupported`, `inlineReplySupported`, `persistenceSupported` |
| Media | `Quickshell.Services.Mpris` |
| Timers, focus, recording, progress | aptus services (`Timers`, `Focus`, `Capture`, `Progress`) |
| Meetings | `Agenda` service ([today.md](today.md) §7) |
| OSD values | `Audio`, `Brightness`, `Keyboard` services; the layout from Hyprland `activelayout` (a keyboard's own layout changing; another keyboard becoming active, or Hyprland's `error` for an unnamed keymap, is no change); Caps Lock from a non-consuming `Caps_Lock` release bind (`hypr/binds.lua`) that reads the main keyboard's `caps_lock` (`hl.get_devices()`) and dispatches `aptus:capslock-on` / `-off` (Hyprland has no Caps Lock event) |

## 12. Edge cases

- **50 notifications in a burst** (a chat backlog): one stack toast; Today groups them by app.
- **A notification without app name or icon**: "Notification" and the `notifications` glyph.
- **A toast arrives while Spotlight is open**: queued; it shows when Spotlight closes, unless it is
  older than 30 s by then (then it only goes to Today).
- **A player with no metadata**: the player's name as title, no cover (the cover slot shows the app
  icon on `raised`).
- **Very long titles**: one line, ellipsised; the card shows two lines.
- **Notch on a monitor that has no focus**: compact activities only; toasts and cards appear on the
  active monitor.

## 13. Settings

`bar.clock.showDate`, `notch.overFullscreen` (`critical` | `none` | `all`), `notifications.timeout`
(`auto` | seconds), `notifications.allowlist`, `notifications.stackWindow` (2 s), `media.ignore`,
`audio.allowBoost`, `notch.hoverExpand` (true). Defaults in [10-settings.md](../10-settings.md).
