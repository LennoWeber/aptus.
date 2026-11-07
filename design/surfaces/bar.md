# Frame and bar

## 1. Purpose

The frame turns the screen into one finished object; the bar is its top edge and answers, at a
glance: *where am I* (workspaces, active window), *what time is it and is anything happening* (the
notch), *is the machine fine* (status). It never asks for attention unless something needs it.

## 2. Anatomy (eDP-1, 1920 × 1080)

```
 x=0                                                                                                    x=1920
 ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────┐ y=0
 │  [▣] (1 ◉◉) (2 ◉) (3) (5 ◉◉◉+2)   ▢ zen  Design review – aptus…        14:32 Sat 7 Nov •     ⋯ ◍ ◍ │ ⏾ ᯤ ✱ ▮▮ 64% │ │ 32 px
 ├─╮                                                                                                      ╭─┤ y=32
 │ │                                                                                                      │ │
 │ │                                      windows (8 px from the frame)                                   │ │
 │ │                                                                                                      │ │
 │ ╰──────────────────────────────────────────────────────────────────────────────────────────────────────╯ │
 └──────────────────────────────────────────────────────────────────────────────────────────────────────────┘ y=1080
  ↑ frame edges 6 px, inner corners r 18 (concentric with window corners r 10 + gap 8), inner 1 px line
```

Zones of the bar (content starts 14 px from the screen edge: 6 px frame + 8 px):

| Zone | Content | Width rule |
|---|---|---|
| Left | overview button, workspace strip, active window | strip first; title takes what is left, max 420 px, min 120 px, else hidden |
| Centre | the notch: clock, date, unread dot, compact activities ([notch.md](notch.md)) | always centred on the monitor, never truncated |
| Right | tray, status cluster | cluster never truncated; tray collapses into overflow first |

Vertical: all bar content is centred in the 32 px band. Pills are 22 px high.

## 3. Workspace strip

### Pills

```
 (1 ◉◉)   (2 ◉)   (3)   (5 ◉◉◉ +2)   (⌨)
  active   used    empty  used, more   scratch
```

| Element | Spec |
|---|---|
| Pill | height 22, radius 11, padding 8 horizontal, gap between pills 4 |
| Number | `bar` type, tabular; the workspace's name instead when it has one (≤ 12 chars, F2 in the overview) |
| App icons | up to 3 distinct apps on that workspace, 14 px, most recently focused first, 3 px apart; more apps: `+n` in `micro` `ink.meta` |
| Active | accent capsule behind the pill, number and glyphs in `onAccent`; the capsule slides between pills (M-02) |
| Used, not active | `raised` fill, number `ink.sec` |
| Empty (shown in `fixed` mode, or because it is active) | no fill, number `ink.faint` |
| Urgent | 6 px `warn` dot at the pill's top-right, one nudge (M-36) |
| Scratch | a `terminal` glyph pill at the end, only while the special workspace has windows; accent ring 1.5 px while it is shown |

`bar.workspaces.show`: `used` (default: occupied and active workspaces of this monitor, in id order)
or `fixed` (every id assigned to this monitor, e.g. 6–10 on eDP-1 when an external monitor is in).
`bar.workspaces.icons`: `true` (default) | `false` (numbers only).

When the strip would need more than 40 % of the bar's width, icons collapse to numbers on the
inactive pills first, then on all.

### Overview button
A 28 × 28 quiet icon button (`grid_view` glyph) before the first pill. Tooltip "Overview  Super+Tab".

### Interactions

| Input | On a pill | On the strip's background |
|---|---|---|
| Click | go to that workspace | open the overview |
| Middle click | move the focused window there (stay) | — |
| Right click | menu: Rename…, Move focused window here, Move workspace to ▸ (monitors), Close all windows… (risk; asks once in the menu row: "Close 4 windows?") | — |
| Wheel | previous / next used workspace | same |
| Hover | wash + tooltip after 600 ms: "2 · zen, kitty" (number or name, then the apps) | — |

## 4. Active window

`app icon (16) · title` in `bar` type, `ink.sec`, ellipsised at the end. After the title, `ink.meta`
glyphs for states: `picture_in_picture` floating, `push_pin` pinned, `fullscreen` fullscreen. With
no window on the workspace: the workspace's name if it has one, otherwise nothing.

| Input | Action |
|---|---|
| Click | window menu (floating, anchored below the title): Float / Tile, Pin (floating only), Fullscreen, Move to workspace ▸ 1–10, Move to monitor ▸, Send to scratch, —, Close (risk, last) |
| Middle click | close the window |
| Wheel | cycle focus between windows on this workspace |

Title changes animate with M-03. A title that changes more than 4 times a second (progress in a
terminal title) updates at most every 250 ms.

## 5. Tray

Status-notifier items, 16 px icons, 6 px apart, to the left of the status cluster.

- At most `bar.tray.max` (default 3) items visible; the rest behind an `expand_more` overflow button
  that opens a menu with icon + title rows.
- Items in `bar.tray.hidden` (by item id) are never shown.
- Click: `activate()`; right click: the item's DBusMenu rendered as an aptus menu; middle click:
  `secondaryActivate()`; wheel: `scroll()`.
