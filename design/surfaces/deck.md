# Deck

## 1. Purpose

Everything about the machine in one drawer from the top-right corner: connectivity, sound, screen,
power, and the media that is playing. The main view answers the common things in one click; every
area has a page for the details.

## 2. Anatomy — main view

```
                                                         ──────────────╮  ╭── bar
                                                                       ╰──┤
                                                   ╭───────────────────────┤ ← cove where it meets the bar
                                                   │ ┌──────┐┌──────┐┌──────┐┌──────┐│
                                                   │ │ ᯤ    ││ ✱    ││ ◐    ││ ⏾    ││  toggle tiles 88 × 64
                                                   │ │Wi-Fi ›│BT   › │Dark  ││DND  ›││  (row 1)
                                                   │ │Home  ││WH-1000│On    ││Off   ││
                                                   │ └──────┘└──────┘└──────┘└──────┘│
                                                   │ ┌──────┐┌──────┐┌──────┐┌──────┐│
                                                   │ │ ☀    ││ ☕   ││ ◎    ││ ⚡   ││  (row 2)
                                                   │ │Night ›│Awake ││Focus ›││Power ›│
                                                   │ └──────┘└──────┘└──────┘└──────┘│
                                                   │ 🔊 ━━━━━━━━━━━●────────  45  › │  sliders 32 high
                                                   │ 🎙 ━━━━━━━━━━━━━━━●────  70  › │
                                                   │ ☀ ━━━━━━●──────────────  38  › │
                                                   │ ┌───────────────────────────┐   │
                                                   │ │ ▣  Track title   ◁ ⏸ ▷   │   │  media card 72 (if a player)
                                                   │ └───────────────────────────┘   │
                                                   │ ▮▮▮ 64 % · 3 h 10 min   Balanced›│  power row 36
                                                   │ ─────────────────────────────── │
                                                   │ ⚙ Settings   ⎙ Capture   🔒   ⏻ │  footer 36: quiet icon buttons
                                                   ╰────────────────────────────────╮│
                                                                                     ╰┤ ← cove where it meets the right edge
```

- Width 400 (inner 368), docked into the top-right inner corner: coves of 14 where it meets the bar
  and where it meets the right frame edge; one convex corner (18) bottom-left.
