# PHASES.md — aptus v2 work log

The work log for aptus v2, from stage S0 on. The v1 log is in the `v1-final` tag.

- Spec: `design/` (source of truth). Plan: `design/11-roadmap.md` §2. Brief: `design/handoff-prompt.md`.
- Workflow: every stage runs the seven phases of `phasen-entwicklung` back to back (no waiting for
  "weiter"); one commit per phase (`S<n> <area>: phase <k>: …`); each phase is logged here with
  what was done, how it was checked and the result. Reviews after phases 2, 3, 4, 6, 7 are done by
  a fresh subagent that sees only the goal, the phase rules and the diff.
- Branch `v2` (from `v2-design`); `v1-final` = `337d6c7`.

## Status

| Wave | Stages | State |
|---|---|---|
| 0 | S0 probes | P-01, P-03, P-11, P-23 pass; P-14 half; the rest run with their stage |
| 1 | S1 Foundation | next |
| 2 | S2 Isolation ‖ S3 Bar and notch | — |
| 3 | S4 Spotlight ‖ S5 Deck ‖ S6 Session ‖ S7 Windows | — |
| 4 | S8 Time and attention ‖ S9 Capture ‖ S10 Settings and gallery | — |
| 5 | S11 Finish, acceptance | — |

## Open items for Lenno

- Physical-key check of P-01 (virtual keyboards cannot fire binds): during the S1 hands-on round.
- P-22: no finger is enrolled; enrolling is Lenno's choice (machine-wide, Umbriel would see it).

---

## S0 · Probes (2026-11-07)

**Setup.** `v2` branched from `v2-design` (`833275c`), `v1-final` tagged on `337d6c7`, both pushed.