- An item in `NeedsAttention` status gets a 6 px `warn` dot.
- The tray shows on the active-by-default monitor only (`bar.tray.monitor`: `primary` | `all`).

## 6. Status cluster

One pill (height 24, radius 12, `raised` on hover only) containing, right to left in this fixed
order (glyphs 16 px, 8 px apart), only what is relevant:

| Order | Item | Shown when | Glyph and colour | Tooltip |
|---|---|---|---|---|
| 1 | Battery | always on a laptop | level glyph (8 steps), `bolt` overlay while charging; `warn` ≤ 15 %, `crit` ≤ 7 %; percentage text after the glyph when ≤ 30 %, while charging, or `bar.battery.percent: always` | "64 % · 3 h 10 min left · Balanced" |
| 2 | Volume | always | level glyph; `volume_off` in `crit` when muted | "Volume 45 % · Speakers" |
| 3 | Bluetooth | adapter on and a device connected (or `bar.bluetooth: always`) | `bluetooth_connected` | "WH-1000XM4 · 70 %" |
| 4 | Network | always | Wi-Fi strength (4 steps), `lan`, `wifi_off` in `ink.faint` when offline; `vpn_key` added while a VPN is up | "Home Wi-Fi · 82 % · VPN work" |
| 5 | Do not disturb | DND on (not during focus; focus shows in the notch) | `do_not_disturb_on` | "Do not disturb until 18:00" |
| 6 | Privacy | something uses the mic, camera or shares the screen | `mic`, `videocam`, `screen_share` in `warn` | "Microphone: zen-browser" |

| Input | Action |
|---|---|
| Click on an item | open the Deck at that item's section (battery → Power, volume → Sound, …) |
| Click on the pill's padding | open the Deck at the top |
| Wheel on volume | volume ±5 % with OSD |
| Wheel on battery | brightness ±5 % with OSD |
| Middle click on volume | mute toggle |
| Right click on network / Bluetooth | toggle Wi-Fi / Bluetooth |

Items appear and leave with M-04. Privacy items appear within 500 ms of the device opening.

## 7. States of the whole bar

| State | What changes |
|---|---|
| Normal | as above |
| Quiet (`Super+Shift+B`, or a focus session) | M-31b: title, tray, date and non-critical status collapse; workspaces, notch, privacy, recording and the battery (only ≤ 30 %) stay |
| Fullscreen window on this monitor | M-31: frame and bar slide out; the top 2 px of the screen stay a hot edge: pushing the pointer there for 400 ms slides the bar back in over the fullscreen window until the pointer leaves it |
| Locked | the bar is under the lock surface; nothing to do |
| Session start | M-01 intro |
| Shell restarted (crash recovery) | appears instantly, no intro |

## 8. Data

| Data | Source | Update |
|---|---|---|
| Workspaces, windows per workspace, focused monitor | `Quickshell.Hyprland` (`Hyprland.workspaces`, `Hyprland.toplevels`, `Hyprland.focusedMonitor`) | events |
| Urgent, fullscreen, special workspace, screencast | `Hyprland.rawEvent` (`urgent`, `fullscreen`, `activespecial`, `screencast`) | events |
| App icons | toplevel class → `DesktopEntries.heuristicLookup()` → icon name in `aptus-icons-*` | on window open / class change |
| Workspace names | `~/.local/state/aptus/workspaces.json` (name per workspace id), applied with `renameworkspace` | on change |
| Tray | `Quickshell.Services.SystemTray` | events |
| Battery | `Quickshell.Services.UPower` (`UPower.displayDevice`) | events |
| Volume | `Quickshell.Services.Pipewire` default sink | events |
| Network | `Quickshell.Networking` (probe P-13), `nmcli monitor` as fallback | events |
| Bluetooth | `Quickshell.Bluetooth` | events |
| Privacy | Pipewire nodes with `media.class` `Stream/Input/Audio` (mic), `Video/Source` in use (camera), Hyprland `screencast` events | events |

## 9. Edge cases

- **No battery** (desktop or battery removed): the battery item disappears.
- **Two batteries**: UPower's display device (combined) is shown.
- **A window with an empty title**: the app's name from its desktop entry.
- **Unknown app class**: fallback letter icon ([03](../03-visual-language.md) §5).
- **Monitor narrower than 1280 px**: date hidden, title max 240, tray max 2.
- **Workspace on another monitor becomes urgent**: the urgent dot shows on that monitor's bar and,
  if it is not visible, a toast on the active monitor: "kitty needs attention on 3".
- **Hyprland reloads its config**: the bar keeps state; reserved space is re-applied by the reserve
  layer, not by the bar.

## 10. Settings

`frame.edge`, `bar.height` (follows `appearance.textScale`), `bar.workspaces.show`,
`bar.workspaces.icons`, `bar.title.show`, `bar.clock.showDate`, `bar.tray.max`, `bar.tray.hidden`,
`bar.tray.monitor`, `bar.battery.percent`, `bar.bluetooth`. Defaults in
[10-settings.md](../10-settings.md).