- Height: content height, at most monitor height − 32 − 6 − 48. Pages may scroll inside.
- Opens at the section that was clicked in the status cluster (main view scrolled so that item is
  visible and briefly washed, or directly on that item's page when `deck.openPages` is on).

## 3. Toggle tiles

| Tile | Glyph | State line | Click | Chevron (›) / right click |
|---|---|---|---|---|
| Wi-Fi | strength glyph | network name / "Off" / "Not connected" | toggle radio | Wi-Fi page |
| Bluetooth | `bluetooth` | device name, "On", "Off" | toggle adapter | Bluetooth page |
| Dark | `dark_mode` | "On", "Off", "Auto · on" | toggle light/dark (`auto` → explicit) | Appearance in settings |
| Do not disturb | `do_not_disturb_on` | "Off", "Until 18:00" | toggle (until turned off) | menu: 1 h, until tomorrow 08:00, until off |
| Night light | `nightlight` | "Off", "4000 K", "Auto · from 17:06" | toggle | Display page |
| Keep awake | `coffee` | "Off", "On" | toggle idle inhibitor (session-scoped) | — |
| Focus | `center_focus_strong` | "Off", "18 min left" | start 50 min / stop | duration menu |
| Power | profile glyph | "Balanced" | cycle saver → balanced → performance | Power page |

Order is fixed by default; `deck.tiles` reorders or hides them (8 slots, two rows).

## 4. Sliders

| Slider | Range | Glyph | Trailing | Chevron |
|---|---|---|---|---|
| Output volume | 0–100 (150 with `audio.allowBoost`) | by level, click = mute | value | Sound page (devices, apps) |
| Microphone | 0–100 | `mic`/`mic_off`, click = mute | value | Sound page, input section |
| Brightness | 1–100 | by level | value | Display page |

Keyboard: `↑ ↓` move between rows; `← →` change by 5 (`Shift`: 1); `Home`/`End` min/max; `M` mutes
the focused audio slider.

## 5. Media card

Present only when a player exists: cover 48, title, artist, prev / play-pause / next, the app icon;
click on the text opens the player's window. Several players: a small pager, `[`/`]` switch.

## 6. Power row

Battery glyph, percentage, "3 h 10 min left" / "1 h 05 min to full" / "Plugged in" / "Fully
charged"; the profile name; click opens the Power page. Without a battery: only the profile.

## 7. Footer

Quiet icon buttons with tooltips: Settings (`Super+S`), Capture (opens the capture choice: region,
window, screen, record), Lock (`Super+L`), Session (`Super+X`, morphs into the session sheet).

## 8. Pages

Pages push from the right (M-17). The page header: back chevron, title (`title`), and the page's main
switch on the right. `Esc` or the back chevron pops.

### Wi-Fi
- Switch: radio on/off. Current network first: name, strength, security glyph, "Connected"; its row
  expands on click to: IP address, speed (if reported), Forget (risk), Share (shows a QR code of the
  network for phones; generated locally), Disconnect.
- Then known networks in range, then other networks by strength; hidden ones in "Other…".
- Click a secured unknown network: the row expands into a password field (`sunken`, show/hide eye);
  Enter connects; while connecting the row shows "Connecting…" and the field is disabled; failure
  says why ("Wrong password", "Timed out") and keeps the field. Enterprise (802.1X) networks:
  "Open in network settings" (`nm-connection-editor`, if installed; otherwise `nmtui` in a terminal).
- Scans on page open and every 10 s while the page is visible; a quiet "Scanning" text in the header
  while a scan runs.
- VPN: a section at the bottom listing NetworkManager VPN/WireGuard connections with switches.
- Hotspot is not in v2 (rarely used; `nmcli` covers it).

### Bluetooth
- Switch: adapter power. Connected devices first (battery % if reported), then paired, then "Nearby"
  while discovering (discovery runs only while this page is open, at most 60 s).
- Row click: connect/disconnect. Right click / chevron: Disconnect, Forget (risk), Rename, trust.
- Pairing a new device: click it in Nearby → "Pairing…"; if a passkey must be confirmed, the row
  shows the six digits and Confirm / Cancel; PIN entry gets a field.

### Sound
- Outputs (radio list with the device's glyph: speakers, headphones, HDMI), volume per selected
  device; Inputs likewise.
- **Apps:** one slider per app stream (icon, name, slider, mute), only apps currently playing or
  recording.
- Per-device: "Set as default" is implied by selection; right click offers profile choice (e.g. A2DP
  vs headset) when the device has profiles.

### Display
- Brightness slider (eDP-1). External monitors: brightness only if DDC/CI is available
  (`ddcutil`, optional, not installed by default; otherwise hidden).
- Night light: switch, temperature slider 2500–6000 K, schedule segmented control *Sunset to sunrise*
  / *Custom* / *Off*; custom shows two time fields.
- Scale and refresh rate per monitor are **not** here: they belong to `hyprland.lua` (Lenno's own
  monitor lines), and changing them from the shell would fight that config.

### Power
- Battery: percentage, state, time left, energy rate (W), health (`energy_full / energy_full_design`
  as %), cycle count if reported.
- Profile: segmented control Power saver / Balanced / Performance (tuned-ppd through UPower's
  PowerProfiles API).
- Idle: lock after (minutes), screen off after (minutes) — shortcuts to the same settings as the
  settings window.
- Lid: "When the lid closes: Lock" (session setting, see [session.md](session.md) §3).

## 9. Motion

M-16 open/close, M-17 pages, M-18 tiles, M-19 sliders. When opened by clicking a status item, the
matching tile or slider gets a 600 ms `hover` wash pulse once the content has settled.

## 10. Data

| Area | Source |
|---|---|
| Wi-Fi, VPN | `Quickshell.Networking` for devices, state, scan results and connecting (probe P-13); `nmcli` for forget, QR (password via `nmcli -s -g 802-11-wireless-security.psk connection show`), VPN up/down when the module lacks it |
| Bluetooth | `Quickshell.Bluetooth` |
| Sound | `Quickshell.Services.Pipewire` (sinks, sources, streams, `PwObjectTracker` for volumes) |
| Brightness | `brightnessctl` (backlight `intel_backlight`), read via `/sys/class/backlight/intel_backlight` with `FileView` watch |
| Keyboard light | `brightnessctl` on the first `*::kbd_backlight` LED; this ThinkPad currently exposes none (`/sys/class/leds`), so the OSD kind and keys stay inert until one appears |
| Night light | `hyprsunset` IPC (`hyprctl hyprsunset temperature N` / `identity`) |
| Battery, profile | `Quickshell.Services.UPower` (`UPower.displayDevice`, `PowerProfiles`) |
| Keep awake | `IdleInhibitor` (Quickshell.Wayland) on a hidden shell surface, plus a logind `idle` inhibitor (`systemd-inhibit --what=idle`) |

## 11. Edge cases

- Wi-Fi hardware switch / rfkill hard-blocked: the tile is disabled with "Blocked by hardware switch".
- No Bluetooth adapter: the tile and page disappear.
- PipeWire restarts: sliders show "—" until the nodes come back (≤ 2 s), no error toast.
- tuned-ppd not running: the Power tile shows "Unavailable" and is disabled.
- Opening the Deck while Spotlight is open: Spotlight closes (exit) while the Deck opens (hero).

## 12. Settings

`deck.tiles`, `deck.openPages`, `audio.allowBoost`, `audio.step`, `brightness.step`,
`nightLight.*`, `idle.*`, `power.lidAction`. Defaults in [10-settings.md](../10-settings.md).
