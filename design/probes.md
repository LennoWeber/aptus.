# Probe results

The probes of [11-roadmap.md](11-roadmap.md) §1, as run on the laptop (ThinkPad P1 Gen 2, Fedora 44,
Hyprland 0.57.1, Quickshell 0.3.2 / Qt 6.11). One section per probe: date, how it was run, the
result, and the path chosen. A probe that is not listed has not been run yet.

## How the nested probes run

All probes marked *nested* ran in a Hyprland nested in Lenno's session, isolated like the e2e
harness will be ([07-architecture.md](07-architecture.md) §13):

```sh
env -u HYPRLAND_INSTANCE_SIGNATURE HOME=<tmp>/home \
    HYPRLAND_NO_SD_VARS=1 HYPRLAND_NO_SD_NOTIFY=1 \
    dbus-run-session -- Hyprland --config <tmp>/cfg/hyprland.lua
```

- `HYPRLAND_NO_SD_VARS=1` is required: without it the nested Hyprland would run
  `systemctl --user import-environment` and overwrite `WAYLAND_DISPLAY` and
  `HYPRLAND_INSTANCE_SIGNATURE` in the real user manager.
- `dbus-run-session` gives the nested session a private session bus, so a test shell never claims
  `org.freedesktop.Notifications`, the tray watcher or portal names on the real bus. The shell is
  started from inside the nested Hyprland (`hyprctl -i <sig> dispatch 'hl.dsp.exec_cmd(…)'`) so it
  inherits that bus and the temporary `HOME`.
- **Virtual keyboards do not trigger Hyprland binds.** `wtype` types into windows of the nested
  session but never fires a bind, so tests drive shortcuts with `hl.dsp.global("aptus:<name>")`
  over the Hyprland socket (the same dispatcher a bind calls) and type into surfaces with `wtype`.
- **Pointer input** comes from `tests/e2e/vpointer.py`, a stdlib-only Wayland client for
  `zwlr_virtual_pointer_v1` that only ever connects to the nested socket (`ydotool` is not used:
  it writes to `/dev/uinput` and would reach the real session).
- **`qs ipc` filters instances by `WAYLAND_DISPLAY`.** A call from outside the nested session must
  set `WAYLAND_DISPLAY` to the nested socket (or pass `--pid`), otherwise it reports "No running
  instances". `aptus msg` inherits the caller's display, which is right inside a session.

## P-01 · global shortcuts reach Quickshell — **pass** (2026-11-07, nested)

- `GlobalShortcut { appid: "aptus"; name: … }` objects (created by a `Variants`, one per name)
  appear in `hyprctl globalshortcuts` as `aptus:spotlight`, `aptus:deck`, `aptus:super-tap`, ….
- Latency, dispatcher to handler: 20 dispatches of `hl.dsp.global("aptus:spotlight")` written
  straight to `.socket.sock`, timestamp before the write vs. `Date.now()` in `onPressed`:
  min 0.0, median 0.8, max 1.2 ms (budget 10 ms). A bind adds only Hyprland's key matching.
- Note: a `Repeater` directly under `ShellRoot` creates nothing (it needs an `Item` parent); the
  shortcut registry uses `Variants`/`Instantiator`.
- **Path:** binds use `hl.dsp.global` as designed. Lenno confirms physical keys during the S1
  hands-on round (virtual keyboards cannot fire binds, see above).

## P-03 · Hyprland 0.57 Lua details — **pass, one spec fix** (2026-11-07, nested)

The complete Lua of [09-hyprland.md](09-hyprland.md) §4–§8 loaded with `hyprctl configerrors`
empty. Unknown fields are reported (`hl.window_rule: unknown field 'bogus_effect'`), so an empty
error list means every name was accepted.

| Item | Result |
|---|---|
| `require("aptus.init")` from `<config dir>/aptus/`, nested `require("aptus.look")` … | works; `package.loaded["aptus.gen"]` is shared between the modules |
| window-rule `center` | 920×640 window centred exactly ((931−920)/2, (1002−640)/2) |
| `pin`, `keep_aspect_ratio`, `idle_inhibit = "fullscreen"` | accepted; PiP window `pinned: true` |
| expressions in `size`/`move` (`monitor_w*0.7 monitor_h*0.6`, `monitor_w*0.15 40`, `monitor_w-494 monitor_h-284`) | evaluated exactly (651×601 at 140,40; 480×270 at 437,718 on a 931×1002 output) |
| curve `{ type = "spring", mass, stiffness, damping }` | accepted |
| `hl.dsp.window.move({ direction = "up" })` | swaps the tiles |
| `hl.dsp.window.move({ workspace = 3, follow = false })` | moves, focus stays |
| `hl.dsp.focus({ workspace = "m+1" })` / `"m-1"` | next/previous *existing* workspace on the monitor |
| `hl.dsp.workspace.toggle_special("scratch")` + a `workspace.created` handler (the `on_created_empty` rule is deprecated in 0.57.1, S1) | the scratch terminal starts in `special:scratch` |
| `hl.unbind("SUPER + C")` | removes the bind |
| `hyprctl eval 'hl.config({ general = { col = { active_border = … } } })'` | applies at runtime (`getoption` shows the new gradient) |
| bind options `release`, `long_press`, `transparent`, `locked`, `repeating`, `description` | accepted; `hyprctl binds -j` shows `release`, `longPress` and the description |
| `hl.gesture({ …, action = function() … end })` | accepted |

