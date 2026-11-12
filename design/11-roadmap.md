# 11 · Roadmap

## 1. Probes (before building what depends on them)

Each probe is a small experiment on the laptop, preferably in a nested Hyprland. Results go into
`design/probes.md` (date, result, chosen path). A failed probe never blocks the project: every one
has a fallback that is already designed.

| ID | Question | Pass when | Fallback | Needed by |
|---|---|---|---|---|
| P-01 | Do `hl.dsp.global("aptus:x")` binds reach Quickshell `GlobalShortcut`s? | `hyprctl globalshortcuts` lists `aptus:*`; key → handler < 10 ms | binds `exec` `aptus msg …` | S1 |
| P-02 | Super tap (`release`) fires only when Super was pressed and released alone; `long_press` gives a hold | 50 chords and 20 `Super+drag`s produce no tap; tap and hold work | no tap (`Super+Space` stays); no peek (Keys via `Super+K`) | S4 |
| P-03 | Hyprland 0.57 Lua details: `require("aptus.init")` from `~/.config/hypr/aptus/`; window-rule effects `center`, `pin`, `keep_aspect_ratio`, `idle_inhibit`, expressions in `size`/`move`; curve field `damping`; `window.move({direction})`, `focus({workspace = "m+1"})`, `hl.unbind`, `hyprctl eval` | `hyprctl configerrors` empty; each rule visible in `hyprctl clients` | per item, the spelling Hyprland accepts; 09 is updated | S1 |
| P-04 | `aptus-recover.service` finishes before the next session's compositor starts | timestamps in `journalctl --user -b` | as described in [02](02-isolation.md) §7 | S2 |
| P-05 | Does a running GTK 3 app re-read user CSS without a `gtk-theme` change? | yes / no recorded | new windows only (accepted) | S2 |
| P-06 | kitty honours `KITTY_CONFIG_DIRECTORY` with a symlink mirror (relative `include`s resolve inside the mirror) | kitty in Hyprland shows aptus colours, in Umbriel Noctalia's | lease `themes/noctalia.conf` (tracked in dotfiles, D-03) | S2 |
| P-07 | Ghostty reloads its config on `SIGUSR2` | live colour change | next start | S2 |
| P-08 | Layer blur behind `aptus-shell` with `ignore_alpha` on the UHD 630 | frame time + < 2 ms | glass setting hidden | S11 |
| P-09 | `ScreencopyView` of toplevels: once for the switcher, live for ≤ 10 windows in the overview | 60 fps held, < 40 MB extra | overview thumbnails captured on open, refreshed every 1 s | S7 |
| P-10 | `ALT + Alt_L` release bind reaches the shell while the switcher holds the keyboard | commit on release in 100 tries | commit on `Enter`, click, or a 1.2 s pause | S7 |
| P-11 | One full-monitor Overlay layer with a changing input mask: clicks outside the mask reach windows; `keyboardFocus` None ↔ Exclusive without remapping | no stuck pointer or keyboard in 30 min of use | one layer per drawer, each at its maximum size | S1 |
| P-12 | Killing `qs` while locked keeps Hyprland locked, and the restarted shell re-locks (`allow_session_lock_restore`) | 10/10 | hyprlock takes over at the first crash while locked | S6 |
| P-13 | `Quickshell.Networking` covers Wi-Fi scan, connect with password, state, errors | all Deck Wi-Fi flows work | `nmcli` for everything, `nmcli monitor` for events | S5 |
| P-14 | A `handle-lid-switch` block inhibitor in a transient unit bound to the guard needs no polkit prompt and ends with the session | lid closed → lock only; after logout, logind's own policy again | `power.lidAction = suspend` behaviour (lock on `PrepareForSleep`) | S6 |
| P-15 | `wf-recorder -c h264_vaapi -d /dev/dri/renderD128` records 1080p60 smoothly | no dropped frames, < 15 % CPU | `libopenh264` | S9 |
| P-16 | Paste-back with `wtype` after focus returns (≤ 150 ms) in Zen, Ghostty, kitty, an Electron app | 20/20 per app | copy only, event "Copied — Ctrl+V to paste" | S4 |
| P-17 | Animating Material Symbols' `FILL`/`wght` axes in Qt 6.11 (`font.variableAxes`) | smooth at 60 fps | crossfade between two glyph states | S3 |
| P-18 | `PamContext` with service `hyprlock` authenticates and relays faillock messages | correct password unlocks; 3 wrong → faillock text | PAM service `login` | S6 |
| P-19 | Quickshell's `PolkitAgent` registers in Hyprland (no other agent: polkit-kde autostarts only in KDE) | `pkexec true` shows the aptus prompt | `hyprpolkitagent` (would need installing) | S6 |
| P-20 | aptus can own `org.freedesktop.Notifications` in Hyprland (nothing else D-Bus-activates) | `notify-send` reaches aptus | doctor names the owner; Lenno removes it | S3 |
| P-21 | Spring calibration (record at 60 fps, measure settle and overshoot) | within ±10 % of [04](04-motion.md) §2.3 | adjust parameters | S11 |
| P-22 | `fprintd-verify` alongside password PAM on the lock screen | either unlocks; no hang when the reader is absent | fingerprint option hidden | S6 |
| P-23 | Quickshell file watching can be turned off for normal runs | editing a QML file does not reload the running shell | harmless; live reload stays on | S1 |

