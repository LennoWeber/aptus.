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

## P-04 · recovery before the next compositor — **pre-check: the assumed order does not hold; fallback** (2026-11-09, read-only)

The full probe needs a hard power-off with a held lease; Lenno runs it (steps below). A read-only
pre-check on the current boot already tests the premise of 02 §7 ("finishes before the user
manager reports ready"):

| Event (this boot, monotonic) | Time |
|---|---|
| user manager starts its default transaction | 104.252 s |
| `basic.target` reached | 104.2748 s |
| `user@1000.service` active (READY=1 received by PID 1) | 104.2751 s |
| `default.target` reached, "Startup finished in 192ms" | 104.2947 s |
| greetd's next PAM module (`pam_kwallet5`) runs | 104.3059 s |

The user manager (systemd 259) reports ready at **basic.target**. `Before=default.target` therefore
does not hold greetd back. Ordering the unit before basic.target is not possible:
- the dconf restore needs `dconf.service`, which has default dependencies (After=basic.target);
- that order would deadlock until the timeout.

(`dbus-broker.service` itself is `Before=basic.target`, so the bus would be available.)

**Path:** the designed fallback. The unit starts with the user manager (`DefaultDependencies=no`)
and races the session start. A late recovery affects only apps started in that window; dconf
values reach running apps live. 02 §7, the exit matrix and the unit comment are updated.

A possible improvement, Lenno's call (not built):
- restore file and ini slots in a unit before basic.target (no D-Bus);
- leave the dconf keys to a second, transient run after it.

**Steps for Lenno** (after S2 is installed with `install.sh`; about five minutes):
1. `systemctl --user is-enabled aptus-recover.service` prints `enabled`.
2. Log into the Hyprland session. `aptus-lease status` shows `state: held`. Open a terminal so
   the session is in normal use.
3. Hard power-off: hold the power button for about 10 s. The guard cannot run.
4. Power on and log into **Umbriel** at the greeter.
5. In Umbriel, run:
   ```sh
   systemctl show "user@$(id -u).service" -p ActiveEnterTimestampMonotonic
   journalctl --user -b -o short-monotonic --no-pager | grep -m2 -E "Reached target (basic|default).target"
   journalctl --user -b -o short-monotonic --no-pager -u aptus-recover.service
   pgrep -l -f umbriel | head -3
   ```
   For the compositor's pid from the last line, `awk '{printf "%.2f s\n", $22/100}'
   /proc/<pid>/stat` gives its start time in seconds since boot. `systemd-analyze --user
   critical-chain aptus-recover.service` gives the unit's own chain.
6. `aptus-lease status` shows no journal, `ls ~/.local/state/aptus/lease/history/ | tail -1`
   shows the new entry, and `aptus doctor isolation` passes.
7. Pass if "Finished aptus-recover.service" is earlier than the compositor's start time. Otherwise
   the fallback stands, and the margin tells whether the split above is worth building.

## P-05 · a running GTK 3 app re-reads user CSS — **no; new windows only (fallback)** (2026-11-09, nested)

The setup:
- Nemo (GTK 3) ran in a nested Hyprland with a temporary HOME.
- `gtk-3.0/gtk.css` contained `@import url("noctalia.css")`, and `noctalia.css` set a red window
  background.

Results:
- Rewriting `noctalia.css` (atomic rename) to green: the running window stayed red for 5 s.
- Closing the window and opening a new one: green.
- No `gtk-theme` toggle was tried. 02 §5.5 makes `gtk-theme` record-only, so aptus never writes it.

**Path:** the accepted fallback. GTK 3 colours apply to new windows. libadwaita/GTK 4 light/dark
stays live through `color-scheme`. 02 §4 row 1 and the 08 reload table now say so.

## P-06 · kitty with `KITTY_CONFIG_DIRECTORY` and a symlink mirror — **pass** (2026-11-09, nested)

Kitty 0.49.2. The temporary HOME held:
- `~/.config/kitty/kitty.conf` with `include themes/noctalia.conf`, and `themes/noctalia.conf`
  with a red background;
- a mirror whose `kitty.conf` is a symlink to the real one, and whose `themes/noctalia.conf` is a
  real file with a green background.

| Check | Result |
|---|---|
| `kitty +runpy` with `load_config`, `KITTY_CONFIG_DIRECTORY=<mirror>` | background `#00ff00`: the relative `include` resolves inside the mirror |
| the same without the variable | `#ff0000` (the real config, as Umbriel sees it) |
| a nested kitty started with the variable | shows the mirror's colours |
| rewrite the mirror file, `SIGUSR1` to that kitty (this HOME only) | live change to the new colour |

Kitty 0.49 has no `--debug-config` flag, so the check uses `kitty +runpy`.

**Path:** the scope design (02 §4 row 6) as specified, with `SIGUSR1` as the reload.

## P-07 · Ghostty reloads on `SIGUSR2` — **pass** (2026-11-09, nested)

The setup:
- Ghostty 1.3.1 in a nested Hyprland with a temporary HOME;
- `config` set `theme = noctalia`, and `themes/noctalia` set a red background.

Results:
- Rewriting the theme to green: no change after 1 s, because Ghostty does not watch the file.
- `SIGUSR2` to that Ghostty's pid (this HOME only): green within 0.5 s.

**Path:** `signal:ghostty:SIGUSR2`, as designed (08 §7).

## FileView and a swapped symlink — **not seen; watch a stable file** (2026-11-09, nested, S2)

Quickshell 0.3.2 `FileView` with `watchChanges`:

| Setup | Result |
|---|---|
| path `<dir>/current/resolved.json`; `current` is a symlink swapped atomically to gen-2, then gen-3 | `fileChanged` never fires |
| a stable file replaced by an atomic write (rename) | fires every time (2 of 2) |

**Path:** after each render, aptus-theme writes `state/theme/resolved.json`, a stable file
replaced atomically. Tokens watches that file, not `current/…`. 07 §7 is updated with S2.