**Spec fix.** `SUPER + Super_L` carries two aptus binds (tap on release, hold on long press). The
`bind()` helper of 09 §7 called `hl.unbind(chord)` before every bind, so the hold bind deleted the
tap bind. The helper now unbinds a chord only the first time aptus binds it in a load, and copies
`opts` instead of mutating the shared `L`/`R` tables. Verified: both `Super_L` binds coexist
(`rel=True` and `lp=True`). [09-hyprland.md](09-hyprland.md) §7 is updated.

## P-11 · one full-monitor Overlay layer with a changing mask — **pass** (2026-11-07, nested)

A `PanelWindow` (Overlay, `aptus-shell`, anchored on all edges, `ExclusionMode.Ignore`) with
`mask: Region { item: open ? full : bar }` and `keyboardFocus: open ? Exclusive : None`:

| Check | Result |
|---|---|
| closed: click on a window below the layer | the window is focused |
| closed: click inside the bar mask | the layer gets it; the active window does not change |
| open: click on a window area (away catcher) | caught by the layer; the active window does not change |
| open: typing | key events reach the layer, none reach the window |
| close | Hyprland gives keyboard focus back to the window that had it |
| 30 open/close toggles | no `openlayer`/`closelayer` event on socket2, the layer address never changes (no remap) |

**Path:** the single-layer design (D-08) stays. The 30-minute "no stuck pointer or keyboard" soak
happens during normal use from S3 on; any regression switches to the fallback (one layer per
drawer).

## P-23 · file watching off in normal runs — **pass** (2026-11-07, nested)

`ShellRoot { settings.watchFiles: Quickshell.env("APTUS_DEV") === "1" }`:

- without `APTUS_DEV`: editing `shell.qml` in place does not reload the shell;
- with `APTUS_DEV=1` (positive control): the same edit reloads it within a second.
- Replacing the file (`sed -i`, new inode) was not picked up even with watching on; editors that
  write in place or keep the inode reload normally. Irrelevant for normal runs.

**Path:** `shell.qml` sets `settings.watchFiles` from `APTUS_DEV`; `aptus dev` exports it.

## P-14 · lid inhibitor without polkit — **first half passes** (2026-11-07)

`pkaction` shows `org.freedesktop.login1.inhibit-handle-lid-switch` with `implicit any: no`, so a
process outside a session could have been refused. It is not: a transient user unit
(`systemd-run --user --wait --collect systemd-inhibit --no-ask-password --what=handle-lid-switch
--mode=block true`) takes the block inhibitor with exit code 0 and no prompt, as does a process in
the session scope. The second half (lid closed → lock only; after logout, logind's own policy
again) needs Lenno's hands and the S6 lock; it runs then.

## P-22 · fingerprint — **not runnable yet** (2026-11-07)

`fprintd-list lenno`: one Synaptics reader, **no finger enrolled**. `lock.fingerprint` stays off by
default and hidden while nothing is enrolled. Enrolling (`fprintd-enroll`) is machine state that
Umbriel would also see; it is Lenno's choice and not part of aptus. The probe runs in S6.

## P-17 · Material Symbols FILL/wght animated through `font.variableAxes` — **pass** (2026-11-09, nested)

A probe shell (`qs -p`, inside the nested session) with 30 glyphs of the bundled
`MaterialSymbolsRounded.ttf` (40 px) in one Overlay layer; each glyph animates FILL 0 ↔ 1 and wght
400 ↔ 500 every 140 ms through `font.variableAxes`, then the same 30 glyphs as the fallback (two
`Text`s, FILL 0 and FILL 1, cross-faded). A `FrameAnimation` records frame intervals; 6 s each.

| Mode | Frames | Mean | p50 | p95 | p99 | Max | > 20 ms |
|---|---|---|---|---|---|---|---|
| axes (`font.variableAxes`) | 330 | 16.66 ms | 17 | 17 | 20 | 26 | 3 |
| cross-fade (fallback) | 329 | 16.67 ms | 17 | 17 | 18 | 19 | 0 |

Three screenshots 70 ms apart differ in ink (4254 / 3936 / 4241 grey-sum units over the glyph
rows): the axes really change the rendered outlines, not just the opacity. 30 glyphs animating at
once is far more than the shell ever does (one glyph per state change).

**Path:** `Glyph.qml` keeps animating FILL and wght through `font.variableAxes` (03 §5, M-03); the
cross-fade fallback is not needed. (A probe note: inside a `Text`, `font` names the Text's own font
property, so a `FontLoader` must not have the id `font`.)

## P-20 · aptus owns `org.freedesktop.Notifications` — **pass** (2026-11-09, nested)

- Activatable services on this machine (read only): only
  `/usr/share/dbus-1/services/org.kde.plasma.Notifications.service` (`Exec=plasma_waitforname`,
  starts no server for the freedesktop name); mako, dunst and swaync are not installed. On the
  real session bus the name belongs to Noctalia (Umbriel); the aptus session never runs Noctalia.
- Nested session (private bus of `dbus-run-session`): with the shell running,
  `GetServerInformation` answers `('quickshell', 'quickshell', '', '1.2')`; `notify-send -a Kitty
  -A ok=OK -A no=Later 'Build finished' '<b>…</b>'` shows the toast with markup and two buttons;
  `-u critical` stays until dismissed and shows over a fullscreen window; `CloseNotification`
  from the sender removes it.
- `NotificationServer` has no "registered" signal, so `Notifications.serverActive` comes from a
  one-shot `GetServerInformation` call 1.5 s after start (true when it names Quickshell; a warning
  names the other server otherwise).

**Path:** no doctor check is needed (it was the fallback if another server could take the name).