## 2. Stages

Every stage runs through the `phasen-entwicklung` workflow (structures → signatures → TODOs →
implementation, review after each phase). Phases run back to back without waiting for a go, as Lenno
prefers. A stage ends with its acceptance checks (§3) and a commit series on the `v2` branch.

| # | Stage | Contents | Probes |
|---|---|---|---|
| S0 | Probes | everything in §1 that can be checked before code (P-01, P-03, P-11, P-23 first) | — |
| S1 | Foundation | v1 removal (§4), `paths`/`atomic`/`log`, `Config` + schema, `Tokens`, `Motion`, `MonitorShell` layers, wallpaper, frame and bar skeleton (static), `aptus-reserve`, the Hyprland block (look, motion, rules, binds stub), `aptus-session` (scope-only), supervisor, `install.sh` (non-destructive, diff + approval) | P-01, P-03, P-11, P-23 |
| S2 | Isolation | `aptus-lease`, `aptus-guard`, `aptus-recover.service`, renderer + every target + hooks, `aptus doctor isolation`; untrack Noctalia artifacts in `~/dotfiles` (D-03, local commit only) | P-04 … P-07 |
| S3 | Bar and notch | workspaces, active window, tray, status cluster, notification server, toasts, events, OSD, hardware keys, media, compact activities | P-17, P-20 |
| S4 | Spotlight | providers, ranking, preview, actions, `aptus-calc`, clipboard daemon, files, paste-back, Super tap | P-02, P-16 |
| S5 | Deck | tiles, sliders, media, power row, pages (Wi-Fi, Bluetooth, Sound, Display, Power) | P-13 |
| S6 | Session | lock + veil, idle, lid, session sheet, graceful logout, polkit, fingerprint | P-12, P-14, P-18, P-19, P-22 |
| S7 | Windows | switcher, overview, scratch terminal | P-09, P-10 |
| S8 | Time and attention | Today (agenda, weather, history, jot inbox), focus, DND, quiet bar, Keys, Jot | — |
| S9 | Capture | screenshots, recording, colour picker | P-15 |
| S10 | Settings and gallery | settings window (generated pages, calendars, keys editing, isolation page), wallpaper gallery and rotation | — |
| S11 | Finish | motion calibration, reduced motion, high contrast, glass, accessibility pass, performance budgets, docs (CLAUDE.md; README rewritten as the project's front page: professional, with current screenshots of every surface in dark and light, taken in a nested session at 1920 × 1080 with a real wallpaper) | P-08, P-21 |

After S2, Hyprland is usable every day with aptus; every later stage replaces a missing piece
without breaking the earlier ones.

## 3. Acceptance

### Always (every stage)
- **Umbriel unchanged:** log into Umbriel; `aptus doctor isolation` passes; Noctalia's look is
  identical (spot-check GTK app, kitty, Zen, Dolphin).
- No errors in `hyprctl configerrors`; no warnings above `info` in `aptus logs` for a normal session.

### Isolation (S2, repeated in S11)
- The round-trip test of [02](02-isolation.md) §10 with three endings: logout, `SIGKILL` to
  Hyprland, hard power-off. All slot hashes equal the Umbriel baseline afterwards.
- With an Umbriel session open on another VT, starting Hyprland gives scope-only mode and the notch
  message; Umbriel's apps keep Noctalia's paint.
- Every enabled Noctalia template is covered or reported.

### Shell
| Area | Checks |
|---|---|
| Start | first frame ≤ 500 ms after `qs` exec; intro plays once per Hyprland session; Noctalia is not running |
| Keys | every entry of [05](05-interaction.md) §6 does what it says, including on the lock screen for hardware keys |
| Ways out | for every surface: Esc ladder, click outside (and the click's focus reaches the window), its key again, activation closes |
| Pointer | nothing opens on hover except activity cards (300 ms), the quiet-bar reveal (600 ms) and the fullscreen hot edge (400 ms push) |
| Fullscreen | bar and frame leave (M-31); critical toast, OSD and Spotlight still appear above |
| Multi-monitor | plug/unplug DP-1 with surfaces open: no crash, surfaces on the removed monitor close, workspace strips follow `auto-workspace-monitors.sh` |
| Lock | lock/unlock 50 times; kill `qs` while locked 10 times (P-12); wrong password, faillock; media keys while locked |
| Logout | an unsaved document blocks with the "still open" card; "Close anyway" works; lease released ≤ 1 s after Hyprland exits |
| Theme | dark ↔ light and every accent: shell crossfade 400 ms; every installed target updated or marked "next start" within 1.5 s |
| Performance | every budget in [07](07-architecture.md) §12 |
| Accessibility | every surface fully usable with the keyboard only; tooltips on every icon-only control; text scale 1.25 without clipping |

## 4. Migration from v1

1. **Tag** the current `main` (`337d6c7`) as `v1-final` and push the tag (approved, D-22).
2. **Branch** `v2` from `v2-design`. S1's first commit removes v1's `shell/`, `greeter/`, `system/`,
   `packages/`, `theme/`, `config/`, `hypr/`, `docs/`, `HANDOFF.md`, `aptus-lint.*` and v1's `bin/`
   scripts; v1 stays reachable through the tag.
3. **Leftovers outside the repo** (found on this laptop on 2026-11-07). `install.sh` lists them and,
   after Lenno approves, **moves** them (never deletes) to
   `~/.local/state/aptus-v1-backup/<date>/`:
   - `~/.config/aptus/config`, `hypr`, `theme` (symlinks into the v1 repo) and v1's
     `~/.config/aptus/settings.json` (v1 format, no `"v"` key, so v2 would ignore it anyway);
   - `~/.local/state/aptus/{color-mode, hyprland-colors.lua, hyprland-look.lua,
     hyprland-look.lua.before, login-wallpaper, wallpaper, snapshots/}`;
   - `~/.local/bin/aptus-ai-usage`, `aptus-packages`, `aptus-settings-watchdog`,
     `aptus-theme-apps` (links to v1 scripts); `~/.local/bin/aptus` is re-pointed to v2's CLI.
4. `/etc/greetd/config.toml.aptus` and `config.toml.before-aptus` are v1 leftovers owned by root.
   v2 never touches `/etc`; Lenno can delete them by hand (`sudo rm …`) if wanted. The greeter
   itself stays as it is.
5. `CLAUDE.md`, `README.md` and `PHASES.md` are rewritten for v2 in S1 (today's `CLAUDE.md` still
   describes the HP ENVY and the shell-switch).

## 5. Packages

| Package | Source | Why | Who installs |
|---|---|---|---|
| `qt6ct` | Fedora | Qt apps without KDE in Hyprland ([02](02-isolation.md) row 5) | installed 2026-11-07 |
| `hyprsunset` | COPR `sdegler/hyprland` (already enabled for Hyprland) | night light | installed 2026-11-07 |
| `ddcutil` | Fedora | optional, brightness of external monitors | only if wanted |

Already installed and used: Quickshell 0.3.2, Hyprland 0.57.1, hyprlock, `wl-clipboard`, `cliphist`,
`wtype`, `plocate`, `fd-find`, `brightnessctl`, `satty`, `wf-recorder`, `ffmpeg-free`,
`libva-intel-media-driver`, `python3-icalendar`, `python3-dateutil`, `fprintd`,
`qt6-qtimageformats`, `kf6-kimageformats`, Inter, Inter Display, JetBrains Mono, Papirus.

Never installed for aptus: `adw-gtk3` (it would change Umbriel through Noctalia's hook), fonts in
`~/.local/share/fonts`, another notification daemon (mako, dunst, swaync), another wallpaper daemon
(hyprpaper, swww), another polkit agent, XDG autostart entries.