**What ran.** A nested Hyprland with a temporary `HOME`, a private D-Bus (`dbus-run-session`) and
`HYPRLAND_NO_SD_VARS=1` (so the real user manager's environment is never touched), the full
`09-hyprland.md` Lua, and a 60-line probe shell. Results with details: `design/probes.md`.

| Probe | Result | Consequence |
|---|---|---|
| P-01 | pass: `aptus:*` listed; dispatch → handler median 0.8 ms | binds use `hl.dsp.global` |
| P-03 | pass; every rule effect, expression, dispatcher and option accepted | **spec fix:** `bind()` in 09 §7 unbinds a chord only once (the Super hold bind deleted the tap bind) and no longer mutates the shared `L`/`R` option tables |
| P-11 | pass: mask click-through, away catcher, None ↔ Exclusive without remap (30 toggles) | D-08 stays |
| P-23 | pass: `settings.watchFiles` from `APTUS_DEV`, positive control reloads | `aptus dev` sets `APTUS_DEV=1` |
| P-14 | first half passes: the lid block inhibitor is granted to a transient user unit without polkit | second half (lid → lock) in S6 with Lenno |
| P-22 | not runnable: no finger enrolled | runs in S6 if Lenno enrols one |

**Findings for the harness** (recorded in probes.md, used by S1): virtual keyboards never fire
Hyprland binds, so e2e tests dispatch `hl.dsp.global` over the socket; pointer input comes from a
stdlib Wayland virtual-pointer client (`tests/e2e/vpointer.py`), never `ydotool`; `qs ipc` only
sees instances on the caller's `WAYLAND_DISPLAY`.

**Checked by:** each probe's pass condition from 11-roadmap §1, measured as listed; P-03 also
checked negatively (an unknown field is reported, so silence means acceptance).

**Slip:** one `hyprctl notify` test was sent without `-i` and showed a 2-second red "x"
notification in Lenno's real session. No other effect. Rule since then: every `hyprctl` in
development carries `-i <nested signature>`; the e2e harness enforces it (07 §13).

---

## S1 · Foundation

### Phase 1 · plan (2026-11-07)

**Goal.** Everything later stages build on, so that S2–S10 only add or fill files in their own
folders: v1 removal; Python `paths`/`atomic`/`log`/`hypr`; the CLI skeleton; `aptus-session`
(scope-only) and `aptus-supervise`; `install.sh` (non-destructive, diff + approval); the complete
`hypr/` Lua (09); `theme/tokens.json` with every token of 03 and 04; `Tokens`, `Motion`, `Config`
(full schema of 10), `Paths`, `Log`, `Format`; the `SurfaceManager` with every surface id and the
transition rules of 07 §5; every `GlobalShortcut` and `IpcHandler` of 07 §7 (stubs routed to
service/surface stubs); the component library of 03 §9; `MonitorShell` with the wallpaper,
reserve and shell layers; wallpaper drawing; the frame (one shape with every drawer's bulge) and a
static bar; the test harness (pytest, qmltestrunner, qmllint with 0 warnings, nested Hyprland
with `APTUS_TEST=1`).

**Architecture decisions** (not spelled out in the spec; they make parallel stages possible):

1. **Logic in pure JS, state in QML.** Transition rules, config validation, colour maths, format
   helpers and the frame path live in `.pragma library` files under `shell/core/js/`; the
   singletons are thin wrappers. qmltestrunner tests the JS directly (Quickshell's `Singleton`
   needs `qs`).
2. **Stub files for every stage-owned root type.** `MonitorShell` and `shell.qml` instantiate
   `Bar`, `Notch`, `Deck`, `Overview`, `CaptureOverlay`, `RecFrame`, `Lock`, `SettingsWindow` from
   their stage folders; `NotchModes.qml` maps notch-mode ids to `Spotlight`, `Switcher`, `Today`,
   `SessionSheet`, `PolkitPrompt`, `Gallery`, `Jot`, `Keys`, `FocusPicker`. S1 writes each as a
   stub with the final interface; the owning stage fills it and never needs to touch
   `MonitorShell`.
3. **One frame shape.** `Frame` draws the frame band and every open drawer's bulge as one path
   (the content area's outline gets a dent per bulge), so drawers are seamless with any alpha
   (glass). Drawers publish a `BulgeSpec` (x, width, height, cove, dock: `top` | `topLeft` |
   `topRight` | `topFull`); the path maths is `core/js/bulge.js`. Fullscreen slide-out (M-31) and
   the frame half of the intro (M-01) are in `Frame`, so S3 never edits it.
4. **Notch-mode contract** (`components/NotchMode.qml`): `monitorName`, `args`, `active`
   (false while leaving), `bulgeWidth`/`bulgeHeight` (what the notch springs to),
   `takesKeyboard`, `back(): bool` (Esc ladder: true when it stepped back internally),
   `closeRequested()`. Drawers (`Deck`, `Overview`) have the same `back()` and a `bulge` spec.
5. **Esc ladder** = `SurfaceManager.back()`: close the menu; else call the top surface's
   registered back function; when it returns false, close the surface.
6. **Services as stubs with their action methods.** `services/qmldir` lists every service of
   07 §6 plus `Switcher`, `Progress` (notch §11); each stub already has the methods the shortcut
   and IPC registries call (`Audio.stepVolume`, `Media.toggle`, `Focus.toggle`, …), logging
   "not available yet" until its stage fills it. `Hypr` (monitors, focused monitor, active
   window, fullscreen per monitor, toplevel geometry for the away catcher) and `Wallpaper`
   (resolution and drawing; gallery, rotation, analysis are S10) are implemented in S1 because
   the manager and the wallpaper layer need them.
7. **Config**: `Config.get(key)` reads a `revision` counter so bindings re-evaluate on change;
   `set/reset`, validation from the schema (types, ranges, enums, cross-key rules of 10), atomic
   debounced write of non-defaults with `"v": 2`, unknown keys kept, a v1 file (no `"v"`) is never
   read and is backed up to `settings.json.v1` before the first write.
8. **Test mode**: `APTUS_TEST=1` derives every XDG path from `HOME` (inherited `XDG_*` outside
   `HOME` are ignored), runtime flags go to `$HOME/.aptus-run/`, logs to `$HOME/aptus-*.log`,
   `aptus-lease`/units/env import refuse or skip, and `hypr.py` refuses to talk to the instance in
   `APTUS_REAL_HYPRLAND_SIGNATURE` (set by the harness from the parent session).
9. **Locking never fails open**: the `Super+L` command becomes
   `aptus msg session lock || hyprlock -c <aptus conf> || hyprlock` (the aptus conf only exists
   after S2's first render); 09 §7 is updated in phase 7.

**Files** (new unless noted):

| Area | Files |
|---|---|
| v1 removal | delete `shell/ greeter/ system/ packages/ theme/ config/ hypr/ docs/ HANDOFF.md aptus-lint.* bin/*` (v1) |
| Python | `lib/aptus/{__init__,paths,atomic,log,hypr,cli,msg,session,supervise}.py`, `lib/aptus/doctor/{__init__,config,deps}.py`, `lib/aptus/install/{__init__,hyprlua}.py` |
| bin | `aptus`, `aptus-session`, `aptus-supervise` (thin launchers into `lib/aptus`) |
| hypr | `hypr/{init,env,look,motion,rules,binds}.lua` (09, complete) |
| theme | `theme/tokens.json` |
| shell core | `shell/shell.qml`, `shell/core/{qmldir,Tokens,Motion,Config,Paths,Log,Format,SurfaceManager,MonitorState,Shortcuts,Ipc,NotchModes}.qml`, `shell/core/js/{colour,rules,config,format,bulge,sun}.js` |
| components | `shell/components/{qmldir,Bulge,BulgeSpec,NotchMode,Label,Glyph,Wash,FocusRing,Button,IconButton,Tile,Switch,Slider,Segmented,Field,Keycap,Ring,Level,Row,List,Menu,MenuHost,Tooltip,Badge,EmptyState,AppIcon,Thumb,Scrim}.qml` |
| services | `shell/services/qmldir` + one file per service (stubs; `Hypr`, `Wallpaper` implemented) |
| surfaces | `frame/Frame.qml`, `wallpaper/WallpaperLayer.qml`, `bar/Bar.qml` (static skeleton), stubs: `notch/Notch.qml`, `deck/Deck.qml`, `overview/Overview.qml`, `capture/{CaptureOverlay,RecFrame}.qml`, `lock/Lock.qml`, `settings/SettingsWindow.qml`, `spotlight/Spotlight.qml`, `switcher/Switcher.qml`, `today/Today.qml`, `session/SessionSheet.qml`, `polkit/PolkitPrompt.qml`, `gallery/Gallery.qml`, `jot/Jot.qml`, `keys/Keys.qml`, `focus/FocusPicker.qml`, each folder with its `qmldir` |
| windows | `shell/windows/MonitorShell.qml` |
| config | `shell/config/settings-schema.json` |
| assets | `shell/assets/fonts/MaterialSymbolsRounded.ttf` + `LICENSE` (Apache 2.0, from google/material-design-icons) |
| install | `install.sh` (rewritten) |
| tests | `tests/run` (all), `tests/lint.sh` (qmllint), `tests/unit/test_*.py`, `tests/qml/tst_*.qml`, `tests/e2e/{nested.py,vpointer.py,hyprland.lua,test_s1.py}` |
| docs | `README.md`, `CLAUDE.md` (v2 status lines), `.gitignore` |

**Risks.** (a) The frame path rebuilt per animation frame could cost GPU time on the UHD 630:
measured in phase 7 (frame time in the nested session), fallback is a separate shape per bulge
overlapping the bar by 1 px (only visible with glass). (b) Quickshell IPC with optional arguments:
checked in phase 5; `aptus msg` pads missing arguments with `""` from `qs ipc show`. (c) `qs ipc`
exit codes when no shell runs decide whether the lock fallback fires: checked in phase 5.
(d) qmllint and `qs.*` imports: the v1 approach (a temporary `qs → shell` link passed with `-I`)
is reused. (e) `pytest` is not installed (needs root, asked); until then tests run in a scratch
venv, and the suite is plain pytest.

**Checks (end of S1).** pytest green; qmltestrunner green; qmllint 0 warnings; nested session:
the shell starts through `aptus-session start` → `aptus-supervise` → `qs`, shows wallpaper, frame
and static bar on the nested output (grim screenshot reviewed), `hyprctl globalshortcuts` lists
every name of 07 §7, `aptus msg shell state` returns JSON, `aptus msg surface open spotlight` /
`back` change the state as 07 §5 says, the reserve layer reserves 32 px, the mask lets clicks
through, `hyprctl configerrors` is empty, `install.sh` in a temporary `HOME` shows the
`hyprland.lua` diff and installs only after "y".

### Phase 2 · structures (2026-11-07)

**Done.**
- `theme/tokens.json`: palettes Ember/Linen with every role, ANSI 16 (08 §3), six accents with
  Papirus and GNOME names, washes, contrast-high and glass amounts, frame line, shadow; type
  families, scale, text-scale steps; glyph and app-icon sizes; geometry, spacing, paddings;
  component dimensions of 03 §9; motion durations, curves, springs, choreography, the M-xx
  catalogue numbers; app fonts and cursor; `surfaces` (512 surface-specific numbers from every
  surface document, extracted by a helper and checked here).
- `shell/config/settings-schema.json`: all 120 keys of 10-settings (92 + 28 expanded provider
  keys) with type, default, values/labels, range, page, section, label, description, keywords,
  `visibleIf`, notes; pages; templates; cross-key rules. Checked mechanically against the
  10-settings tables: no key missing or extra, every default equal.
- QML types: `MonitorState`, `BulgeSpec`, `NotchMode`, `Drawer`; property declarations of
  `Tokens`, `Motion`, `Config`, `Paths`, `Log`, `Format`, `SurfaceManager`; 30 service stubs
  (owner stage in each header); 28 component types; 21 surface root types; module `qmldir`s
  (`qs.core`, `qs.components`, `qs.services`, `qs.surfaces.<name>`, `qs.registry`,
  `qs.windows`).
- Python: `Paths` dataclass, `Mode`/`StartReport`, `RestartPolicy`/`CrashLog`, `Check`,
  `Removal`/`Plan`, `HyprError`/`RefusedInstance`.
- Material Symbols Rounded (variable, Apache 2.0) in `shell/assets/fonts/` with its licence.

**Changes to the plan found while writing.**
- Module order core ← components ← services ← surfaces ← registry ← windows ← shell.qml, to
  avoid import cycles: `Shortcuts`, `Ipc`, `NotchModes` moved from `qs.core` to `qs.registry`;
  core gets service data through `Binding`s in `shell.qml` (`Tokens.wallpaperHue`,
  `SurfaceManager.activeMonitor/currentWindow/locked`); `Notch` receives the mode components as
  `modeComponents` instead of importing the registry.
- Surface types that would collide with service singletons are named `SwitcherStrip`,
  `KeysSheet`, `JotSheet`.
- The lid state moved from `Power` to `Session`, so no file has two owners in the same wave.
- Spec fix: the overview's drop height is 330 px (overview.md §2, from its card layout);
  04-motion M-14 said 320 and is corrected.

### Phase 3 · signatures (2026-11-07)

**Done** (placeholder bodies throw / `raise NotImplementedError`; nothing is called yet):
- `shell/core/js/`: `colour.js` (sRGB ↔ OKLab/OKLCH, `over`, `toward`, hue distance),
  `resolve.js` (08 §3: `resolve`, `accentFor`, `groundAlpha`, the role order), `rules.js`
  (07 §5 / 05 §2–§3 as pure functions over plain state: open/close/toggle/back, post/dismiss/
  arbitrate/expire, menus, monitor add/remove/active, lock, fullscreen, settings focus; surface id
  lists and the 30 s / 4 s constants), `config.js` (defaults, validate, crossCheck, load,
  serialise, equal, visible), `format.js` (03 §4), `bulge.js` (normalise, framePath,
  bodiesPath), `sun.js` (NOAA times, modeAt, nextChange; 07:00/19:00 fallback).
- QML singletons: `SurfaceManager` (open/close/toggle/back/post/dismiss/state/isOpen/
  monitorState, menus, back handlers, settings focus, syncMonitors and internals), `Config`
  (get/set/reset/resetPage/validate/entry/reload), `Tokens` (resolveNow/apply/alpha/font),
  `Motion` (ms/curve/spring), `Log`, `Format` (wrappers), `Paths` (expand/insideHome/url/
  ensureDir).
- `qs.registry`: `Shortcuts` (the 44 names of 07 §7, pressed/released), `NotchModes` (ids,
  component()), `Ipc` (every target and function of 07 §7 as `IpcHandler`s).
- Service action methods the registries call: Hypr (dispatch, focusWindow, windowAt, monitor),
  Wallpaper (pathFor, set, next), Audio, Brightness, Media, Switcher, Session, Theme, Focus, Dnd,
  Capture, Jot, Notifications.inject. Other services get their methods from their own stage.
- Components: `NotchMode.back()`/`Drawer.back()` (default false: the contract's real default),
  `Menu.moveCurrent/triggerCurrent`, `Field.forceFocus/selectAll/clear`.
- `hypr/init.lua` (generated-value defaults), `hypr/binds.lua` (`G`, `bind`, `LOCK`,
  `overrides`, `unbound`, `L`, `R`).
- Python: `paths.resolve/get/inside`, `atomic.write_bytes/write_text/write_json/fsync_dir/
  symlink`, `log.level_from_env/setup`, `hypr.signature/socket_path/request/request_json/
  dispatch/eval_lua/notify/config_errors`, `msg.parse_show/build/call/main` + `ALIASES`,
  `cli.parser/cmd_logs/cmd_dev/main`, `session.check_environment/start/write_status/
  exec_supervisor/stop/main`, `supervise.shell_command/next_delay/crashed_out/on_crash_limit/
  run/main`, `doctor.run/render/main`, `doctor.config.check/validate`, `doctor.deps.check` with
  the package lists, `install.v1_leftovers/plan/plan_uninstall/describe/apply/main` +
  `install/__main__.py`, `install.hyprlua.statements/plan_install/plan_uninstall/diff/
  removed_lua/parse_removed` + the removal patterns and the block text.
- Test skeletons: `tests/conftest.py` (temp-HOME fixture), 13 `tests/unit/test_*.py`, 7
  `tests/qml/tst_*.qml`, `tests/e2e/nested.py` (harness API), `tests/e2e/test_s1.py`;
  `tests/e2e/vpointer.py` moved unchanged from the S0 probe (already working code).

**Reported (gaps of earlier phases, filled here because the signatures need them).**
- Phase 2 missed `windows/MonitorShell.qml` (its `qmldir` entry existed) and the
  `install.Action` record; both added with properties/fields only.
- `dnd for <duration>`: `for` is reserved in JavaScript, so the `IpcHandler` function is
  `forDuration` and `aptus msg` maps the name (`msg.ALIASES`); 07 §7 updated.
- Phase-1 decision 9 (lock never fails open) lands in `binds.lua`'s `LOCK`
  (`aptus msg session lock || hyprlock -c <conf> || hyprlock`); 09 §7 is updated with the rest
  of the Lua in phase 7.
- Checked: a property named `on` (Glyph, Tile, Wash, IconButton, Dnd) loads and lints cleanly
  in Qt 6.11.
