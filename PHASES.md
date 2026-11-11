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
| 1 | S1 Foundation | done: phases 1–7, wave-1 review, simplify |
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

### Review of phases 2 and 3 (2026-11-07)

Two fresh reviewers (phase-2 diff `234a4d3..af12051`, phase-3 diff `af12051..3cb08c8`). Both arrived
after phase 3 was committed, so their fixes share one commit; structure fixes follow phase-2 rules,
signature fixes phase-3 rules.

**Phase 2: accepted and fixed**
- `Bulge.top` shadowed Item's FINAL `top` (the frame would not load) → `barHeight`.
- `enabled` redeclared in 8 components (lint warnings, broke disabling of children) → removed,
  the inherited `enabled` is used.
- Name clashes with QtQuick: the `Keys` service hid the `Keys` attached type, `Row` hid the
  positioner → `Binds` service, `ListRow` component; rule in 07 §2: QtQuick.Controls only with a
  namespace.
- tokens.json held copies of settings (idle times, close timeout, history limits, clipboard size,
  focus durations, slider steps, ranges) and of the supervisor policy → removed (the schema and
  `supervise.py` own them). 124 surface numbers that duplicated `geometry`, `components`,
  `motion.durations` or `motion.catalogue` removed after a check that every pair was equal; the
  surface groups now hold only surface-specific numbers (512 → 369). `activityPriorities` and
  `matchScores` are maps.
- Same-file edits by parallel stages: `Paths.qml` now has every path of 07 §9 (with the owning
  stage); an extension point for the notch: `Activity` (live activities) and `NotchCard` (result
  cards shown as toasts with `payload.card`) base types, the `qs.registry` `Activities` table, and
  stubs in each owner's folder (`notch/MediaActivity`, `notch/ProgressActivity` S3;
  `focus/FocusActivity`, `focus/TimerActivity`, `today/MeetingActivity` S8;
  `capture/RecordingActivity`, `capture/CaptureCard`, `capture/ColourCard` S9;
  `session/StillOpenCard` S6). Service data shapes for what other stages read: Hypr workspaces/
  special/urgent + window actions (S1 implements them), Audio devices and streams, Network list/
  VPN/airplane, Bt devices, Power profiles, Focus state machine, Timers/Agenda/Progress item
  shapes, Capture recording details and last capture, Binds overrides/conflicts/perform (S8 builds
  them, S10 calls them), `Apps.iconFor` (owner S3 for the bar's icons, S4 for the rest).
- Missing shared components → `Checkbox`, `RollingDigits`, `Ellipsis`, `ErrorLine`, `PagerDots`,
  `Swatch` (03 §9 and tokens updated).
- Shared-element interfaces: `Bar.pillRects` → `Overview.pillRects` (M-14), `Notch.clockRect` /
  `NotchMode.clockRect` + `takesClock` (M-20), `CaptureOverlay.selection` + toast
  `payload.flyFrom` (M-23); NotchMode flags `scrim`, `catchesOutside`, `sizeSpring`.
- Spec updated: 07 §2 (layout, registry, module order, SettingsWindow/SwitcherStrip/KeysSheet/
  JotSheet), 07 §5 (capture state `{ mode, args }`; cards and the peek are not interactive), 07 §6
  (lid in Session, Binds, Switcher, Progress).
- Spec contradictions decided: bar padding 8 from the frame edge = 14 from the screen edge
  (bar.md wins, 03 §7 fixed); toast app icon 24 (notch.md wins, 03 §5 fixed); the capture overlay
  lives in `aptus-shell` (one layer, so M-23's flight into the notch is possible; capture.md §3
  fixed); `ambient` token name of 04 used (`Motion.ambientTheme/ambientWallpaper`); button
  padding 12 and badge pill height 16 written into 03 §9.
- Schema: `nightLight.temperature` has no `visibleIf` (the Deck turns night light on by hand);
  `deck.tiles` unique; `dnd.schedule.days` 1–7, unique; `insideHome` also for `list<path>`;
  `wallpaper.dir` `mustExist`; new `bar.tray.order` (settings.md's "drag order"); `deck.*` moved
  to the Bar and frame section in 10 and settings.md §3. Re-checked: schema keys = 10's keys.
- `paths.py`: `hypr_runtime` (the real Hyprland socket dir, also in tests), lease files, theme
  `current`, generated/binds Lua, agenda, clipboard db, runtime flags, caches.
- Smaller: `Tokens.accents`/`neutrals` (neutrals = ink.sec, ink.meta, settings.md §5),
  `Tokens.wallpaperChroma`, `Config.v1File/pending/_backupV1`, Menu rows `keys`/`confirm`,
  `Check.warn`.

**Phase 2: rejected**
- Rename the `on` properties: they load and lint cleanly in Qt 6.11 (checked) and read naturally.
- `type.textScale.barHeight` duplicates the schema's derived `bar.height`: the geometry is a
  design token; the schema entry only documents the derived value. `test_tokens` checks that both
  are equal instead.
- Literal defaults in `Tokens.qml`/`Motion.qml` are a phase-7 matter: every property is bound to
  `raw` there, and a failed tokens.json load is logged as an error.

**Phase 3: accepted and fixed**
- Blocker: the root-level autouse fixture would have removed the real signature before the e2e
  harness read it, and `hypr.signature` refused only on equality → fixture moved to
  `tests/unit/conftest.py`, `tests/e2e/conftest.py` reads the real signature first and provides a
  session `nested` fixture, `hypr.check_allowed` fails closed when the real signature is unknown and
  runs on every request.
- Locking could fail open: `qs ipc call` exits 0 for most errors (probe below) → `msg.classify`,
  exit codes, a 2 s timeout; `session lock` answers `error: …` while the shell cannot lock;
  09 §7 and 07 §10 updated in this commit.
- `START_RE` missed Lenno's three-line autostart → statement-level patterns with `re.S`, comments
  are never statements (a commented-out autostart stays).
- `aptus logs` as specified matched nothing (journalctl ANDs `-t` with `-u`; checked) → two
  queries merged by time; 07 §11 updated.
- The `aptus-session` tag never reached the journal → `log.JournalHandler` (native socket) when not
  under a unit; never in tests.
- `paths.get()` cached across test HOMEs → not cached under `APTUS_TEST`.
- Missing: `settingsFocused` state (+ `setSettingsFocused`, renamed to avoid the clash),
  `post(…, key)` replacing in place and `update()`, `arbitrate(m, now, opts)` returning
  `{ kind, entry }` with the fullscreen and pinned-card tiers, Deck page stack owned by the manager,
  `config.js` `MIGRATIONS`/`migrate`, limits passed in instead of constants in `rules.js`.
- Optional QML parameters: an omitted typed `string` arrives as `"undefined"` (probe) → optional
  parameters of the manager API (and `Wallpaper.set`, `Focus.start`) are `var`.
- Nits: TYPE_CHECKING imports in doctor; deps lists fixed (+ systemd-cat, journalctl, grim,
  Papirus); `--yes-to-base` dropped; `Ipc settings.open(pageOrKey)`; rules.js field names equal
  SurfaceManager's; `menu` removed from the surface ids; `NotchModes.ids` = `rules.NOTCH_MODES`;
  `toggle` returns bool; `test_binds_lua.py`; `aptus dev on|off` is a flag the supervisor reads
  (`supervise.shell_env`); more `tst_rules`/`tst_config` cases.
- Reported: `install/__main__.py`, the conftest `sys.path` lines and `back(): bool { return false }`
  are tiny wiring/behaviour in phase 3 (accepted as the contract defaults); the registry files
  first appeared in phase 3 (phase 2 had only their qmldir entries).

**Probe (phase-5 risks b and c, run early in a scratch shell with a private bus and runtime dir):**
`qs ipc call` with too few arguments, an unknown function, a bad int or a throwing handler prints a
message (or nothing) and exits **0**; with no instance it exits **255**; `qs ipc show` lists
`function name(arg: type): type` per target. `aptus msg` therefore pads arguments from `show`,
classifies the output, and treats an empty answer as an error.

### Phase 4 · TODO markers (2026-11-07)

**Done** (comments only, 110 `TODO(phase)` markers outside PHASES.md; no code):
- Wiring places that exist only as comment files so far: `shell/shell.qml` (watchFiles, Bindings
  into core, monitor sync, MonitorShell per screen with the registry tables, Shortcuts/Ipc/Lock/
  SettingsWindow, start order with the locked marker and the intro flag), `hypr/{env,look,motion,
  rules}.lua` (09 §3–§6 verbatim), `bin/{aptus,aptus-session,aptus-supervise}` (launchers),
  `install.sh`, `tests/run`, `tests/lint.sh`, `tests/e2e/hyprland.lua`, `.qmllint.ini`.
- In the S1 stubs: `MonitorShell` (the three layers, mask/away catcher/keyboard, the surface stack
  with the registry tables, RecFrame), core singletons (tokens/schema/settings FileViews, palette
  resolution and M-30 Behaviors, accents/chroma, migrations and pending keys, debounce, rules.js
  plumbing, limits from tokens, optional-argument normalisation), registries (Variants of
  GlobalShortcuts and the routing table, NotchModes and Activities component tables, Ipc answers
  and the lock fallback), `Hypr` and `Wallpaper` (implemented in S1), the "not available yet"
  bodies of every other service's action methods, every component of 03 §9, `Frame`, `Bar`,
  `WallpaperLayer`, `hypr/init.lua` and `hypr/binds.lua`.
- Docs: `README.md` (v2 rewrite) and `CLAUDE.md` (status lines).

**Missing from phases 2–3 (reported, corrected after the review):** phase 4 created 15
comment-only files that phases 2–3 should have laid down as placeholders: `shell/shell.qml` (the
root type), `bin/{aptus,aptus-session,aptus-supervise}`, `hypr/{env,look,motion,rules}.lua`,
`install.sh`, `tests/run`, `tests/lint.sh`, `tests/e2e/hyprland.lua`, `.qmllint.ini`.
Marker convention: in new Python, JS and test files the placeholder body with its docstring is the
marker (each `raise NotImplementedError` / `notImplemented(…)` / `fail("not implemented")` is a place
to fill); `TODO(phase)` marks wiring that has no placeholder body.

### Review of phase 4 (fresh reviewer, diff `d09b302..c64013b`)

**Fixed (markers and docs only):**
- `Frame`: `barHeight` (not the renamed `top`) and `innerRadius`; M-31 runs on catalogue
  `fullscreen.out/in` (180/240), not the surface timings.
- M-31 fully marked: `Frame.hidden ← monitor.fullscreen`, the 400 ms hot-edge push sets `revealed`,
  the mask while revealed, the Bar follows the frame's hide.
- `shell.qml`: start-order steps 2 (layers start hidden) and 3 (eager Hypr, Notifications, Idle,
  Session, Wallpaper).
- `Tokens`: textScale → barHeight/type, `frame.edge` → frameEdge.
- `Wallpaper`: the resolution chain of wallpaper.md §3 (`monitors` → `byMode` → `all` → newest
  image → ground), filling `images`; `WallpaperLayer`: tile, focus, sourceSize × scale, async.
- `MonitorShell`: `screen: modelData`, transparent layers, introProgress/notchWidth/fill/focus
  wiring, away catcher calls `close(monitor.top, name)`; long TODOs split to two lines (also `Hypr`,
  `Ipc`, `install.sh`).
- `Shortcuts`: overview-open/-close open/close; super-tap and keys-peek honour their settings.
- `Format`: QML `import "js/format.js" as F`. `binds.lua`: TODOs at `G`, `overrides`, `bind`.
- `install.sh`: `python3 -s` with PYTHONPATH (`-I` ignores it); APTUS_TEST refuses when HOME is
  the passwd home; mode 755 noted on every launcher and script.
- `supervise.py`: qs output → `systemd-cat -t aptus-shell`, under APTUS_TEST `$HOME/aptus-shell.log`;
  single-instance flock.
- e2e start path: `nested.py` fills the temp HOME (bin links, config copy with the `aptus` link in
  `<tmp>/cfg`); the `hyprland.start` hook starts the shell, `start_shell` only waits.
- `install`: `~/.config/hypr` is a stow link into `~/dotfiles`, so the `aptus` link would be an
  untracked file there; the plan shows the resolved path and asks for it as its own group.
- `test_install.py`: an install.sh wrapper test marked. `.gitignore` cleanup marked.
- Spec: 07 §3 names the intro flag `intro.<signature>` as the code does; a stray blank line in 09 §7
  removed.

**Gaps for phases 2–3 (filled after the phase-5 probe, with the probe's gaps):**
- Fullscreen never reaches core: `SurfaceManager` needs a `fullscreenMonitors` input (bound from
  `Hypr.fullscreenMonitors` in shell.qml, applied through `rules.setFullscreen`).
- `Session.canLock` (false in the stub) so Ipc's `session.lock` answers without S6 editing Ipc.
- `Bar.hide` (the frame's slide-out amount) for M-31.

### Phase 5 · probe (2026-11-07, thrown away)

**Done.** The whole of S1 implemented inside the placeholders and TODOs on a throw-away branch
(`s1-probe` in a worktree under the session scratchpad; kept outside the repo as the reference
patch for phase 7). Core, rules, config, tokens, services Hypr/Wallpaper, registry, frame, bar,
wallpaper layer, MonitorShell, shell.qml, the Lua of 09, Python tools, the test harness; the
component library by a helper agent.

**Checked.** qmltestrunner: 106 tests pass (config 23, rules 35, bulge/colour/format/resolve/sun).
pytest: unit tests pass (two binds tests skipped, see below). qmllint over all 109 QML files:
0 warnings. Nested Hyprland (`APTUS_TEST=1`, temp HOME): the start chain hyprland.start →
aptus-session → aptus-supervise → qs works; `pytest tests/e2e` 9/9 (shell starts, every
GlobalShortcut listed, `aptus msg shell state`, surface open/back, reserve zone 32 px, mask
click-through with kitty, configerrors empty, no deprecated config, screenshot); grim screenshots
show wallpaper, frame edge, bar reserve and the inner coves; a new image in the wallpaper folder
appears within ~2.5 s; the scratch terminal floats below the bar.

**Problems found and their fixes (they shape phase 7):**
- `Behavior` inside a lazily created singleton crashes qs 0.3.2 (SIGSEGV in
  `QQmlData::deferData`). Tokens crossfades with one `NumberAnimation` on `_t` instead; spec 04 §6.
- Quickshell.Hyprland: two `refresh*()` in the same JS turn leave every list empty, and
  `refreshMonitors()` clears `focusedMonitor` until the next `refreshWorkspaces()`; the shell saw
  no monitor at all. Hypr queues refreshes (`_pending`, `_refresh`), one per 15 ms tick, monitors
  always followed by workspaces; `focused` comes from `Hyprland.focusedMonitor`. Spec 07 §6.
- A lazy singleton starts with its bindings already evaluated, so `on<Prop>Changed` never fires
  for the first value, and a handler can run before a binding on the same property updates.
  Wallpaper lists the folder with `FolderListModel` (the spec's source) instead of `find`. Spec 07 §6.
- Hyprland 0.57.1 deprecates the workspace rule `on_created_empty` (a notification on every
  start). The scratch terminal starts from a `workspace.created` handler; verified that the
  handler gets the workspace and that a reload drops old handlers. Spec 09 §5, probes.md.
- V4's `JSON.parse` gives no error position; config.js scans for it itself (settings.md §4).
- qmllint: GlobalShortcut needs scoped suppressions (its qmltypes lack the Quickshell
  dependency); `.qmllint.ini` needs a `[Warnings]` section; Process.onExited's
  `QProcess::ExitStatus` does not resolve, so `onRunningChanged`; inline components cannot see the
  outer file's ids (WallpaperLayer uses two explicit Images).
- A Python test wrote through the `~/.local/bin/aptus` link of a temp HOME into `<repo>/bin/aptus`
  (restored); `install.apply` must refuse to write through links.

**Gaps, by phase (filled in the same commit as this entry, each under its phase's rules):**
- Phase 2 (structures): `config.load` result `migrated`; passive entries `shown`/`waited`;
  `SurfaceManager.fullscreenMonitors` (list; `Hypr.fullscreenMonitors` becomes a list too),
  `_lastActive`, `_fields`, `_hasPassive`; `Bar.hide`; `Frame.edgeNow`/`barNow`; `Config._v1Text`;
  Tokens `_r`, `_autoMode`, `_themeMs`, `_from`, `_to`, `_t`, colour roles readonly (bound to
  `_blend`); Motion `_m`, `_systemReduced`; Hypr `_windowEvents`, `_pending`; Wallpaper `_dir`;
  Shortcuts `_routes`; WallpaperLayer `_aFront`, `_scale`, `_native`, `_hAlign`, `_vAlign`;
  `Bulge.lineColour`/`lineWidth` (the frame line is the same path stroked); `Session.canLock`; `available` on Focus, Dnd, Capture, Jot (Ipc answers an error while false);
  `CrashLog.streak`/`started`; MonitorState `id: root` + rules.js import; shell.qml's ShellRoot
  with `introProgress`, `_startChecked`, `_ready` (it was comment-only). Components: a
  `ComponentShared` singleton (glyph font loaded once from the repo, tooltip regrace clock, ink and
  state-layer lookups; qmldir line); `MonitorState.menu` gains `anchorX/anchorY` and
  `onTriggered(row)` (nothing carried the chosen row back; 07 §5); `Field.text` an alias of the
  input; `Slider.glyphClicked()`; `disabledReason` on Button and IconButton (`enabled: false` kills
  the hover the tooltip needs); Glyph becomes an Item with two Texts (glyph-swap crossfade, 04 §3
  rule 6, also P-17's fallback); private state of every component (Menu, MenuHost, Tooltip, Tile,
  Slider, Segmented, RollingDigits, …); tokens `surfaces.notch.cardWidth/resultCardHeight/cardHeights`
  (notch.md §5's numbers had no token).
- Phase 3 (signatures): config.js helpers (`isObj`, `clone`, `expand`, `insideHome`,
  `insideHomeTypes`, `fail`, `okv`, `checkInt`, `inValues`, `checkShapeField`, `locateError`,
  `errorPosition`, `sortedStringify`, public `deriveAll`, `TIME_RE`); `resolve.accentFor(…,
  paletteName)`; rules.js helpers (`isCard` … `findEntry`), `tick`, a trailing `now` on
  openMenu/closeMenu/addMonitor/removeMonitor/setActive/setLocked/setFullscreen/
  setSettingsFocused, `expire(m, now, limits)`, arbitrate `opts.limits` (no `recording`);
  `sun.eventMinutes`/`at`/`RAD`; `format.pad2`; `colour.round8`, public `colour.mix` (OKLab; `over`/`toward` build on it, Tokens' crossfade
  blends linearly);
  `bulge.num`; QML helpers `Config._store`, `Paths._xdg`, `SurfaceManager._syncActive`, Tokens
  `_colours`/`_shown`/`_mix`/`_blend`/`_updateAuto`, Hypr `_client`/`_target`/`_refresh`,
  Wallpaper `_list`, Shortcuts `_activeNotch`/`_spotlightScope`, WallpaperLayer
  `_modeFor`/`_load`/`_ready`; new tests `test_derived_follows_text_scale`,
  `test_previous_window_recorded`, `test_logs_without_journalctl`, `test_dev_flag_shell_down`,
  `test_crash_limit_without_marker_only_notifies`, `test_command_and_env`,
  `test_no_deprecated_config`, `tst_components` (14 tests); `List.navigate(key, modifiers)`
  (Spotlight's field keeps the focus and forwards keys); `Motion.catalogueMs(path, out)` (reduced
  motion for catalogue durations); the component helpers. Conventions in the docs: "critical" = priority ≥ 2; menus count as
  interactive but toasts queue only behind interactive notch modes, Overview and Capture (07 §5,
  notch.md §9 now say so). The probe suppressed OSD under the Deck; 05 §2 lets them coexist, so
  phase 7 follows the spec.
- Phase 4 (TODOs): Tokens crossfade and mode `auto`; Hypr refresh queue and `focused`; Wallpaper
  FolderListModel; Config backup `printErrors: false`, `set` refuses cross-rule breaks via
  `_store`; SurfaceManager never writes `activeMonitor`/`locked`, fullscreen input and the
  500 ms tick; Ipc `canLock`/`available` answers and the restart Process; Shortcuts lint
  suppressions; shell.qml fullscreen binding; tests/run `QML_XHR_ALLOW_FILE_READ=1`;
  `install.apply` never writes through links; supervise delay index = streak (the 2 s step is
  reachable when crashes are spread out, e.g. 0, 6, 12 s: no spec change); nested.py removes a
  left-over runtime dir; binds tests run under `/usr/bin/luajit` with a stub `hl`. Components:
  NotchMode and Drawer own the content choreography (04 §3 rule 1); the hosts register back
  handlers (Notch for modes, MonitorShell for Deck and Overview); the mask covers the monitor
  while a menu is open; size defaults from tokens instead of literals (Glyph, AppIcon, Ring, Thumb,
  Activity/NotchCard card heights); Button press scale from tokens (the TODO said 0.97, 03 says
  0.98); Keycap `raised` (the TODO said sunken); `tests/qml/mock` for tst_components
  (qmltestrunner cannot load the real Quickshell plugin).
- Spec, settled where it was silent (03 §9 "Behaviour settled while building the library"):
  controlled inputs, disabled-with-reason, filled-control washes, tile layout, menu and tooltip
  behaviour, List key forwarding; Deck tile labels are the diagram's short forms (52 px beside the
  chevron, deck.md §3).
- Missed by the probe itself: Theme's S1 part (setMode/toggleMode/setAccent/setGlass write
  Config; Super+T needs it) stayed a stub; phase 7 fills it.

- Housekeeping: four `__pycache__/*.pyc` files were committed by mistake in phases 2–4; phase 7
  removes them from the index together with the `.gitignore` TODO.

**Rejected (with reason):** a public `aptus.schema` module and a stable `Check.id` for doctor
(the schema test can import `doctor.config.validate`; check names `config: <key>` are stable).


### Review of the phase-5 gap fill (fresh reviewer, diff `c14c1f7..1b546fa`)

No rule violations (every body a placeholder, defaults literal, the Field alias with a bare
`TextInput` accepted as the structure an alias needs); every listed gap present; lint shows no
syntax errors; tokens.json valid. **Fixed:**
- OSD under the Deck: the probe suppressed it, 05 §2 lets the Deck coexist with OSD, so the
  rules doc follows the spec (phase 7 changes the probe's arbitration accordingly).
- Toasts also queue behind Overview and Capture: written into 07 §5 and notch.md §9 (the spec
  named only interactive notch modes).
- 07 §5 passive entry gains `key`, `shown`, `waited`; Tokens comments name `_themeMs`, not Motion;
  one blend for the crossfade (linear, Tokens._mix). (The review fix also dropped `colour.mix`
  as unused; phase 7 found `over`/`toward` use it and restored it.)
- ComponentShared gets `_glyphFont` (a QtObject has no default property for a FontLoader child).
- `cardHeightMin` → `resultCardHeight` (Progress cards are 80, so "min" was wrong).
- Ring/Thumb TODOs name `thickness`/`radius`; `fullscreenMonitors` moved to SurfaceManager's public
  inputs; `Config._store` documented (how reset() goes through it); `Session.canLock` readonly
  with the public properties; Bulge's reference fixed and its new properties logged; Hypr
  `_windowEvents` comment; 0.57.1 in 09; shell.qml keeps only the imports its structure uses;
  TODOs no longer glued to `id: root`; blank lines in test_binds_lua.py.

### Phase 6 · invariants (2026-11-07)

**Done** (assertions only; placeholders keep their bodies after the checks, no TODO removed):
- `rules.js`: `checkState(monitors, global)` and `checkRequest(req)` (thrown as "rules invariant:
  …"): monitor key = name; a legal notch state; the Deck stack starts with `main`; Overview alone
  (no Deck, notch at rest); never the Deck with an interactive notch mode; capture on all monitors
  or none and never under a menu; no menu or capture while locked; polkit on at most one monitor
  and exactly the one `polkitMonitor` names; queued requests only while polkit is open; settings
  focused ⇒ open; passive kinds legal, ids unique and ≤ `passiveSerial`, keys unique. Every
  public operation checks its input; a TODO makes `finish()` check every result.
- `config.js`: `checkSchema` before every schema use, `checkSerialise` (no `"v"`, no key both an
  override and unknown), `load` takes a string.
- `resolve.js`: `checkInputs` (mode already resolved from `auto`, a known accent or `wallpaper`,
  a known contrast).
- `install`: `check_action` before `apply` does anything: no action outside HOME, inside the repo
  (also through a link), or in Umbriel's/Noctalia's files; moves only into the v1 backup or the
  install state; links only into the repo; only `hyprland.lua` is edited.
- `supervise`: `RestartPolicy` refuses a policy that could spin or never give up; `next_delay`
  refuses a negative streak or a crash before the run started.
- Tests: `test_invariants_reject_broken_state` (runs now, passes), `test_policy_rejects_nonsense`
  and `test_check_action_refuses` (their fixture needs `paths.get`, so they run in phase 7; the same
  checks ran by hand: the policy refuses 5/5 bad ones).

**Checked against the probe** (scratch copies of the probe's libraries with the checks added):
rules with `checkState` after every operation: 34/35 tests pass; the failure is a real bug the
invariant found: when the last monitor that holds polkit goes away, the requests queued behind
polkit stay forever (nothing to replay them onto). Phase 7 drops the queue then
(`test_last_polkit_monitor_removed_drops_queue`). config 23/23 and resolve 12/12 with the
preconditions (one candidate invariant, "the current accent is known", was dropped: the probe
falls back on purpose, the value can come from a resolution written outside). `check_action`
accepts all 14 actions of the probe's install plan with v1 leftovers and the 5 of its uninstall
plan, and refuses a write through a link into the repo and a move out of `~/.config/umbriel`.

**Not asserted, on purpose:** Tokens.apply's input (current/shell.json comes from outside, so it is
validated and ignored when malformed, not asserted); `activeMonitor ∈ monitors` (Hyprland can
report the focus before the monitor list).

### Review of phase 6 (fresh reviewer, diff `d881f03..86ce7e5`; fixed in phase 7)

| Finding | Resolution |
|---|---|
| "Overview ⇒ notch at rest" has no spec rule behind it (polkit is "above everything") | Kept: "Overview alone" (05 §2) and the code close Overview when an interactive mode opens; the rule is now a row of 07 §5. Cards and the Keys peek are refused under Overview. |
| "locked ⇒ no menu or capture" has no spec rule | Kept and specified (07 §5 row "lock"): lock closes menus and Capture at once, everything else stays under the lock. |
| Capture "all monitors or none" breaks on a hot-plugged monitor | Real bug (`addMonitor` would have thrown). A monitor added during the selection cancels it (07 §5, capture.md §7); a removed one drops out. Test added. |
| Missing: capture beside Spotlight/notch modes, polkit in the queue, queue entries unchecked | Added. Capture now closes menus, interactive notch modes, Deck and Overview first unless `includeShell` (capture.md §7, made explicit); never beside polkit; the queue holds no polkit request and every entry passes `checkRequest`. |
| `~/.config/noctalia`, autostart, fonts, user units not protected | Added to `check_action` (leased slots: `TODO(S2)`, the slot table is S2's). |
| A link onto a real file, a move onto an existing target | Already refused by `apply()` at run time; `check_action` is the plan check, where the file in the way still exists (plan() moves it first), so it cannot refuse there. Documented. |
| `edit-hyprland`'s removed-lines file not bound to the install state | Added. |
| `..` gets around the HOME check; relative link targets resolve against the cwd | Fixed: paths must be absolute and normalised. |
| An edit writes through a hyprland.lua link | Fixed: edits resolve the full path (a link into the repo is refused). |
| Queue drop on polkit-monitor removal not in the spec | Added to 07 §5: the prompt moves to the active monitor, the queue stays; with no monitor left the request is cancelled and the queue dropped. |
| Non-string notch → TypeError, not an invariant | Fixed (`legalNotch` uses `isCard`, which checks the type). |
| A bad state wedges SurfaceManager | Rejected: `finish()` checks every result before SurfaceManager applies it, so a broken state is never stored; a throwing operation leaves the old state. |
| supervise comment says "never give up" | Fixed. |
| Only one valid baseline in the tests; reasons not pinned | 7 allowed states and 15 more forbidden ones in `tst_rules`; `test_check_action_refuses` pins each reason (18 cases, plus the `..`, prefix-sibling, relative and link cases). |

### Phase 7 · implementation (2026-11-07/08)

**How:** the phase-5 probe (branch `s1-probe`, kept as a reference, never merged) was squash-merged
onto phase 6, every conflict taken from the probe; then everything phase 5 and 6 decided that the
probe lacked was applied on top:
- JS libraries: probe bodies under phase 6's checks (`finish()` now runs `checkState` on every
  result); the decisions of the phase-6 review above; `colour.mix` kept (used by `over`/`toward`).
- Python: `check_action` runs over the whole plan before `apply()` does anything; the supervisor's
  delay follows the crash streak (crashes at 0, 6, 12 s wait 0.5, 1, 2 s; a run of ≥ 10 s starts a
  new streak), the slow retry still counts crashes in the window; `crashes.started` set per start.
- QML: `Hypr.fullscreenMonitors` is a list (bound directly, and also applied to a monitor that
  appears later); `Session.canLock` readonly; `available` flags on Focus, Dnd, Capture, Jot with Ipc
  answering "error: <x> is not available yet"; Theme's setters write Config (S1 part, logs a
  refusal); Glyph is an Item with two Texts and the swap crossfade (0.8 → 1, plain crossfade with
  reduced motion); `disabledReason` on Button and IconButton (faint, no wash, no click, tooltip says
  why); `Motion.catalogueMs(path, out)` used by Menu, MenuHost, Scrim, Ellipsis, Frame, MonitorShell;
  card heights from `surfaces.notch.cardHeights`/`resultCardHeight`; MonitorShell registers the
  Deck's and Overview's `back()`; Notch's back registration is `TODO(S3)`, Tokens' `shell.json`
  watch `TODO(S2)`.
- **New type phase 5 did not find:** `components/Choreographed.qml`, the base of NotchMode and
  Drawer for the content choreography of 04 §3 rule 1 (content from 60 ms over `fade`, rising
  8 px; on exit out first over 100 ms; a plain crossfade with reduced motion). One base instead of
  the same states/transitions in both.
- Tests and tooling: `tests/lint.sh` (qmllint over shell/ incl. the JS libraries, `--max-warnings
  0`; checked that a warning fails it); `tests/qml/mkmock.py` builds the import dir qmltestrunner
  needs (own minimal Quickshell doubles, qs.core doubles, the real components, Tokens/Motion without
  their Quickshell parts) and `tests/run` uses it; `tst_components` ported from the probe's smoke
  tests (14 functions plus Glyph swap, `disabledReason`, choreography); `test_binds_lua` runs
  `hypr/binds.lua` under luajit with a stub `hl` (every route bound, lock through exec with its
  fallback, hardware keys `locked`, each chord unbound once before its first bind, overrides
  apply); `nested.py stop` removes a killed nested session's runtime dir (never the real one).
- Repo: `README.md` rewritten for v2 (11 §4.5); `CLAUDE.md` status lines; `.gitignore`
  (`__pycache__/`, `.pytest_cache/`, v1's lint file dropped); tracked `.pyc` files removed; main's
  doc comments restored where the probe had dropped or weakened them.
- Spec, same commit: 07 §5 four rows (interactive mode vs Overview, lock, polkit monitor removed,
  monitor added during Capture); capture.md §7 (what closes before the freeze, `includeShell`,
  polkit, hot-plug).

**Checked:**
- `tests/run`: pytest 88 passed; qmltestrunner 131 passed (rules 41, components 19, the rest
  unchanged); lint 117 files, 0 warnings.
- `pytest tests/e2e` in a nested Hyprland: 9/9 (start, global shortcuts listed, state JSON, open +
  back, reserve zone, mask click-through, `configerrors` empty, no deprecated options, screenshot).
- By hand in a nested session: `shell state` lists the services; `theme mode light` switches the
  frame to Linen through Config (screenshot), back to dark; `focus stop` and `capture region`
  answer "error: … is not available yet"; `surface open deck` + `surface back` closes the Deck
  through the registered back step; no warnings in the shell log except the portal app-ID notice
  of the nested session.
- No `TODO(phase)` left; remaining TODOs name their stage.

**Open:** Deck, Overview, notch modes are their stages' stubs, so the choreography is covered by
tests, not seen on screen yet. The physical-key check of P-01 stays for Lenno's hands-on round.

### Review of phase 7 (fresh reviewer, diff `86ce7e5..18f9c29`; fixed in "phase 7: review fixes")

| Finding | Resolution |
|---|---|
| Locking throws: `onLockedChanged` snapshots `locked: true` before rules.js has seen the lock, so `checkState` refuses the closing menu/Capture | Fixed: SurfaceManager keeps `_lastLocked` (the lock state as rules.js last saw it) for the snapshot. `tst_surfacemanager` (new, 7 tests) fails without it. |
| A submenu fills the whole monitor (Loader with `anchors.fill` resizes it) and gets the parent's space wrong | Fixed: the submenu Loader is placed at 0,0 without anchors; `_space`/`_spaceV` are writable and passed through `setSource`. Test fails with the old code. |
| `install.sh` can stop halfway: a link fails on a file whose move was declined, a move onto an existing target fails after earlier steps ran | Fixed: `apply()` checks the whole plan first (every blocked link has an approved move, no move target exists), then runs in the order mkdir → move → link → edit (`ORDER`). `main()` leaves out a link whose blocking file stays, and skips the hyprland group when `~/.config/hypr/aptus` is not linked (`_aptus_linked`). Tests added. |
| A second polkit request opens on the focused monitor beside the first; a polkit monitor removed while locked keeps a queue nobody replays | Fixed in rules.js: a new request replaces the shown one where it is; with no monitor to move to (or locked) the request is cancelled and the queue dropped (as 07 §5 says). Tests added. |
| No Esc in the shell's own windows; shortcuts of unbuilt surfaces grab the keyboard with nothing on screen; Super+M does nothing | Fixed: MonitorShell's content item takes focus and routes Esc to `SurfaceManager.back()` (e2e `test_escape_closes_mode` types Escape into the nested session; fails without the handler). `Shortcuts.notBuilt` (one line per stage, each stage removes its own) makes those shortcuts log "not available yet"; IPC still opens them for tests. `Session.logout()` falls back to `hl.dsp.exit()`. |
| `restore` can run twice and put the removed lines back twice | Fixed: after a restore `removed.lua` is renamed `removed.lua.restored-<stamp>`. Test added. |
| The supervisor leaves the slow retry after one more crash outside the window and shows the crash notice again | Fixed: `CrashLog.slow_from` keeps the slow retry until a run of ≥ 10 s; the notice fires once per slow streak. Tests added. |
| `Config.reset()`/`resetPage()` skip the cross-key rules (a reset can leave `focus.default` outside the durations, dimAfter > lockAfter) | Fixed: both go through `_resetKeys`, which cross-checks the whole result and refuses like `set()`; they return "" or the message. `tst_configsingleton` (new) covers it and fails without the check. |
| No QML test covers SurfaceManager.qml, Config.qml or Tokens.qml | Added: the mock import dir now generates the real SurfaceManager and Config (a `Quickshell.Io` double: FileView reads through XHR, writes stay in memory; FileViewError) and the real Tokens; `tst_surfacemanager`, `tst_configsingleton`, `tst_tokens`. |
| e2e `configerrors` passes when hyprctl gives no JSON | Fixed: `None` fails. |
| IPC answers "ok" for things that did nothing (`notch toast` without Notifications, reboot/poweroff without logind, a refused theme value) | Fixed: `Notifications.available`, `Session.canPower`; Theme's setters return the refusal and Ipc answers "error: …". |
| `aptus doctor config` words problems differently from the shell and rejects `60.0` for whole numbers | Fixed: the shell's wording without the label; integral floats are whole numbers (JSON has one number type). `tests/fixtures/validate-cases.json` (33 cases) is checked against both `doctor/config.py` (pytest) and `config.js` (`tst_config`). |
| Tokens restarts the 400 ms crossfade on every appearance setting, even when the palette does not change | Fixed: an unchanged resolution starts no crossfade (`tst_tokens` fails without the guard). |
| `now` defaults handled per call site; `pinnedCardTimeout` missing from the limits | `nowOr` moved into `finish()` and `post()` (test added). `pinnedCardTimeout` is S3's (pinned cards are), marked `TODO(S3)`. |
| `WallpaperLayer` sets `sourceSize: undefined` | Rejected: `sourceSize` is resettable, `undefined` resets it; no warning in the shell log. |
| New APIs not reported | Reported here: `Ipc.notYet`; `SurfaceManager._syncFullscreen`, `_lastLocked`; `Shortcuts.notBuilt`, `_built`; `Session.canPower`, the logout fallback; `Notifications.available`; Theme setters → string; `Config.reset`/`resetPage` → string, `_resetKeys`; Menu `_space`/`_spaceV` writable; install `ORDER`, `_aptus_linked`; `CrashLog.slow_from`; `Nested.key`, `nested.py` as a script (`python3 tests/e2e/nested.py`: a nested session with the shell until Ctrl+C). |

**Checked:** `tests/run`: pytest 93 passed, qmltestrunner 154 passed (rules 44, components 19,
config 24, configsingleton 7, surfacemanager 7, tokens 5, the rest unchanged), lint 117 files,
0 warnings; `pytest tests/e2e`: 10/10. Each new test was run against the old code once and failed.

### Wave-1 review (`/code-review high`, diff `f579932..a1ffada`)

| Finding | Resolution |
|---|---|
| A second `install.sh` with new removals replaces `removed.lua`, so uninstall loses the first install's Noctalia lines | Fixed: the record grows (the old one is kept as `removed.lua.<stamp>`); a line removed again replaces its old entry, so it is put back once. `test_second_install_keeps_earlier_removals`; `test_uninstall_plan` caught the double-restore case on the way. |
| `wallpaper next` without an own image on the focused monitor wipes every monitor's own image (and is hidden behind `byMode`) | Fixed per wallpaper.md §6: `next` changes `all` only, monitors with their own image keep it (`byMode` still wins, as the resolution order says). e2e `test_wallpaper_next_keeps_monitor_images`. |
| A key used by two kinds (OSD "volume", toast "volume") throws in `finish()` | Fixed: `post()` coalesces per kind and key, so the invariant is per kind too. Test extended (failed before). |
| The hyprland.lua edit replaces a symlinked hyprland.lua with a copy | Fixed: read, back up and write the file the link leads to (the one `check_action` checked). `test_edit_follows_a_link`. Lenno's file is a plain file today. |
| `Config._save()` races `Paths.ensureDir` (fire-and-forget mkdir) | Rejected as a bug: Quickshell 0.3.2's FileView creates missing folders on write (tested: `setText` into `a/b/x.json` under a fresh folder saves). `ensureDir` was redundant and is removed (Config, Wallpaper, Paths, the mock). |
| `shell restart` quits even when the flag was not written; the supervisor then ends | Fixed: the flag is written through a FileView and the shell quits on `saved` only (a failure is logged, the shell keeps running). No `sh` any more. e2e `test_shell_restart`. |
| `_apply` reassigns `passive`, `passiveTop`, `deckPages` on every operation (the 500 ms tick) | Fixed: fields are compared by content two levels deep (payloads and menu callbacks by reference). `test_unchanged_fields_fire_nothing` (failed before). |
| `setActive` closes activity cards on the old monitor, but "passive content stays" | Rejected: cards show only on the active monitor (05 §7); "passive content" in 07 §5 is the toast/OSD/event queue. Made explicit in the 07 §5 row and the code comment; a test covers the card case. |
| Without `XDG_RUNTIME_DIR`, Paths.qml and paths.py disagree on the runtime folder | Fixed: paths.py falls back to `$HOME/.aptus-run` as Paths.qml does (QML cannot know the uid); Hyprland's sockets stay under `/run/user/<uid>`. `test_paths` updated. |
| M-28's wallpaper scale 1.02 is a literal | Fixed: `motion.catalogue.wallpaper.scaleFrom` (1 with reduced motion). |

**Checked:** `tests/run`: pytest 95, qmltestrunner 155, lint 117 files 0 warnings; `pytest
tests/e2e`: 12/12.

### Wave-1 simplify (`simplify` on the wave diff; four reviewers: reuse, quality, efficiency, altitude)

| Area | Change |
|---|---|
| Rules engine | `begin()` checks the state and fills the limits with their defaults once (16 `checkState` calls and `DRAWERS`/`OTHER` gone); `monitorOf` owns the polkit-monitor rule; `nextDeadline` gives the expiry of the oldest unshown event, so SurfaceManager arms one single-shot timer instead of a 500 ms tick. |
| SurfaceManager | Every operation goes through `_run(op, …)`; the global state is kept as `_g` (`_hasPassive`, `_lastActive`, `_lastLocked` gone); limits come straight from the tokens. |
| Motion, Tokens | Motion: `ms()`, `catalogueMs()`, `catalogueValue()`, `scaleFrom()` and `springs` instead of 20 copied properties; lookups before tokens.json has loaded give 0 silently (the shell log of a nested run had "unknown duration intro"). Tokens coalesces re-resolutions with `Qt.callLater`. |
| Components | `StandardAnimation`, `StandardColorAnimation`, `SnappySpring` replace 36 copies of the curve and spring settings. Choreographed carries the host contract NotchMode and Drawer shared (monitorName, args, takesKeyboard, keys, closeRequested, back). Glyph lays out its leaving text only during a swap. |
| Lazy drawers (04 §8) | `DrawerSlot` loads Deck and Overview from opening until their exit has finished (`Drawer.busy`, default `Choreographed.leaving`) and forwards bulge and `back()`, so S5/S7 never edit MonitorShell. MenuHost was lazy already; CaptureOverlay's stub tells S9 to load its content the same way. `test_drawer_slot` (fails without the hold). |
| Shell start | The locked-marker and intro-flag checks are two FileViews instead of two `sh` Processes. |
| Config, Paths, Ipc, registry | Config: one `_commit` path for set/reset/resetPage, reload only when the file differs from what it wrote. Paths.qml uses config.js `expand`/`insideHome`. Ipc: `guarded()` for the not-yet-built services, theme modes and the time pattern from the schema/config.js. Activities/NotchModes read the ids from rules.js. Shortcuts: `names` from the route table. |
| aptus msg | Calls first and runs `qs ipc show` only on a usage error (one process per call instead of two); "Too many arguments" is a usage error. |
| install, doctor | install: `_bin_links`, `_links_into_repo`, `_blocked`, `hyprlua.read_removed`, `hyprlua._lines`; `install/__main__.py` removed (install.sh imports `main`). doctor: `cross_check` mirrors config.js `crossCheck` (same relation indexing, same words); `crossCases` in `validate-cases.json` are checked by both suites. Forbidden packages: one `rpm -q` call. |
| supervise, hypr, session | `next_delay` returns `(delay, switched)` (`crashed_out` and `slow_from` gone, `CrashLog.slow`); `hypr._expect_ok`; `Paths.make_runtime()`; session uses `hypr.ENV_SIG` and `paths.test`. |
| binds.lua | The overview gestures use `G()`; the binds test runs gesture actions instead of grepping the source. |
| Tests | Shared fixtures `fake_hypr`, `stub_bin`, `FakeQs`; e2e uses `Nested.paths` and the route table. The mock builds Tokens, Motion, Config and SurfaceManager in one loop; dead mock files gone. |

Skipped, with the reason:

| Finding | Why |
|---|---|
| Animate the wallpaper colour change | It happens on a wallpaper change only; the crossfade covers it. |
| imgA/imgB of WallpaperLayer as an inline component | Inline components cannot reach the outer ids under `ComponentBehavior: Bound`; the copy is two short blocks. |
| Label composition helper, env export helper | One caller each. |
| Move `Shortcuts.notBuilt` elsewhere | Any other home would be shared by more files; it belongs to the routes. |
| A global revision counter | S10's (settings UI) concern. |
| Literal fallbacks in Tokens/Motion | Placeholders before tokens.json has loaded; MonitorShells appear only after it has (07 §3 step 2), so nothing draws with them. |

Handed to S3 (in its brief): Hypr's refetch on title events and the eager `windows` list (E1), the
Frame shadow blurring the whole monitor instead of the bulge bounding box (E4), Bulge normalising
twice (E12).

**New APIs:** `DrawerSlot`, `Drawer.busy`, `Choreographed.leaving` and the contract members it now
holds; `StandardAnimation`, `StandardColorAnimation`, `SnappySpring`; `Motion.catalogueValue`,
`scaleFrom`, `springs`; `Rules.nextDeadline`, `withDefaults`; `Paths.make_runtime`;
`hyprlua.read_removed`; `doctor.config.cross_check`; `supervise.next_delay` → `(delay, switched)`.

**Checked:** `tests/run`: pytest 97, qmltestrunner 159, lint 121 files 0 warnings; `pytest
tests/e2e`: 12/12. A nested run (shell start, overview open and Esc, theme toggle): screenshots
right, shell log without warnings (only the portal's app-id note of the nested session).

---

## S2 · Isolation

### Phase 1 · plan (2026-11-09)

**Goal** (11 §2 row S2, brief `.claude/briefs/s2.md`). `aptus-lease` (take | update | release |
recover | status), `aptus-guard`, `aptus-recover.service`, the renderer with every target of 02 §4
and its reload hook (`aptus-theme render | apply | targets`, `theme/targets.toml`,
`theme/templates/<target>/…`), `aptus doctor isolation` (all eight checks of 02 §10), the `Lease`
service (read-only) and `Theme`'s render requests, `aptus-session start` with recover → render →
preflight → take → env import → guard, install/uninstall of the recovery unit and the check-8
baseline. Probes P-04 (steps for Lenno), P-05, P-06, P-07 (nested). D-03 untracking: list and
commands for the main session only.

**Facts found while reading** (read-only; `~/.config/umbriel` and `~/.local/state/noctalia` never
opened):
- Noctalia is 5.4.1 (native). Its built-in templates are listed in
  `/usr/share/noctalia/assets/templates/builtin.toml` (`gtk3`, `gtk4`, `kcolorscheme`, `qt`,
  `kitty`, `ghostty`, `foot`, `alacritty`, `btop`, `cava`, `hyprland`, compositors, `umbriel`, …);
  community templates come from the `noctalia-dev/community-templates` catalogue (`zen-browser`,
  `pywalfox`, `thunderbird`, `discord`, `claude-code`, `antigravity`, `vscode`, `steam`, `brave`,
  `hyprtoolkit`, `papirus-icons`, `spicetify`, `libreoffice`, `fuzzel`, `thunar`, `tmux`,
  `starship`, `fastfetch`, `neovim`, `lazyvim`, `yazi`, `bat`, …). Noctalia's docs: the enabled ids
  are `[theme.templates] builtin_ids` / `community_ids` (with `enable_builtin_templates`,
  `enable_community_templates`) and `[theme.templates.user.<id>]`, read from
  `~/.config/noctalia/*.toml` with `~/.local/state/noctalia/settings.toml` as the final overlay.
  `~/.config/noctalia` is empty here, so the coverage check (runtime code, read-only) reads the
  file 02 §4 names; tests use fixtures.
- The `thunar` community template writes a GTK 3 extension with literal colours
  (`gtk-3.0/noctalia-extensions/thunar.thunar.css`), imported from Noctalia's `noctalia.css`: not
  in 02 §4; it becomes target `thunar` (lease, only if present) so Thunar does not keep Noctalia's
  colours.
- LibreOffice's artifact is `~/.local/state/noctalia/libreoffice-theme-staging/Theme_Colors.xcu`,
  inside Noctalia's state, which I-1 forbids: the `libreoffice` bake cannot exist; it stays
  Noctalia's whatever `isolation.bakeTargets` says (doctor and the targets list say why).
- `hyprland.lock` in `$XDG_RUNTIME_DIR/hypr/<sig>/` holds Hyprland's pid; `XDG_SESSION_ID` is
  inherited by `aptus-session`; a session left on another VT is logind state `online`, not
  `active`.
- Leased files reached through a stow link into `~/dotfiles`: `hypr/hyprtoolkit.conf` (tracked),
  `nvim/lua/matugen.lua` (tracked), `nvim/colors/noctalia.lua`, `btop/themes/noctalia.theme`
  (untracked). The kitty theme (scoped, tracked) and fastfetch's stale copy are tracked too.

**Decisions where the spec is silent** (each written into the spec in the phase that builds it):
1. **Test safety.** Under `APTUS_TEST=1` every tool with an effect outside the process (`dconf`,
   `systemctl`, `systemd-run`, `loginctl`, `dbus-send`, `tmux`, `nvim`, `pywalfox`, `spicetify`,
   `bat`) is looked up only in `$HOME/.aptus-test/bin` (fakes that record their calls); without a
   fake the step is skipped and logged. `aptus-lease`, `aptus-guard` and `aptus-theme` refuse to
   run when `APTUS_TEST=1` and HOME is not a directory below the system temp dir (or is the
   passwd home): `paths.require_safe_home`. Signals go only to processes whose environment carries
   this session's signature (and, under test, this HOME).
2. **Preflight** (02 §5.3): "another active graphical session" = a logind session of this user
   with class `user`, type `wayland`/`x11`/`mir`, state `active` or `online`, id ≠ this session's
   `XDG_SESSION_ID`. A `noctalia` process of this user (02 §8) also means scope-only.
3. **Environment import only while the lease is held**: in scope-only mode another session may be
   using the user manager, so nothing is imported (02 §6).
4. **Journal.** Step 5 records each slot's `before` and its *planned* `after` (status `pending`);
   step 7 marks them `held`. An update records the old hash as `after_prev` before writing. So a
   crash at any point leaves enough to recognise aptus's own paint. Release per slot: equal to
   `before` → nothing to write; else (own paint or a conflict, saved under `conflicts/`) restore
   `before` and verify; a failed slot keeps the journal in `releasing`.
5. **ini-sections** (kdeglobals): blocks = preamble + `[header]` sections (verbatim text); a
   section matches the globs by its header name (`Colors:Header][Inactive` matches `Colors:*`);
   `before` stores each matching section with the name of the non-matching block before it
   (anchor). Write and restore remove the matching sections and insert the new ones after their
   anchors (unknown anchor: end of file); everything else stays byte-identical, also a missing
   final newline.
6. **dconf**: the fixed key set of 02 §5.5; `gtk-theme` is recorded, never written.
7. **Template language** (08 §4) with the roles of `resolve` (+ `ansi0`…`ansi15`, `mode`,
   `accent.name`, `papirus.folder`, `gnome.accent`, `font.*`, `cursor.*`). aptus's templates keep
   the structure of Noctalia's (same variable names, includes, sections), so the wiring keeps
   working; colours come from a fixed Noctalia-role → aptus-role table (written into 08 §4).
8. **Generations**: `gen-<n>/` holds every output, `resolved.json` and `inputs.json` (the
   wallpaper inputs the shell passed, reused by the session-start render). The shell watches
   `current/resolved.json` (07 §7 said `shell.json`; one file, renamed in the spec).
9. **Coverage**: enabled ids (built-in, community, `user:<id>`) against the targets' `noctalia`
   lists; ids whose output only another compositor reads (`umbriel`, `niri`, `sway`, `labwc`,
   `mango`, `scroll`) are inert in Hyprland (an `[inert]` table in `targets.toml`); a user template
   is also covered when its output path is a target's slot.
10. **Golden files**: full outputs for Ember/jade and Linen/jade, plus a hash manifest of every
    target for 2 palettes × 6 accents (07 §13).
11. **Doctor rules** made exact: check 2 accepts a slot changed after the release time (Noctalia
    wrote it in Umbriel) and fails a restored slot that differs without being touched since; a
    changed dconf value is a warning. Check 7 compares `~/.local/share/fonts` with the install
    baseline and fails on any of aptus's own font files. Check 8: a changed file whose mtime lies
    inside a recorded lease period fails; outside every lease period it is Lenno's change in
    Umbriel.
12. **Recovery unit**: `DefaultDependencies=no`, `Before=default.target`, plus
    `After=dbus.socket` (dconf writes need the bus), `ExecStart=%h/.local/bin/aptus-lease recover`,
    installed as a link into the repo and enabled with `systemctl --user enable`.
13. **Guard**: `aptus-guard <hyprland-pid> <signature>`; pidfd + SIGTERM through a self-pipe;
    releases only a lease owned by that pid and signature; a 30 s tick retries queued bakes
    (spicetify, only when opted in); writes `guard.state` (`ok`, `scope-only`, `failed`).
    `aptus-session stop` (logout path) stops the guard unit, which releases.
14. **Lease service**: journal, `guard.state` and `session.json` read-only; `notice` (the notch's
    one-time message: "Another session is open — some apps keep Noctalia's colours.", "Noctalia
    is running — some apps keep Noctalia's colours.", "Some apps could not be themed — they keep
    Noctalia's colours."), `warning` for the bar, `statusLine` for settings (settings.md §7).
15. **Theme service**: after a resolution change (mode, accent, glass, contrast, ground alpha) and
    `frame.edge`/`motion.reduce`, debounced 250 ms after the crossfade, runs `aptus-theme apply
    --inputs <json>` with the resolved mode and the wallpaper inputs; exposes `lastApply`,
    `failed`.

**Files** (new unless noted):

| Area | Files |
|---|---|
| launchers | `bin/aptus-lease`, `bin/aptus-guard`, `bin/aptus-theme`; `bin/aptus` unchanged (dispatch is in `cli.py`) |
| lease | `lib/aptus/lease/{__init__,journal,slots,recover,preflight,system,guard,cli}.py`, `lib/aptus/lease/kinds/{__init__,file,ini,dconf}.py` |
| theme | `lib/aptus/theme/{__init__,palette,resolve,sun,inputs,targets,noctalia,render,scope,own,hooks,apply,cli}.py` |
| doctor | `lib/aptus/doctor/isolation.py`; `doctor/__init__.py` (wiring) |
| changed | `paths.py` (new paths, `require_safe_home`), `session.py` (start/stop), `cli.py` (`theme`, `lease`), `install/__init__.py` (leased slots in `check_action`, unit link + enable, baseline, uninstall of 02 §11) |
| data | `theme/targets.toml`, `theme/templates/<target>/…` (36 rows + thunar), `systemd/aptus-recover.service` |
| shell | `shell/services/Lease.qml`, `shell/services/lease.js`, `shell/services/Theme.qml`, `shell/core/Tokens.qml` (the TODO(S2) spot only) |
| tests | `tests/unit/test_{lease_kinds,lease_journal,lease,exit_matrix,guard,preflight,theme_resolve,theme_render,theme_apply,hooks,coverage,doctor_isolation,session_s2,install_s2}.py`, `tests/unit/slotfix.py` (fixtures from the real slot files), `tests/golden/`, `tests/qml/tst_lease.qml`, `tests/e2e/test_s2.py` |
| spec | 02 (§4 thunar and libreoffice rows, §5.3, §5.5, §6, §7 unit, §10 rules), 07 (§7, §13), 08 (§4, §5 manifest schema, §7), probes.md (P-04…P-07) |

**Risks.** (a) A template that changes the wiring's variable names would break an app in Hyprland:
templates are derived from Noctalia's own and checked in the nested session (GTK 3, kitty,
Ghostty). (b) FileView may not notice a swapped `current` symlink: probed in phase 5; fallback:
watch a stable file written by rename. (c) Python and JS colour maths must be byte-identical: a
test resolves every combination in both. (d) Exact restore of kdeglobals: tests over the real
file. (e) The guard must outlive Hyprland and never act on a foreign lease: tested with a real
child process named `Hyprland` and a real pidfd. (f) Time: 37 targets; the template translation is
mechanical and may go to a helper (sonnet, lower).

**Checks (end of S2).** `tests/run` green; exit-matrix tests (logout, SIGKILL, power-off, crash
mid-take, crash mid-release, user manager stop) end with every slot hash equal to the baseline;
scope-only with a fake Umbriel session; the refusal on a real HOME; each doctor check passes and
fails once; golden files; nested: `aptus-session start` takes the lease in the temporary HOME,
kitty/Ghostty/a GTK 3 app show aptus paint, `hyprctl configerrors` empty, killing the nested
Hyprland restores every slot.

### Phase 2 · structures (2026-11-09)

**Done.** Data structures only, no behaviour:
- `lease/journal.py` (`State`, `SlotStatus`, `Owner`, `SlotRecord`, `Journal`: 02 §5.2),
  `lease/slots.py` (`SlotSpec`: what the renderer hands the lease), `lease/ops.py` (the reports of
  take, update, release, status; added to the plan so the CLI and the session share them),
  `lease/kinds/` (`Snapshot`; ini `Block`/`Section`), `lease/system.py` (`ToolResult`, `Proc`),
  `lease/preflight.py` (`LoginSession`, `Preflight`), `lease/guard.py` (`GuardState`).
- `theme/inputs.py` (`Inputs`), `theme/targets.py` (`Mechanism`, `FileOut`, `ScopeSpec`, `Target`,
  `Manifest`, `Coverage`), `theme/noctalia.py` (`Enabled`), `theme/render.py` (`TemplateError`,
  `Generation`), `theme/hooks.py` (`Hook`, `HookResult`), `theme/apply.py` (`Report`).
- `doctor/isolation.py` (`Baseline`), `session.py` (`StartReport.notice`, `.generation`, `.guard`).
- `paths.py`: 23 new paths (templates, manifest, recovery unit, scope dirs, icons/fonts/themes,
  qt6ct, baseline, doctor stamp, bake queue, the test tool dir, the read-only Noctalia/Umbriel/
  greetd paths, tmux sockets) filled in `resolve()` (constructor arguments only, so every caller
  keeps working), `UnsafeHome`.
- `theme/targets.toml`: the full manifest, 36 entries (rows 1–37 of 02 §4 without Umbriel's
  row 32) plus the `[inert]` table; `systemd/aptus-recover.service`.
- `Lease.qml`: `state`, `journal`, `guard`, `mode`, `reasons`, `failedSlots`, `notice`, `warning`,
  `statusLine`. `Theme.qml`: `failed`, `generation`, `_pendingInputs`.

**Checked.** Every module imports; the manifest parses (36 targets, rows 1–37 except 32); paths
resolve in a test HOME (greetd and tmux paths inside it); `tests/run` green (97 unit, 159 QML),
qmllint 0 warnings.

### Review of phase 2 (fresh subagent, phase-2 diff only)

14 findings and 3 test-safety notes. The fixes went into the phase-3 commit, because phase 3 had
started on the same files.

**Fixed.**
1. Noctalia's post-hooks copy the paint elsewhere for fastfetch (merged into `config.jsonc`),
   Antigravity/Gemini (merged into `config.json`) and Brave (installed into
   `~/.local/share/noctalia` and Brave's preferences). The leased theme file alone paints
   nothing, and Brave's real target is Noctalia's own data. Checked against the fetched
   templates. On this machine `config.jsonc` has comments, so Noctalia's own merge fails, and it
   does not include the theme. All three are now `never` with a note. 02 §4 is updated in
   phase 7.
2. Vesktop: all six Noctalia outputs (midnight, material, system24; native and Flatpak).
3. Yazi: Noctalia writes `flavors/noctalia.yazi/{flavor.toml,tmtheme.xml}`, wired by `[flavor]`
   in `theme.toml`. The scope mirror now replaces the two flavor files and adds a `theme.toml`
   only when there is none (`missing_only`). `ScopeSpec.replace` is gone; each `FileOut` has an
   `at` path inside the mirror.
4. `FileOut.name` gives the slot id `<target>.<name>` (default `artifact`). A `*` slot appends
   `.<sha256(path)[:8]>`, so ids stay stable and safe as file names.
5. `SlotSpec.create`. A missing artifact is created only when its directory exists, so release
   deletes exactly what aptus created and never a directory. With `present`, a missing artifact
   is skipped.
6. `Target.requires` (dconf key → target): `icon-theme` is only recorded when `icons` was not
   applied, so GTK never falls back to hicolor.
7. `SlotRecord.reload`: release and recover do not depend on a manifest changed since the take.
8. `before` records `link` (readlink) for file and ini slots, and `mode` for ini.
9. Own destinations use `{config}`/`{state}`/`{cache}`/`{data}` placeholders (XDG bases, the same
   as `paths.py`). The unit uses `ConditionPathExists=%S/aptus/lease/journal.json`.
10. Partly: a `SlotKind` enum; `Status.state: State | None`, `Status.owner: Owner | None`;
    `Manifest` is not frozen.
12. `Coverage.kept` for Noctalia ids that a `never` target keeps on purpose.
13. The doctor stamp moved to `state/doctor-check` (not `lease/`), documented as the doctor's
    only write.
14. `recover_unit` and `scope_*` are derived from `systemd_user` and `scope`.
- Test safety: a `nvim_sockets` path (`runtime_home`, inside HOME in tests); the bat note says
  `--target` is `cache_bat` and never bat's shared cache. The Own-destination allowlist is a
  phase-6 invariant.

**Rejected.**
- 10, the rest. `apply.Report.mode` stays a string: `session` imports the theme package, so
  sharing `session.Mode` would be circular. Hook kinds and result states stay strings checked
  against a constant tuple, as `install.KINDS` does. Each layer encodes "record only" in its own
  way: TOML has no null (`""`), the spec has `value=None`, the journal has `write=False`. Each is
  the natural form for its layer. The `-1` sentinels stay, to match `resolve.js` (parity).
- 11. The spec updates (02 §4/§5.2, 07 §7, 08 §5) come with phase 7, when the structures are
  final, in one consistent edit. They are listed in the phase-1 plan.

### Phase 3 · signatures (2026-11-09)

**Done.** Signatures, docstrings and constants. Every body is `raise NotImplementedError`, or an
empty QML body marked "phase 7":
- lease: `system` (`TOOLS`, `tool`, `run`, `boot_id`, `comm`, `environ`, `processes`,
  `session_processes`, `signal_session`).
- lease kinds: one interface for all three kinds (`read`, `digest`, `before_digest`, `planned`,
  `write`, `restore`, `current`) plus `module` and `sha256`. ini adds `split`, `matches`,
  `extract`, `splice`, `sections_sha256`. dconf adds `KEYS`, `RECORD_ONLY`, `check_key`,
  `read_key`, `write_key`, `reset_key`.
- lease journal and ops: journal `load`/`save`/`archive`/`last_released`/`to_dict`/`from_dict`;
  ops `lock` (re-entrant within one process), `owner`, `take`, `update`, `release`, `status`,
  `held_by`, `save_conflict`.
- lease preflight, recover, guard and CLI:
  - preflight: `sessions`, `others`, `noctalia`, `check`, and the three notice texts.
  - recover: `socket_accepts`, `owner_alive`, `recover`.
  - guard: `write_state`, `pidfd`, `wait`, `release_if_ours`, `unset_environment`, `run`,
    `main`, `UNSET`.
  - `lease/cli.py`.
- theme: `palette` (port of colour.js), `resolve` (`ROLES`, `resolve`, `accent_for`,
  `ground_alpha`), `sun`, `inputs` (`setting`, `from_settings`, `from_json`, `to_dict`), and
  `targets` (`load`, `parse_target`, `expand`, `active`, `slots`, `coverage`).
- theme, continued: `noctalia` (`sources`, `merge`, `enabled`), `render` (`FILTERS`,
  `PLACEHOLDER`, `context`, `apply_filter`, `render_text`, `input_hash`, `current`, `render`,
  `prune`), `scope` (`mirror`, `marked`, `swap`), `own` (`write_files`, `icons`, `bat`, `record`)
  and `hooks` (`parse`, `run_all`, the four builtins, `bake`, `retry_queued`).
- theme apply and CLI: `apply` (`slot_specs`, `lease_mode`, `apply`, `report_json`) and
  `theme/cli.py`.
- elsewhere:
  - `paths.require_safe_home`.
  - `session`: `IMPORT_VARS`, `recover_step`, `render_step`, `lease_step`, `theme_step`,
    `import_environment`, `start_guard`, `stop_guard`.
  - `install`: `leased_paths`, `systemctl_user`, `WANTS_LINK`.
  - `doctor/isolation`: the eight `check_*`, `lease_periods`, `fingerprint`, `watched_files`,
    and the baseline functions.
  - Launchers `bin/aptus-{lease,guard,theme}`.
  - `shell/services/lease.js` (`parseGuard`, `failedSlots`, `summarize`); `Lease.refresh()`;
    `Theme.requestApply()`, `_inputs()`, `_applied()`.
- Not done: test skeletons. The tests are written with the implementation in phase 7. Extending
  `install.KINDS` waits for phase 7 too: an S1 test pins the tuple, and a kind without handling
  would pass `check_action`.

**Checked.** Every module of `lib/aptus` imports. `tests/run` is green (97 unit tests, the QML
tests) and qmllint reports 0 warnings.

### Review of phase 3 (fresh subagent, phase-3 diff only)

13 findings; the first reviewer died on the usage limit and was started again on the same diff.
The fixes went into the phase-4 commit (signatures and docstrings changed, bodies still
placeholders).

**Fixed.**
1. Import cycle ops ↔ recover. `recover()` moved into `ops`; `lease/recover.py` became
   `lease/liveness.py` with only `socket_accepts` and `owner_alive` (no import of ops).
2. Reloads without the manifest. `ReleaseReport.reloads` (target id → reload string) and
   `hooks.run_reloads(paths, reloads, signature)`; `run_all` delegates to it. The guard, recover
   and release reload from the journal's `SlotRecord.reload` alone.
3. Install interface for 02 §11. The four kinds are named now with their one path each:
   `enable-unit`, `disable-unit`, `baseline` (only when no baseline exists: a re-install never
   re-records, that would hide an aptus write), `release-lease`, and the order. The tuple itself
   grows in phase 7 with its handling, because an S1 test pins it and a kind without handling
   would pass `check_action`.
4. `scope/kitty` and `scope/yazi` as real directories. `install.plan` drops them (TODO);
   `scope.swap` documents the contract for directory and file targets (`starship.toml`) and
   moves an old real file aside.
5. Inputs of `slot_specs`. `Generation.inputs`; render writes the dconf values into
   `<gen>/<id>/dconf.json`; the bake opt-in comes from `inputs.bake_targets`.
6. `theme_step` duplicated apply. `apply.apply_generation(paths, manifest, gen, signature)` is
   shared by the session (after take) and `apply`; `lease_mode` is gone (`ops.held_by`).
7. Take after an incomplete recover. `take` raises `LeaseError` when a journal is still there
   after recover (live owner, failed slots, unparseable), so Noctalia's only `before` record is
   never overwritten; a leftover `released` journal is archived; `recover` lets `JournalError`
   through and `aptus-lease recover` exits 1 for it; a lock timeout raises `LeaseError`.
8. Locking. A theme lock of its own (`state/theme/lock`, `render.lock`) covers render, scope and
   Own; the lease flock is taken only inside ops, so `bat cache --build` never delays a release.
9. Guard. `release_if_ours` accepts every non-`released` state of the same owner;
   `unset_environment` runs only after our own release and unsets only variables that still hold
   aptus's value; `HYPRCURSOR_SIZE` is in `UNSET`.
10. The file kind never creates directories: a missing parent skips the slot.
11. Smaller items: one wording for who writes slots (the lease package, in-process; `aptus-lease`
    is its CLI); `render_step` falls back to `render.current`; `state/doctor-check`; "seven
    functions"; `read` records `link` and `mode`; `ini.planned` equals `digest` after a write;
    the vscode files have distinct `out`s (`vscode/code.json`, `codium.json`,
    `antigravity.json`); guard imports at the top.
12. Safety:
    - Preflight runs inside `ops.take` under the flock, so a manual `aptus-lease take` with
      Umbriel open takes nothing.
    - `targets.expand` raises `ManifestError` for a slot, dest or `at` outside HOME or inside
      Umbriel's config, Noctalia's state or `/etc`.
    - The kinds check `invariants.writable` on the resolved write path (phase 6).
    - `require_safe_home` compares realpaths.
13. One enforcement point each:
    - `require_safe_home` runs in `ops.lock` and `render.lock`, which every in-process caller
      (guard, theme, session) passes.
    - `own.write_files` refuses an existing dest that is not in own.json.
    - The guard starts before take: no guard, no lease.
    - `paths.sysroot` (`/`, or `$HOME/.aptus-test/root` under test) for `exists:` rules,
      Papirus and the system theme dirs.
    - The spec gap (Umbriel logging in on another VT mid-session) is closed by the guard: it
      polls `/run/systemd/users/<uid>` (`paths.logind_user`) once a second, releases at once when
      another graphical session appears and writes `scope-only` into guard.state; the shell's
      Lease service shows the notice. A window of about one second remains (open item).

**Deferred.** The spec updates (02 §4/§5/§7/§11, 07 §3/§7, 08 §5/§6) are made in phase 7 with the
implementation, as planned.

### Phase 4 · TODO markers (2026-11-09)

**Done.** A `# TODO(S2): …` line (or block) in every placeholder, naming the steps, the order and
the error cases:
- lease: `system`, `journal`, the three kinds, `ops`, `liveness`, `preflight`, `guard`, `cli`.
- theme: `palette` (port of colour.js), `resolve`, `sun`, `inputs`, `targets`, `noctalia`,
  `render`, `scope`, `own`, `hooks`, `apply`, `cli`.
- `doctor/isolation.py` (the eight checks and the baseline), `session.py` (the new start order:
  recover, render, guard, take, apply, import; `write_status`, `stop`), `paths.require_safe_home`.
- Integration spots: `install` (`KINDS`, `check_action`, `plan`, `plan_uninstall`, `apply`,
  `leased_paths`, `systemctl_user`), `cli.py` (theme/lease dispatch), `doctor/__init__`
  (isolation group), `Tokens.qml` (the `TODO(S2)` watch, now on `state/theme/resolved.json`),
  `Lease.qml`, `Theme.qml`, `lease.js`.
- Template fix: two fold markers removed from `templates/yazi/flavor.toml` (they would render as
  stray `{{`).

**Checked.** A script walks every function of `lib/aptus`: each one that raises
`NotImplementedError` carries a `TODO(S2)` (192 markers, 174 placeholders). Every module imports.
`tests/run` green (97 unit, 159 QML), qmllint 0 warnings.

### Phase 5 · probe (2026-11-09, thrown away)

**Done.** The risky parts were tried with throwaway code: drafts of the pure cores (palette,
resolve, sun, render, ini, journal, ops, release, guard, invariants) and probe scripts, all kept
outside the repo as the reference for phase 7. Every app probe ran in a nested Hyprland with a
temporary HOME. The probe results are in design/probes.md.

**Checked.**
- Parity: the drafted `palette`, `resolve` and `sun` against `colour.js`, `resolve.js` and
  `sun.js`, the JS run under node with the QML pragmas stripped.
  - resolve: 7,808 input combinations (mode × accent incl. wallpaper × contrast × glass ×
    wallpaper hue, chroma and lightness × current accent), **0 differences**.
  - sun: 138 cases (4 locations and none, 24 days, and the DST days at 00:30, 02:30 and 23:59),
    **0 differences**.
- Templates: all 36 rendered with the drafted render core for dark and light × the six accents
  (432 renders). No placeholder error. Every JSON and TOML output parses, and every Lua output
  compiles (`luajit -b`).
- ini-sections: a read-only copy of the real `kdeglobals` and 3,000 random files, checking
  identity, take→restore round trip, planned = digest, and foreign edits surviving a restore.
  The real file passed. The random files found two design faults (fixed in the draft, now
  2,993/3,000; the 7 left are a probe artefact, `[General]` at EOF without a newline):
  1. `planned != digest`: splice places sections by their anchors, so the file order can differ
     from the rendered order, and a section that lacked a final newline gets one. **Phase 7:**
     `sections_sha256` hashes the sections sorted by name, each ending in one newline.
  2. Round trip: a file without a final newline gets one when a section is appended after its
     last block, and restore cannot tell. **Phase 7:** `before` records `eof_newline`; restore
     drops the added newline when the file again ends in a non-leased block.
- dconf: every key of the target exists in the installed `org.gnome.desktop.interface` schema.
  Every `gnome` accent is in the `accent-color` enum. Every `papirus` folder colour has
  `folder-<colour>.svg` in Papirus.
- logind: `/run/systemd/users/1000` (`SESSIONS=3 2`) was last replaced at login. logind rewrites
  it by rename. **Phase 7:** the guard compares `(st_ino, st_mtime_ns)`, not the mtime alone, and
  on a change asks `loginctl` (preflight.sessions).
- P-04 (read-only pre-check): the user manager reports ready at basic.target, not at
  default.target. The recovery unit therefore races the session start, and it cannot move before
  basic.target (the dconf restore would deadlock). The designed fallback applies: 02 §7, the exit
  matrix row and the unit comment are updated, and Lenno's steps are in probes.md.
- P-05 (no: new windows only, fallback), P-06 (pass), P-07 (pass), FileView (a swapped symlink is
  not seen; Tokens watches `state/theme/resolved.json`). 02 §4 row 1 and the 08 reload table now
  carry the P-05 result.
- Not probed: yazi with `YAZI_CONFIG_HOME` and a mirror. A miss only means yazi keeps Noctalia's
  flavor inside aptus, which is no leak; e2e checks the mirror layout.

**Shapes phase 7:**
- `render` rounds HSL with `floor(x + 0.5)` (the draft used Python's banker's `round`).
- The two ini fixes and the guard's inode check above.

### Phase 6 · invariants (2026-11-09)

**Done.** Checks only. The placeholders keep their bodies after the checks, and no TODO was
removed.
- New `lease/invariants.py`. Each check raises `InvariantError("isolation invariant: …")`:
  - `transition(old, new)`: the journal state machine of 02 §5.3–§5.7 (`TRANSITIONS`).
  - `never_paths()`: Umbriel's config, Noctalia's state and config, the repo, the fonts dir, XDG
    autostart, user GTK themes, and `/etc` (also below `sysroot`).
  - `writable(paths, target, kind=lease|scope|own|state)`. The realpath, with every link
    followed, must be below HOME and outside every never-path. Then by kind:
    - lease: not inside aptus's own dirs;
    - scope: below `scope/`;
    - own: aptus's state or cache, the two qt6ct files, or `aptus-icons-{dark,light}`;
    - state: aptus's state, cache or runtime.
  - `check_spec`/`check_specs`:
    - the id is `<target>.<name>` and unique;
    - the fields fit the kind;
    - dconf keys come from the fixed set, and `gtk-theme` is never given a value;
    - the slot is writable.
  - `check_journal`:
    - version 1;
    - an owner unless released, and `released_at` exactly when released;
    - unique ids, and slot statuses that fit the state;
    - no record-only file or ini slot;
    - dconf keys from the set, and a written `gtk-theme` refused;
    - every file or ini slot writable.
  - `check_scope_name`: one plain path component.
  - `check_unset`: the guard unsets only aptus's variables.
- Implemented now, because they are themselves checks:
  - `dconf.check_key`.
  - `paths.require_safe_home`. Under `APTUS_TEST=1` HOME must be an existing directory whose
    realpath lies below the realpath of the temporary directory. It must not be, hold or lie
    inside the passwd home. The last rule keeps `TMPDIR=$HOME` from making the real home
    "temporary".
- Calls at the top of the placeholders:
  - `file`/`ini` `write` and `restore` → `writable(lease)`;
  - `journal.save` → `check_journal`;
  - `ops.lock` and `render.lock` → `require_safe_home`;
  - `ops.take`/`update` → `check_specs`;
  - `render.render` → `writable(state)`;
  - `scope.swap` → `check_scope_name` and `writable(scope)`;
  - `own.icons` → `writable(own)`;
  - `system.signal_session` and `hooks.builtin_hyprland` → `hypr.check_allowed`.
  - The guard's unset and ops' state changes name `check_unset` and `transition` in their TODOs
    (the values exist only once the body runs).
- Tests: `tests/unit/test_s2_invariants.py`, 80 cases, each check with passing and failing
  inputs. They include:
  - a symlink out of the temporary HOME, and one into Umbriel's config;
  - a stow-style directory link inside HOME, which is allowed;
  - the real home, a `/tmp` link to it, a missing dir, `/usr`, and `TMPDIR` inside the real home;
  - `ops.lock` and `render.lock` refusing the real home before they touch a file.

  An autouse fixture blocks `dconf`, `gsettings`, `loginctl`, `kitty`, `ghostty`, `tmux`, `nvim`
  and `bat` on `PATH`, on top of conftest's net.

**Checked.**
- Read-only: every non-glob slot of the manifest, resolved against the real HOME with realpath
  only (nothing opened), passes `writable(lease)`. That is 28 slots, 0 refused. Four resolve
  through stow links into `~/dotfiles` (btop, hyprtoolkit, nvim colors, matugen), which is
  inside HOME, so D-03 matters for them. The Steam slot resolves into `~/.local/share/Steam`.
- `tests/run` green: 177 unit (97 + 80), 159 QML. qmllint 0 warnings. Every module imports, and
  every placeholder still has its TODO.


### Review of phase 4 (fresh subagent, diff `2897e39..53a6125`; fixed in phase 7)

18 findings; the first reviewer died on the usage limit and was started again. Every placeholder
had its TODO and no behaviour had slipped in. The fixes are part of the phase-7 implementation.

**Fixed.**
1. Scope rebuild of the same generation deleted the live mirror: builds go to a unique
   `.<into>.<n>.<pid>` name, `swap` removes the old target only when it differs from the new one
   and is a build, and a real file or directory at `scope/<into>` is moved aside first.
2. `JournalError` and errors before `taking` escaped `take` and `start`: take converts them into
   `LeaseError`/`TakeReport.error`, `lease_step` catches everything and goes scope-only with the
   failure notice; `start` never raises.
3. The theme lock contradicted itself in four places: one model now, `render.lock` re-entrant
   within a process (like `ops.lock`); `render`, `apply_generation` and `apply` each take it;
   `ops.update` runs inside it (lock order: theme, then lease; the guard takes only the lease).
4. `update` order: `after_prev = after; after = planned; save; write; after_prev = None; save`.
5. Guard: its own session id comes from the journal's owner (the transient unit has no
   `XDG_SESSION_ID`); `sessions()` failing keeps the lease and logs; the post-wait steps are
   written out (release, reloads, unset, state, exit code).
6. `aptus-session stop` and `aptus-lease release` run the reloads and unset the environment after
   a release that acted, like the guard.
7. `aptus-lease take` refuses unless `aptus-guard.service` is active and loads the manifest.
8. `invariants.py` was committed in phase 6 with fixed signatures; writes check the realpath.
10. ini digest of "missing" and of "no leased sections" are the same value, so a restore of a
    file aptus created that KDE has since written to verifies.
11. Release saves `released` before archiving, reloads include conflict slots, `.before` data is
    passed only for file slots, and `release(expect=(signature, pid))` checks ownership under the
    flock (guard and stop).
12. `file.restore` verifies the `.before` copy against `before.sha256` before writing.
13. `run_one`/`bake` take `(target id, reload)` from the journal; `shlex` for commands; an
    unreachable Hyprland is next-start.
14. Session: the guard starts whatever the render result; no generation → no apply; the
    manifest is loaded once in `start`; recover passes the session's signature for reloads.
15. `rec.write = kind != dconf or spec.value is not None`; update never writes a record-only key.
16. `aptus-icons-*` dirs are recorded in own.json (before writing), rebuilt via rename-aside.
18. The small items: `paths` passed everywhere, `ops.lock` creates `lease/`, `leased_paths`
    lists every candidate, the preamble naming is documented, the doctor catches
    `JournalError`, `check_umbriel` reads bytes, `_pendingInputs`, the render steps complete.

**Rejected.**
- 9, partly: the spec updates are part of phase 7 as planned (done there). The wording "only
  aptus-lease writes a leased slot" is read as "only the lease package (whose CLI is
  `aptus-lease`)": session, theme and guard call it in-process. This is reported to the main
  session as a question for Lenno; CLAUDE.md is not this stage's file.
- 17, partly: `TMPDIR` is still honoured (tests may use another temp root), because phase 6
  already refuses any HOME that is, holds or lies inside the passwd home, which closes the hole.


### Review of phase 6 (fresh subagent, diff `49d04f9..f356b72`; fixed in phase 7)

11 findings. The phase rules were kept.

**Fixed.**
1. `writable(state)` refused the runtime dir, which is outside HOME in a normal session
   (`/run/user/<uid>/aptus`, for guard.state and the bake queue). State writes are now checked
   against aptus's state, cache and runtime dirs only. A test builds non-test paths.
2. `check_journal` checked every slot's path on every save, so one slot whose path changed (a
   re-stowed directory) would have stopped the whole release. Paths are now checked only while
   taking or held; during a release each slot is checked when it is restored, and only that slot
   fails.
3. Nothing protected the `before` record. Now:
   - `check_journal` requires a well-formed `before` for every slot not yet restored;
   - `journal.save` loads the journal on disk and calls `check_save`: a legal transition, no slot
     dropped, no `before` changed until released;
   - `archive` accepts only a released journal with every slot restored.
   Refusing to overwrite `slots/<id>.before` was rejected, see below.
4. `transition` now has its choke point in `journal.save`, through `check_save`.
5. Writers that skipped checks:
   - `restore` of file and ini, `update` (`check_specs`), the dconf functions (`check_key`) were
     already checked in phase 7;
   - added `writable(state)` for the journal, history, conflicts and `.before` copies;
   - `writable(own)` per Own dest, `writable(scope)` for the build;
   - `check_update`: an update writes a slot with the kind, path, key and sections it was taken
     with.
6. `require_safe_home` bypasses are closed:
   - (a) a temporary dir that is `/` or holds the passwd home is refused;
   - (b) every XDG base and aptus's state and cache dirs must resolve inside HOME;
   - (c) `APTUS_TEST=1` in the process environment counts even when a `Paths` says
     `test=False`;
   - `writable` re-checks it on every call.
7. `never_paths` gained these entries:
   - `~/dotfiles/umbriel` and `~/dotfiles/.git`, `~/.config/dconf`;
   - the user unit dir, `environment.d`, `hyprland.lua` and `hypr/hyprlock.conf`;
   - the Papirus dirs below `~/.local/share/icons`, and `color-schemes/noctalia.colors`;
   - under test, the whole sysroot and `$HOME/.aptus-test`.
8. The final link component:
   - the kinds write the realpath recorded at take, with `no_link=True`. A write path that has
     since become a symlink fails, so its link is never replaced by a file;
   - `scope_entry()` checks `scope/<into>` without following the link that `swap` replaces.
9. Ids follow `<target>.<name>` in the journal too, which also keeps them safe as filenames.
   Paths must be absolute, and no two slots may resolve to the same file (specs and journal).
10. Tests now cover:
    - the call sites firing (file write outside HOME and through a new link, `journal.save` as
      the choke point, `archive`, dconf keys never reaching the tool, signals refusing the real
      signature);
    - each failing journal case with a `match`;
    - the TMPDIR and XDG-link bypasses.

**Rejected.**
- 3(d), refusing to overwrite an existing `slots/<id>.before`:
  - take writes the copies only after recover, under the flock, and only when no journal exists,
    so no journal can reference an old copy;
  - an old copy is debris from a take that crashed before its journal was written;
  - refusing to overwrite it would block every later take for good.
- 11, the unreachable `RELEASED → TAKING` transition: harmless, kept for clarity.

### Phase 7 · implementation (2026-11-09/10)

**Done.** Every placeholder has its body, every `TODO(S2)` is gone, and the review fixes of
phases 4 and 6 are in (above).
- **Lease** (`lib/aptus/lease/`): the kinds `file`, `ini-sections` and `dconf`; the journal;
  take, update, release and recover under the flock, with preflight inside take after recover.
  `bin/aptus-lease take | update | release | recover | status`; take refuses unless the guard
  runs.
- **Guard** (`bin/aptus-guard`, `lease/guard.py`):
  - a pidfd on Hyprland, plus a self-pipe for SIGTERM, SIGINT and SIGHUP;
  - logind's user record checked every second: another session opens → release, `scope-only`
    with the notch message in `guard.state`, keep watching;
  - the bake queue retried every 30 s;
  - after the wait: release if this session owns the lease, the reload hooks, the environment
    unset (value-checked), `guard.state`.
- **Theme** (`lib/aptus/theme/`, `bin/aptus-theme render | apply | targets`):
  - the parts: inputs, Noctalia's enabled templates (read only), and the manifest (36 targets,
    `[inert]`);
  - render: generations with the input hash, `theme/lock`, `resolved.json`, `dconf.json`; scope
    builds the kitty and yazi mirrors and the starship block;
  - own: `own.json` recorded first, the icons, bat, qt6ct, generated.lua and hyprlock;
  - hooks: signal, exec, builtin and bake, in parallel with 3 s each; then apply;
  - a template for every target that is not `never`, and golden output for dark-jade and
    light-sky-high-glass.
- **Session** (`session.py`):
  - start runs recover → render → guard → take → environment import (lease only) → the
    generation's scope, Own and hooks;
  - `session.json` carries mode, reasons, notice, generation and guard;
  - stop stops the guard, or releases directly when no guard runs.
- **Doctor**: `aptus doctor isolation` with the eight checks of 02 §10, the doctor stamp, and
  the check-8 baseline.
- **Install**:
  - `systemd/aptus-recover.service`;
  - the kinds `enable-unit`, `disable-unit`, `baseline` and `release-lease`, and the approval
    group `recover`;
  - `check_action` refuses leased slots;
  - uninstall moves the scope mirrors and the Own files into `install/uninstalled-<date>/`.
- **Shell**:
  - `Lease` (read only; `lease.js` summarize);
  - `Theme`'s render requests: debounced 250 ms after the crossfade, one at a time, with a
    queue;
  - `Tokens` watches `theme/resolved.json` (marked spot only).

  Shared commits: `c54f7e6` (shell.qml binds `Tokens.ownRenderBusy` to `Theme.busy`) and
  `875c19e` (Ipc: a `lease` summary in `aptus msg shell state`).
- **Tests**:
  - `tests/unit/test_s2_{lease,guard,session,crash,doctor,theme,golden,invariants}.py`, with
    `s2_fakes.py`;
  - `tests/qml/tst_lease.qml`;
  - `tests/e2e/test_s2.py`, which uses its own fixtures and imports `Nested` without changing
    it.
- **Spec**: 02 §4–§7, §9, §11; 07 §1, §7, §9, §13; 08 §4–§8; probes.md (`builtin:hyprland`).
- **Found by the nested run with copies of the real slot files:** the two zen-chrome files
  shared the slot name `artifact`. The duplicate slot id made every take fail on this laptop.
  The manifest now names them, and `load` refuses a target whose slots share a name (with a
  test).

**Checked.**
- `tests/run` is green:
  - 319 unit tests, 222 of them S2's:
    - invariants 98, theme 64, lease 28, doctor 12, session 8, guard 7, golden 3, crash 2;
  - 167 QML tests (tst_lease 6);
  - qmllint: 122 files, 0 warnings.
- e2e: 16 passed, S1's 12 and S2's 4, in a nested Hyprland with a temporary HOME.
  - The slot fixtures are copies of the 22 real lease and bake slots (read only; never
    `~/.config/umbriel`, `~/.config/noctalia` or `~/.local/state/noctalia`).
  - The dconf fake starts from the real values (`dconf read`).
  - Each test asserts an empty `hyprctl -i <nested> configerrors`.
  - The tests and what they show:
    - logout through `aptus msg session logout`: the guard's pidfd releases, and every slot
      hash and dconf value is back;
    - `SIGKILL` to the nested Hyprland (pid checked: comm, HOME, not the real one): the guard
      releases;
    - power-off (guard and Hyprland `SIGKILL`ed, journal `held`), then the next login on the
      same HOME: recover, take again, logout, every hash back;
    - Umbriel open: scope-only, the shell's `Lease` shows `scope-only` with the notch message,
      no slot touched, Own targets themed.
  - The accent change through the shell reached Hyprland: the border equals generated.lua's
    accent, and the hook logged `applied`.
  - Screenshots: looked at all three, and they show the frame and the wallpaper.
- Unit round trip (real guard, fakes):
  - the endings: logout, Hyprland crash, power-off then the next login, power-off then the
    recover unit, Umbriel already open, Umbriel logging in mid-session, no guard, crash
    mid-take and mid-release (a child `SIGKILL`s itself on the second slot write or restore);
  - each compares every slot with the baseline;
  - `aptus-lease`, `aptus-theme`, `aptus-guard` and `aptus-session` refuse the real HOME and a
    `/tmp` link to it (exit 3, no log file).
- Coverage: every built-in template of the installed Noctalia 5.4.1 is covered, kept, inert or
  reported (test). Three are reported: `emacs`, `helix` and `wezterm`. Helix and WezTerm are not
  installed. Emacs is, but Noctalia's output (`~/.config/doom/themes/noctalia-theme.el`) does
  not exist, so its template is not enabled; the doctor would name it if it were. Every
  community template in the catalogue read in phase 1 is covered (checked against the manifest).

### Review of phase 7 (fresh subagent, diff `f356b72..e643563`; fixed in "phase 7: review fixes")

12 findings, none critical. The first reviewer died on the usage limit and was started again.

**Fixed.**
1. A failed slot skipped the environment unset, so Umbriel could get `QT_QPA_PLATFORMTHEME`.
   - `after_release` now unsets before it runs the hooks, also when slots failed.
   - The guard unsets **first**, while its session still holds the lease, so a guard killed
     half-way leaves no variable behind.
   - 02 §5.6 has the new order.
2. A release that raised killed the guard for the rest of the session. The causes were the lease
   lock busy for 10 s, a full disk, or the theme lock. `give_back` now tries 4 times, 2 s apart,
   then reports `failed`.
3. A reused generation forgot its failed targets. The next session start then failed the whole
   take on the missing output.
   - Each generation now has `failed.json`, which `current()` loads.
   - `slot_specs` leaves out a target whose output is missing.
   - `apply` re-applies an unchanged generation that this session's lease does not carry yet.
4. `is-active` (Type=exec) proved only that `execve` succeeded. Now:
   - the guard writes `ok` once its pidfd is open;
   - `aptus-session` removes the old `guard.state` and waits up to 5 s for `guard.ready`;
   - `aptus-lease take` checks the same.
5. The guard could use up a change in logind's record while nothing was held yet, or while
   `loginctl` failed. Now only a conclusive check (lease held, sessions listed) uses it up.
6. An environment import that landed after the guard released is unset again, and the session
   goes on scope-only (`environment_step`).
7. A failing recover, or any exception in `start`, could leave Hyprland without a shell. Now
   `recover_step` catches everything, and `main` writes `session.json` and starts the
   supervisor whatever happened.
8. Lease mode now means `held` (`ops.holds`); a half-released lease is the guard's to finish.
   The doctor's message for one with a live owner names the guard and `aptus-lease release`,
   not recover.
9. The guard's bake retry takes the theme lock without waiting (`LockBusy`) and skips that tick.
10. INI anchors now count repeated headers. The random round trip now includes repeated
    headers (400 files, byte-identical).
11. `load` accepts target ids only as `[a-z0-9-]` path components. The build-directory write
    pattern (private 0700 directory, one atomic rename) is written down in 08 §4.
12. `aptus-lease update` acts only for the session that holds the lease. `release` stays the
    manual escape hatch (and uninstall's `release-lease`), documented in 02 §5.6.

**Checked.** 16 new tests, one or more per finding:
- guard: 6;
- session: 4;
- theme: 3;
- lease: 2, and the INI round trip now has repeated headers;
- doctor: 1.

`tests/run` is green: 335 unit tests, 167 QML tests, and qmllint with 0 warnings on 122 files.
All 16 e2e tests pass again in the nested Hyprland.

**Rejected.** None.

### Wave-2 review fixes (2026-11-11)

The findings of `/code-review high` on the wave diff (items 1–10) and of the security review
(item 11), each checked against the code first. Every fix has a test that failed before it
and passes after it (each run against the old file once).

| # | Item | Verdict | Fix · test |
|---|---|---|---|
| 1 | `ops.update` keeps the planned `after` of a failed write; after two failed updates release reports a false conflict | Real | After a failed write `_settle` reads the slot: `after` is the paint it carries (the previous one, writes are atomic), `after_prev` is cleared. · `test_failed_updates_are_no_conflict_at_release` |
| 2 | dconf `icon-theme` is written when the `icons` target's `when` holds, not when the themes exist; a failed build leaves GTK without its icon theme | Real | A `requires` key is written only while its target's output exists (`own.in_place`: both `aptus-icons-*` with `index.theme`), else it is only recorded. The session applies the required Own targets before the take (`apply.apply_required`), so the first login still selects them. 08 §6 and the `targets.toml` header say so. · `test_slot_specs` (extended), `test_the_icon_theme_key_names_only_a_built_theme` |
| 3 | An outside render applied by `Tokens._external` fires `requestApply`, so the apps get Config's colours back | Real (reproduced in the nested shell: gen 3 with Config's accent right after the outside gen 2) | `Tokens.applyingExternal` is true while `_external` applies; Theme asks for no apply then. · `tst_theme::test_an_outside_render_requests_no_apply`, e2e `test_an_outside_render_is_not_answered` |
| 4 | `applying` is cleared only when stdout ended and the process exited; a program that cannot start leaves `applying`/`busy` true | Real. Probe (a `qs -p` scratch config, offscreen, Quickshell 0.3.2): a missing binary only emits `runningChanged` (running false), no `started`, no `exited`, no `streamFinished`; a normal run emits `exited` before `runningChanged` | `onRunningChanged`: running off without an exit ends the run as failed ("aptus-theme could not be started", never a stale stdout); `_run` clears `_done`. · `tst_theme::test_a_program_that_cannot_start_ends_the_run`, `…_either_order` |
| 5 | `from_settings` reduces motion only for `on`, ignoring `auto` with GNOME animations off | Real | `auto` reads `gsettings get org.gnome.desktop.interface enable-animations` as `Motion.reduced` does (`gsettings` added to `system.TOOLS`; a fake under test). 08 §2 lists the input. · `test_inputs_reduce_motion_auto_follows_gnome` |
| 6 | `give_back` retries the whole release when something after `ops.release` raises; the retry finds no journal and skips the hooks | Real | Only `release_if_ours` is retried; `after_release` runs once and never raises (each of its two steps is logged on failure, the next still runs). · `test_a_failure_after_the_release_still_runs_the_hooks` |
| 7 | Every login writes every slot twice (take, then `apply_generation`'s update) and runs `bat cache --build` | Real | `ops.update` skips a slot that carries the planned paint (`unchanged`); `apply_generation(taken=…)` does not update the slots the take just wrote (their hooks still run, 02 §5.3 step 8); Own files that hold the rendered bytes are not rewritten; `bat cache --build` runs only when `themes.bin` is missing or older than its source (`own.bat_stale`, so a failed build is retried). A lease target whose slots all carry the paint is reported `applied`, with no hook. 02 §5.4 and 08 §6 updated. · `test_update_skips_a_slot_that_carries_the_paint`, `test_a_login_writes_each_slot_once`, `test_an_apply_writes_only_what_changed`, `test_own_bat_builds_only_a_changed_source` |
| 8 | `check_update` raises `InvariantError` and aborts the update loop midway | Real | A spec that does not match its slot is that slot's failure (`failed[id]`); the other slots are written and the generation is recorded. The `invariants` docstring says so. · `test_update_with_a_mismatched_spec_fails_only_that_slot` |
| 9 | Two flock managers with different re-entry keying, three `_signature()` copies, `_guard_active` repeating `guard.ready` | Real (duplication) | `lease/locks.exclusive` (re-entrant per thread) behind `ops.lock` and `render.lock`; `ops.signature(env)` replaces the three copies; `guard.active` is the unit check, `guard.ready` = state `ok` and `active`, `aptus-lease take` uses `active` (same refusal as before). · `test_lease_and_theme_lock_share_one_flock_helper` (the lease lock used to let a second thread in), `test_lease_cli_take_needs_a_running_guard`; the existing lock tests pass unchanged |
| 10 | About 12 `wip` commits and `S2 shared:` commits instead of one commit per phase | Accepted deviation | No history rewrite (already merged into `v2`). The wip commits were asked for by brief rule 9: reboots wiped `/tmp` twice during the stage. This fix round has wip commits for the same reason. |
| 11 | `builtin_tmux` runs `tmux -S` for every socket in `${TMUX_TMPDIR:-/tmp}/tmux-<uid>/` without tmux's own directory check | Hardening (no reportable vulnerability) | `hooks.tmux_sockets`: the directory must be a real directory (lstat, no symlink) owned by `getuid()` with `mode & 0o077 == 0`; each socket is owned by `getuid()` and not a symlink; otherwise nothing runs and the target is "next start". 08 §7 updated. · `test_hook_tmux_only_in_a_private_socket_dir` (symlinked directory, mode 0755, symlinked socket, another uid) |

**Login path, measured.** `session.start` in a temporary HOME. It used the unit-test fakes for
systemd-run, systemctl and loginctl, a shell `dconf` fake (about 1 ms a call, like the real
one), the real `bat` (writing only into the temporary HOME) and the real Papirus through the
test sysroot. There were six logins per tree; after the first, the generation is reused. The
scratch script is `.scratch-s2/login_timing.py` in the S2 worktree (not committed).

| | `bedcdf1` (before) | after |
|---|---|---|
| first login | 2070 ms (`apply_generation` 1001 ms) | 1785 ms (572 ms: bat build, icon themes) |
| logins 2–6, median | 2232 ms (2117–2288) | 1328 ms (1237–1431) |
| `apply_generation` at logins 2–6 | 898–937 ms | 75–78 ms |
| journal saves per login | 43 | 16 |

With the Python `dconf` fake of the unit tests (about 35 ms a call), the median of logins 2–5 went
from 3584 ms (41 `dconf` calls) to 2336 ms (25). Logins 2–6 still spend about 750 ms in the take
in this HOME. That time goes to the Python fakes (`loginctl`, `systemctl is-active`) and to the
fsync of the journal after each slot (02 §5.3 step 6). Neither changed here. Real numbers need a
real login.

**Checked.**
- `tests/run`: 347 unit tests (12 new), 172 QML tests (`tst_theme`: 3 new), qmllint with 0
  warnings on 122 files.
- `pytest tests/e2e`: 17/17 in the nested Hyprland (1 new).
- Each new test fails against the file as it was before its fix.

---

## S3 · Bar and notch

### Phase 1 · plan (2026-11-09)

**Goal.** The bar and the notch of surfaces/bar.md and surfaces/notch.md, complete for S3: the
workspace strip, the active window, the tray, the status cluster, the notification server with
toasts, the held queue and history, events, the OSD, the hardware keys of 05 §6, media, the compact
live activities (media, progress; the other four come from S7–S9 through the same host) with their
cards, the bar's states (fullscreen leave M-31 with the hot edge; quiet collapse wired to
`Focus.quietBar`, its reveal is S8's), the notch's rest, morph and arbitration (notch.md §9), and
the hand-offs of the S1 simplify pass (Hypr title events, eager `windows`, Frame shadow box, one
`normalise()` per change). Services filled: `Hypr`, `Notifications`, `Progress`, `Media`, `Audio`,
`Brightness`, `Power`, `Network`, `Bt` (status), `Privacy`, `Apps`; each sets `available` when it
works. Probes P-17 and P-20.

**Architecture decisions** (not spelled out in the spec):

1. **Logic in pure JS again** (S1 decision 1): `shell/services/js/notifications.js` (interruption
   policy of 05 §8, toast timeout, stack window, history trim, held summary, body markup
   reduction), `media.js` (active-player rule, time format), `hypr.js` (workspace records for the
   strip: ids per monitor in `used`/`fixed` mode, MRU app classes, labels, urgent, special),
   `levels.js` (glyph by level for battery, volume, Wi-Fi, brightness; OSD payloads; step maths),
   `shell/surfaces/bar/js/bar.js` (strip collapse at 40 %, title throttle, tray overflow, status
   items and their order, narrow-monitor rules), `shell/surfaces/notch/js/notch.js` (compact
   slots by priority within 480 px, toast countdown with pause/resume ≥ 2 s, passive timers,
   bulge size per state, pager). qmltestrunner tests them directly: `tst_notifylogic`,
   `tst_medialogic`, `tst_hyprmodel`, `tst_levels`, `tst_barlogic`, `tst_notchlogic`, plus
   `tst_glyphs` (every glyph name S3 uses exists as a ligature in MaterialSymbolsRounded).
2. **Who posts what.** Services post passive content through `SurfaceManager.post` (they already
   own the decision): `Notifications` toasts (key `n:<id>` so `replaces_id` updates in place; the
   stack toast is the shown entry updated in place), `Audio`/`Brightness`/`Hypr` the OSD (key =
   OSD kind, one OSD per kind; skipped while the Deck is open on that monitor, notch.md §8),
   `Media` the event "Nothing to play", `Power` the battery toasts (warn once ≤ 15 %, crit until
   plugged, priority 2). The **Notch** is the presenter: it shows `passiveTop`, runs the toast
   countdown (pauses on hover and while an OSD or anything else covers it; resumes with ≥ 2 s),
   dismisses an OSD 1 200 ms after its last `born`, an event 1 600 ms after it shows, and a pinned
   card after 8 s without the pointer (the `rules.js` TODO moves into the Notch; `rules.js` only
   loses its TODO comment).
3. **Interruption policy lives in `Notifications`** (05 §8): low → Today + unread dot; normal →
   toast, unless DND, focus or a fullscreen window on the active monitor holds it (allowlisted apps
   override DND and focus); critical → toast with priority 2, no timeout; a progress hint → a
   `Progress` item until it completes (then a toast). Held notifications go to Today unread and are
   summarised in one toast when the holding condition ends ("7 notifications while you were
   focused" / "… during Do not disturb" / "… while in fullscreen"); the summary opens Today. The
   toast payload carries everything the Notch draws (`appName`, `appIcon`, `summary`, body reduced
   to bold/italic/links, `image`, `actions` ≤ 3, `critical`, `timeout`, `stack`), and the Notch calls
   back `Notifications.activate(id, action)`, `dismiss(id)`, `reply(id, text)`, `muteApp(app)`.
   History is plain records (newest first), persisted to `Paths.notificationsState` 2 s debounced,
   trimmed by `notifications.historyMax`/`historyDays`; live `Notification` objects stay tracked
   for actions while the record lives (`persistenceSupported`).
4. **Notch host.** One `Notch` per monitor (full monitor size, input via `maskItem`): the rest
   group (clock with `RollingDigits`, date after the clock, unread dot), compact slots left/right of
   the clock (shared element M-05), one bulge (`BulgeSpec`, dock `top`, centred, width/height on
   `spring.notch`, coves 0 → 14 over the first 120 ms) whose content is a crossfading stack of
   toast/OSD/event/card/mode content (old out 110 ms, new in from 60 ms; notch.md §10). Interactive
   modes load from `modeComponents` with `active`, `registerBack`/`unregisterBack`, `takesClock`,
   `clockRect` and the scrim. A pinned card closes on Esc (the shell's Esc ladder: `top` is the
   card), after 8 s without the pointer, and on a click outside: while a card is pinned the Notch's
   `maskItem` covers the monitor below the bar band and a catcher closes the card and replays focus
   to the window under the pointer (07 §5 keeps cards out of the shell-wide away catcher). Toasts
   and cards show on the active monitor only; compact activities on every monitor (05 §7).
5. **Bar.** `Bar` lays out the zones of bar.md §2 around `notchWidth`: `WorkspaceStrip`
   (`WorkspacePill` ×n, accent capsule M-02 with lead/trail edges and `spring.snappy` width, urgent
   nudge M-36, scratch pill, icon collapse at 40 %, interactions of §3), the overview button,
   `ActiveWindow` (M-03, 250 ms throttle above 4 changes/s, window menu, middle close, wheel
   cycle), `Tray`/`TrayItem` (overflow menu, DBusMenu through `QsMenuOpener` into the aptus `Menu`
   model, attention dot), `StatusCluster` with `StatusItem`s (M-04 width open/close, click → Deck
   `{section}`, or `{page}` when `deck.openPages`; wheel/middle/right actions of §6), tooltips via
   the component library. Quiet collapse (M-31b) follows `Focus.quietBar` (S8 sets it; the reveal
   on hover is S8's, marked `TODO(S8)`). Narrow monitors (< 1280 px): date hidden, title ≤ 240,
   tray ≤ 2.
6. **Hypr.** `windowtitle`/`windowtitlev2` no longer refresh; the title is patched from the
   `windowtitlev2` payload (`address,title`) into the window record. `windows` is rebuilt only when
   `toplevels` changes, cheaply (no per-window bindings). New: `workspaces` records `{ id, name,
   label, monitor, windows, apps, urgent, special, active, focused }`, `specialOpen` per monitor,
   `urgent` (from `urgent` events, cleared when the workspace is shown), `submap`, `screencast`,
   the focus history for MRU app order, workspace names from `Paths.workspacesState` applied with
   `renameWorkspace`, `activelayout` → layout OSD. The `fixed` strip follows
   `auto-workspace-monitors.sh`: eDP-1 alone holds 1–10; with an external monitor 1–5 are
   external, 6–10 eDP-1 (bar.md §3). The urgent toast "<app> needs attention on <ws>" goes to the
   active monitor when that workspace is not visible.
7. **Caps Lock OSD.** Hyprland has no Caps Lock event; the stubs show `hl.get_devices()` with
   `caps_lock` and that `hl.bind` takes a Lua function. A `Caps_Lock` bind (`locked`, `release`,
   `non_consuming`, `ignore_mods`) reads the main keyboard's state and dispatches
   `aptus:capslock-on`/`-off`, so no process forks per keypress. Shared change (binds.lua,
   Shortcuts.qml, 05/07/09 spec lines), checked in phase 5.
8. **Safety of hardware and buses** (brief): under `Paths.test` `Audio` never connects to
   PipeWire: it uses an in-memory sink/source double with the same shape (volume, muted, name)
   and `Privacy` reports nothing (screencast still from Hyprland); the PipeWire backend is a
   `Component` inside `Audio.qml` instantiated only outside tests, so nothing touches the real
   graph. `Brightness` reads `$APTUS_SYSFS` (default `/sys`) and, under `APTUS_TEST` without
   `APTUS_SYSFS`, has no backlight and no LED; it writes only through `brightnessctl` from `PATH`
   (`-d <device> set <n>`), and re-reads after its own write (sysfs has no inotify). The e2e tests
   build a fake sysfs tree and a fake `brightnessctl` in the test's own folder and start the
   nested Hyprland with them (`tests/e2e/test_s3*.py` builds them; `nested.py` gets a minimal
   `env` hook in a shared commit if it needs one). `Network`/`Bt` only read in tests (toggles
   refused under `Paths.test`). Media keys in tests act on `tests/e2e/fake_mpris.py` (system
   `python3` + `gi`), started inside the nested session (`Nested.exec`), so on its private bus.
9. **Frame** (hand-offs): no whole-frame opacity under a fullscreen window: the band and line
   slide out and fade, the bulges stay drawn so the notch (critical toast, OSD) shows above a
   fullscreen window; the drawer shadow blurs only the bodies' bounding box plus the blur radius;
   `bulge.js` gets `normalised` input so `framePath`/`bodiesPath` share one `normalise()` per
   change (`Bulge.qml` computes it once).

**Files** (new unless noted):

| Area | Files |
|---|---|
| bar | `shell/surfaces/bar/{Bar (filled),WorkspaceStrip,WorkspacePill,ActiveWindow,Tray,TrayItem,StatusCluster,StatusItem}.qml`, `bar/js/bar.js`, `bar/qmldir` |
| notch | `shell/surfaces/notch/{Notch (filled),RestGroup,CompactSlot,Toast,Osd,EventLine,MediaActivity (filled),MediaCompact,MediaCard,ProgressActivity (filled),ProgressCompact,ProgressCard}.qml`, `notch/js/notch.js`, `notch/qmldir` |
| frame | `shell/surfaces/frame/Frame.qml` (fullscreen fade, shadow box) |
| services | `Hypr`, `Notifications`, `Progress`, `Media`, `Audio`, `Brightness`, `Power`, `Network`, `Bt`, `Privacy`, `Apps` (filled); `shell/services/js/{notifications,media,hypr,levels}.js` |
| assets | `shell/assets/sounds/chime.oga` (for S8's timers and focus, if an encoder is installed; else noted) |
| tests | `tests/qml/tst_{notifylogic,medialogic,hyprmodel,levels,barlogic,notchlogic,glyphs}.qml`, `tests/e2e/test_s3_{bar,notch,keys,notifications,monitors}.py`, `tests/e2e/fake_mpris.py`, `tests/e2e/fakehw.py` (sysfs tree, `brightnessctl` fake) |
| probes | `design/probes.md` P-17, P-20 |

**Shared changes expected** (each its own `S3 shared: <file>: <why>` commit, smallest change):
`shell/windows/MonitorShell.qml` (Notch gets `hide: frame.hide` and the hot-edge reveal so it can
stay above a fullscreen window); `shell/components/Activity.qml` (`middleClick()` and
`menuTriggered(row)` hooks the notch calls, notch.md §4); `shell/core/js/rules.js` (TODO(S3)
comment removed: the pinned-card timeout lives in the Notch); `shell/core/js/bulge.js` +
`shell/components/Bulge.qml` (one `normalise()` per change); `hypr/binds.lua` +
`shell/registry/Shortcuts.qml` (Caps Lock OSD shortcuts) with 05/07/09; `shell/registry/Ipc.qml`
(S3 service summaries in `shell state` for the e2e tests); `shell/config/settings-schema.json` +
10-settings (`bar.clock.showDate` says "before the time"; bar.md and notch.md put the date after
the clock: the surfaces are right). Anything else found later is logged here.

**Risks.** (a) Material Symbols axis animation cost (P-17): measured; fallback is the crossfade
Glyph already does for name swaps. (b) Quickshell's `NotificationServer` and `replaces_id`: the
object is updated in place without a new signal, so the service listens to its property changes.
(c) The tray's DBusMenu in an aptus `Menu`: `QsMenuOpener` children are asynchronous; submenus
are opened lazily. (d) The bulge spring on every frame rebuilds the frame path (S1 risk a): frame
times measured under toasts and OSD bursts. (e) Two monitors: Notch instances per monitor share
the singletons; the active-monitor rules for toasts/cards are in `rules.js` already. (f) The fake
MPRIS player and `notify-send` need the nested bus address: they run through `Nested.exec`.
(g) Under a fullscreen window the frame no longer fades as a whole; the S1 Frame test and M-31
screenshots are re-checked.

**Checks (end of S3).** `tests/run` green (pytest, qmltestrunner incl. the new logic tests,
qmllint 0 warnings); `pytest tests/e2e` green incl. `test_s3_*`: keys → action + OSD (volume and
mute on the double, brightness on the fake sysfs, keyboard light, mic, Caps Lock, media on the fake
player, "Nothing to play"), notifications with `notify-send` on the nested bus (low/normal/critical,
replaces-id, stack, held under DND via the `Dnd` stub's state, history), Ipc `notch toast`,
fullscreen leave/hot edge, a headless output added and removed with a toast and a card open;
screenshots at 1920 × 1080 (bar dark and light, toast, OSD, compact activity and card) compared
with bar.md §2 and notch.md; budgets of 07 §12 (RSS, idle CPU and wakeups, frame times during
toast/OSD/card morphs) measured; `hyprctl configerrors` empty; no shell-log line above `info`.

### Phase 2 · structures (2026-11-09)

**Done** (types, properties, signals and record shapes only; nothing wired, nothing built):
- Record shapes as header comments of the new pure-JS libraries: `services/js/notifications.js`
  (history record, policy context, decision, toast payload, stack), `media.js` (player summary,
  the active-player rule), `hypr.js` (window, workspace and strip records; the `fixed`
  assignment of `auto-workspace-monitors.sh`, read-only from `~/.config/hypr/scripts`),
  `levels.js` (OSD payload, status glyph), `surfaces/bar/js/bar.js` (status item and input,
  title throttle), `surfaces/notch/js/notch.js` (layer, view, countdown, slot assignment).
- Bar types: `WorkspaceStrip`, `WorkspacePill` (scratch is a pill with `scratch`),
  `ActiveWindow`, `Tray`, `TrayItem`, `StatusCluster`, `StatusItem`; `Bar` gains `quiet` and
  `narrow`; `bar/qmldir` lists them.
- Notch types: `RestGroup`, `CompactSlot`, `NotchLayer` (one content in the bulge, the 110/60 ms
  crossfade), `Toast`, `Osd`, `EventLine`, `ActivityCard` (card frame + pager), `MediaCompact`,
  `MediaCard`, `ProgressCompact`, `ProgressCard`; `MediaActivity`/`ProgressActivity` get their
  id, slot and source properties; `Notch` gains `hide`, `view` and its private state (layers,
  hover card, countdowns, OSD/event timers, activity objects, slots, mode); `notch/qmldir`.
- `Frame`: `shape` (one normalised bulge set) and `shadowBox`.
- Services: `available` on Hypr, Progress, Media, Audio, Brightness, Power, Network, Privacy,
  Apps (Notifications had it; `Bt.available` keeps its S1 meaning "an adapter exists");
  Hypr `screencast`, `layout`, `workspaceNames` and the workspace record documented; Notifications
  `holding`, `muted` and its private maps; Audio `sourceName`, `testDouble`; Brightness `sysfs`,
  device names, `max`, `raw`; Power `pluggedIn` and the battery-toast state; Media `pausedSince`;
  Apps' class cache.
- Test fakes: `tests/e2e/fakehw.py` (`FakeHardware`), `tests/e2e/fake_mpris.py` (`PlayerState`).

**Changes to the plan found while writing.**
- `Audio`'s test flag is `testDouble` (`double` is a QML value-type name).
- The pinned/hover card frame is its own type (`ActivityCard`) so activity cards of other stages
  only draw their content; the host sets `monitorName`, `activity` and `pinned` on the card item
  when it has them (documented in phase 3 on `Activity.qml`'s `card`, a shared file).
- No shared file changes yet: shared changes are made complete in their own commits when they
  are needed (phase 5/7), not split over phases.

### Phase 3 · signatures (2026-11-09)

**Done** (placeholder bodies throw `not implemented` / `raise NotImplementedError`; nothing calls
them yet; existing S1 stub bodies untouched):
- `services/js/notifications.js`: urgency constants, `CRITICAL_PRIORITY`, `MUTE_MS`, fallbacks,
  `HELD_WHILE`, `KEEP_TAGS`; `makeRecord`, `decide`, `isAllowlisted`, `isMuted`, `toastTimeout`,
  `toastPayload`, `stackStep`, `stackPayload`, `heldPayload`, `reduceMarkup`, `plainText`,
  `progressOf`, history `addToHistory`/`trimHistory`/`markRead`/`markAllRead`/`removeRecord`,
  `unreadInfo`, `serialise`/`parse`.
- `media.js`: `pickActive`, `isIgnored` (time texts reuse `format.js` `clockDuration`).
- `hypr.js`: `INTERNAL`, `SCRATCH`; `fixedIds`, `workspaceRecords`, `appsOf`, `labelOf`,
  `stripFor`, `neighbour`, `parseTitleEvent`, `patchTitle`, `bumpFocus`, `isShown`.
- `levels.js`: glyph tables (`BATTERY` 8 steps, `WIFI` 4, `VOLUME`, `GLYPHS`); `batteryGlyph`,
  `volumeGlyph`, `networkGlyph`, `brightnessGlyph`, `step`, OSD payloads for volume, mic,
  brightness, keyboard light, Caps Lock, layout.
- `bar/js/bar.js` (imports `format.js`): `STATUS_ORDER`, `WINDOW_GLYPHS`; `statusItems`,
  `batteryTooltip`, `collapseLevel`, `noteTitleChange`/`titleDelay`, `trayLayout`, `deckArgs`,
  `workspaceTooltip`, `windowGlyphs`, `windowMenu`, `pillMenu`, `isNarrow`.
- `notch/js/notch.js` (imports `format.js`): `viewOf`, `keyOf`, `nextLayers`, `dropLayer`,
  `assignSlots`, `toastHeight`, `eventWidth`, countdown `Start`/`Pause`/`Resume`/`Left`,
  `pagerStep`, `longDate`.
- Services: Hypr (`stripFor`, `workspace`, `setWorkspaceName`, `moveWorkspaceToMonitor`,
  `closeWorkspaceWindows`, `togglePin`, `moveToMonitor`, `sendToScratch`, `cycleFocus`,
  `showCapsLock`, private `_onTitle`, `_onUrgent`, `_rebuildWindows`, `_rebuildWorkspaces`,
  `_loadNames`), Notifications (`activate`, `dismiss`, `reply`, `muteApp`, `markRead`,
  `markAllRead`, `remove`, `clearAll`, `toastGone`, private `_arrive`, `_receive`, `_toast`,
  `_releaseHeld`, `_changed`), Progress (`fromRecord`, `remove`), Media (`_rebuild`,
  `_noteState`), Audio (`_osd`), Brightness (`_read`, `_write`, `_osd`), Power
  (`_checkBattery`), Apps (`nameFor`, `entryFor`).
- Bar: WorkspaceStrip (`_go`, `_moveHere`, `_menu`, `_wheel`, `_placeCapsule`), WorkspacePill
  (`nudge`), ActiveWindow (`_changed`, `_show`, `_menu`, `_menuTriggered`), Tray
  (`_overflowMenu`), TrayItem (`openMenu`), StatusCluster (`_open`, `_wheel`, `_middle`,
  `_right`). Notch: Notch (`_sync`, `_layerGone`, `_openCard`, `_closeHoverCard`,
  `_dismissEntry`, `_toastActivated`/`Dismissed`/`Menu`, `_activityMenu`, `_countdownTick`,
  `_modeEntered`/`_modeLeft`), RestGroup (`_refresh`, `_menu`, `_menuTriggered`), Toast
  (`openReply`, `closeReply`), ActivityCard (`_setUp`), MediaActivity (`middleClick`,
  `menuTriggered`), ProgressActivity (`menuTriggered`).
- Python: `fakehw.BRIGHTNESSCTL`, `FakeHardware.build/backlight_value/kbd_value`;
  `fake_mpris.Player` (`metadata`, `call`, `get_property`, `changed`), `main`.
- Test skeletons (`skip("phase 7")`): `tests/qml/tst_{notifylogic,medialogic,hyprmodel,levels,
  barlogic,notchlogic,glyphs}.qml`, `tests/e2e/test_s3_{keys,notifications,bar,monitors}.py`
  (the planned `test_s3_notch` is folded into `bar` and `notifications`).

**Shared commits** (separate, see the final list): `S3 shared: shell/components/Activity.qml`
(`middleClick()` / `menuTriggered(row)` no-op hooks; the card contract comment: the Notch sets
`activity`, `monitorName`, `pinned` on the created item when it declares them; the Notch adds
"Open in Today" to every activity menu itself) and `S3 shared: shell/core/MonitorState.qml`
(the passive payload comment points at S3's toast and OSD shapes; found by the phase-2 review).

**Reported.** Reuse instead of new helpers: `format.js` already has `clockDuration` (media
times), `duration` (battery tooltip), `dateLong` + `isoWeek` (the clock tooltip), so
`formatTime`, `remainingText`, `durationText` and `isoWeek` were dropped from the new
libraries while writing. Every nested session needs the fake backlight (the brief's safety
rule, and e2e tests share one session per pytest run, so a per-module fixture would come too
late): planned as `S3 shared: tests/e2e/nested.py` (the harness builds `FakeHardware` into its
temporary root and passes `APTUS_SYSFS` and the fake `PATH` to the nested Hyprland).

### Review of phase 2 (fresh reviewer, diff `4278cdb..23e617c`)

It arrived while phase 3 was being written; the structure fixes follow phase-2 rules and are
committed separately ("phase 2: review fixes"), the fake player's fields went into phase 3's file
rewrite.

| # | Finding | Result |
|---|---|---|
| 1 | no logic, wiring or bodies in the phase | — |
| 2 | `NotchLayer.layer` shadows the FINAL `Item.layer` (qmllint, and Qt refuses to load it) | fixed: `record` |
| 3 | MonitorState's payload comment says `toast { notification }`, `osd { kind, value, label, device }` | fixed in `S3 shared: shell/core/MonitorState.qml` (points at the S3 shapes; the result-card variant stays and is notch.js view kind `result`) |
| 4 | `Notch._eventShown` is an `int` holding ms | fixed: `_eventId` (int) + `_eventShownAt` (real) |
| 5 | `Toast.replying` readonly but set by the toast itself | fixed: writable |
| 6 | bar.js battery input names differ from `Power` | fixed: the input uses the services' names |
| 7 | device-change detection specified twice (poster and `Osd._lastDevice`) | fixed: the poster owns it (`Audio._osdSink`/`_osdSource`), `Osd` only times the 1 s |
| 8 | `Bt.available` means "an adapter exists", unlike the other services | rejected: Ipc guards no Bt function, S5 builds on the S1 meaning; the bar reads `available && enabled` |
| 9 | Brightness has no monitor for the OSD | rejected: the brightness OSD goes to `hypr.js INTERNAL` (eDP-1) when it is connected, else the active monitor; no state needed |
| 10 | no `nameFor` for empty titles and tooltips | done in phase 3 (`Apps.nameFor`, `bar.js workspaceTooltip`) |
| 11 | nothing models `bar.title.show` | rejected: wiring (Bar shows the title only when the setting is on and not quiet), no structure |
| 12 | fake player lacks cover, shuffle/loop support, a no-metadata mode | fixed in phase 3 (`art_url`, `shuffle`/`loop_status` with `None` = unsupported, `bare`) |
| 13 | plan says `Bulge.qml` normalises once, structure puts `shape` on Frame | the structure holds: Frame computes `shape` once and both Bulge items take it through a new `shape` input (shared change, phase 7) |
| 14 | `Notch._osdBorn` repeats the entry's `born` | fixed: removed (the OSD timer runs from `born`) |
| 15 | `Notch._mode` repeats `monitor.notch` | fixed: comment says it is the mode whose back handler is registered, also while it fades out |
| 16 | duplicate placeholders (`pillRects`, `hovered`) | fixed: comments name the source (strip coordinates mapped by Bar; `Notch._bulgeHovered` drives timing) |
| 17 | right-click signals named three ways | fixed: `rightClicked(real x, real y)` everywhere |
| 18 | `Tray.maxItems: 3` duplicates the setting's default | fixed: `0`, the Bar binds `bar.tray.max` / `narrowTrayMax` |
| 19 | `RestGroup.unreadAccent` vs `Notifications.unreadAllowlisted` | fixed: `unreadAllowlisted` |

### Review of phase 3 (fresh reviewer, diff 23e617c..76dc96d)

| # | Finding | Result |
|---|---|---|
| 1 | Network, Bt, Privacy without signatures; no poster for the S3 events (Bluetooth device, Wi-Fi off, Charging) | Fixed: new `services/js/status.js` (`privacyKind`, `privacy`, `vpnFrom`, `btConnectedEvent`, `chargingEvent`, `wifiOffEvent`, `MIC_CLASS`, `CAMERA_CLASSES`, `EVENT_GLYPHS`) with `tst_statuslogic`; `Privacy._rebuild`, `Network._readVpn`/`_wifiChanged`, `Bt._deviceConnected`, `Power._pluggedChanged` |
| 2 | notch.js lacks the bulge size per state and the passive timers | Fixed: `bulgeSize(kind, payload, measured, tokens)` replaces `eventWidth`; `dueEntries(passive, shown, eventShownAt, pinnedSince, now, timing)` covers the OSD collapse (after `born`, shown or not, so an OSD posted under a mode never shows late), the event time and the pinned-card timeout; `Notch._expire()` runs it. The hover 300/400 ms stay with CompactSlot's rest timer and the Notch's leave timer (`_closeHoverCard`) |
| 3 | Menu trigger handlers missing | Fixed: `WorkspaceStrip._menuTriggered(record, row)`, `Tray._overflowTriggered(row)`, `TrayItem._rows(entries)` + `_menuTriggered(row)`, `Notch._toastMenuTriggered(entry, row)`, `Notch._activityMenuTriggered(activity, row)` |
| 4 | Hypr: no handlers for `activespecial`, `screencast`, `activelayout`, `activewindowv2`; layout OSD caller; scratch toggle; Rename… UI | Fixed: `_onActiveWindow`, `_onActiveSpecial`, `_onScreencast`, `_onLayout` (posts the layout OSD), `toggleScratch()`, `hypr.js splitEvent`. Rename…: the bar never takes the keyboard (05 §2), so the pill menu opens the overview with `{ workspace, rename: true }` for its F2 rename (S6 hand-off, noted in `_menuTriggered`) |
| 5a | Pinned card: click outside has no signature | Fixed: `Notch._outsideClicked(x, y)` |
| 5b | Hot edge without signature | Rejected: S1 built it in `MonitorShell` (`barInput`, 2 px, `pushTimer` with `fullscreen.hotEdgePush`, `revealed` until the pointer leaves); S3 only passes `hide` to the Notch (shared change listed in phase 1) and tests it (`test_hot_edge_reveal`) |
| 6 | Notifications: sender close, policy context, system toasts, window of an app | Fixed: `_senderClosed(id)`, `_context()`, `notifications.js systemToast(title, body, glyph, critical, timeout)`, `Hypr.windowForApp(desktopEntry, appName)`. The hold watch is wiring (`holding` binding → `_releaseHeld`, a phase-4 marker) |
| 7 | The "Deck open → no OSD" rule split over four posters | Partly: only volume, mic and brightness have Deck sliders (deck.md §4), so the rule concerns `Audio._osd` and `Brightness._osd`; `levels.js deckReplaces(kind)` holds which kinds, both ask it. Caps Lock, layout and keyboard light keep their OSD |
| 8 | Menu comments contradict the Activity contract; Cancel not in the progress menu | Fixed: MediaActivity's own row is Hide until it changes; ProgressActivity has no own rows (its `menuTriggered` signature removed, the base default stays); Cancel is on the card |
| 9 | `MUTE_MS` literal; `CRITICAL_PRIORITY` duplicates rules.js | Rejected: tokens.json holds the visual language and surface timings; the one hour is part of the menu text "Mute *App* for 1 hour" and belongs next to it. `rules.js` is shared and states the threshold in prose; `tst_notifylogic.test_critical_priority_passes_over_fullscreen` pins that a `CRITICAL_PRIORITY` toast passes `rules.arbitrate` over a fullscreen window |
| 10 | Media: ignore applied twice; card seek/shuffle/loop; lastActive on control | Fixed: `pickActive(players)` (ignored players never reach it; `_rebuild` filters with `isIgnored`); `Media.seek`, `toggleShuffle`, `cycleLoop`, `_touch(player)` |
| 11 | Superfluous: `hypr.js isShown`, `sendToScratch`, `bar.js isNarrow`, `notch.js eventWidth`, `batteryTooltip` | Fixed the first four (`isShown` → the record's `active`; `sendToScratch` → `moveToWorkspace(address, SCRATCH)`; `isNarrow` → `titleWidth(available, narrow, tokens)`, the bar.md §2/§9 title rule; `eventWidth` → `bulgeSize`). Rejected `batteryTooltip`: it is the one tooltip with logic (two durations, profile), tested on its own |
| 12 | Rule deviations: Activity `{}` defaults; `__main__`; empty `BRIGHTNESSCTL`; fake_mpris `set_property`/`Seeked` | Activity's `{}` bodies are the base defaults (a throw would break every activity without own handlers), so they are complete, not placeholders; `__main__` stays. Fixed: `fakehw.brightnessctl_script()` replaces the empty constant; `Player.set_property`, `Player.seeked` |
| 13 | Test skeletons missing (held under DND, privacy, no OSD under Deck/mode, budgets) | Fixed: `test_held_under_dnd_then_summary`, `test_sender_close_removes_the_toast`, `test_toast_ways_out`, `test_no_osd_while_the_deck_or_a_mode_is_open`, `test_hover_card_opens_and_collapses`, `test_privacy_reports_nothing_under_test`, new `test_s3_budgets.py`; QML `test_bulge_sizes`, `test_due_entries`, `test_split_event`, `test_title_width`, `test_deck_replaces`, `test_system_toast` |

Checked after the fixes: `tests/lint.sh` 146 files, 0 warnings. The notch states of the plan's
`test_s3_notch.py` live in `test_s3_bar.py` (one nested session for bar and notch states).

### Phase 4 · TODO markers (2026-11-09)

**Done.** `TODO(phase)` markers (94 in `shell/`) at every place of the owned code that changes:
the services (`Hypr`: eager `windows` and the title refresh of the S1 hand-off, the raw-event
routing to `_onTitle`, `_onUrgent`, `_onActiveSpecial`, `_onScreencast`, `_onLayout`,
`_onActiveWindow`, the names FileView and the first rebuild; `Notifications`: server, tracked
instantiator with replace and sender close, state file, `holding`, `inject`; `Progress`, `Media`,
`Audio` with its test double and the PipeWire backend behind a LazyLoader, `Brightness` with the
sysfs root and the brightnessctl writes, `Power`, `Network` with the nmcli read, `Bt`, `Privacy`,
`Apps`), `Frame` (one `shape`, `shadowBox`, no whole-frame opacity, the MultiEffect over the
box), `Bar` (zones, `quiet`, `narrow`, `pillRects`), every new bar and notch component (its
readonly bindings and its drawing), `Notch` (bulge, clock rect, rest width, mask item, view,
slots, the content tree and timers) and the two activities. The S1 markers `TODO(S3)` in
`Notch.qml` and `rules.js` stay until phase 7.

**Shared change points** (not marked in the shared files; each becomes its own `S3 shared:`
commit in phase 7, smallest change):

| File | Change |
|---|---|
| `shell/windows/MonitorShell.qml` | `Notch { hide: frame.hide }` |
| `shell/core/js/rules.js` | the `TODO(S3)` comment goes (the pinned-card timeout is the Notch's `dueEntries`) |
| `shell/core/js/bulge.js`, `shell/components/Bulge.qml` | a `shape` input (normalised once by Frame), so `framePath`/`bodiesPath` do not normalise again |
| `hypr/binds.lua`, `shell/registry/Shortcuts.qml` (+ 05 §6, 07, 09 lines) | Caps Lock bind with a Lua function → `aptus:capslock-on`/`-off`; routes `capslock-on`/`-off` → `Hypr.showCapsLock` (probe in phase 5) |
| `shell/registry/Ipc.qml` | S3 service summaries in `shell state` (audio, brightness, media, notifications, hypr workspaces) for the e2e tests |
| `shell/config/settings-schema.json` + `design/10-settings.md` | `bar.clock.showDate` "after the time" |
| `tests/e2e/nested.py` | build `FakeHardware` for every nested session (APTUS_SYSFS, PATH with the fake brightnessctl) |
| `design/probes.md` | P-17, P-20 |

**Checked.** `tests/lint.sh`: 146 files, 0 warnings. No body, type or signature changed in
this phase (the diff adds comments only).

### Review of phase 4 (fresh reviewer, diff d485811..55bf77e)

Gaps of earlier phases found by the review are filled with that phase's rules (structures and
signatures only, marked [2] / [3]); markers with phase-4 rules.

| # | Finding | Result |
|---|---|---|
| 1 | The inline reply cannot get the keyboard (`MonitorState.keyboard` is mode or pinned card only) | Fixed without touching rules.js: [2] `Notch.wantsKeyboard` (the shown toast's `replying`), shared change `MonitorShell` (`keyboardFocus` also while `notch.wantsKeyboard`); Esc is handled by the field itself, not the Esc ladder; spec fix 05 §2 (toasts never take the keyboard, except the open reply field) |
| 2 | No handler for `Toast.replied` | Fixed: [3] `Notch._toastReplied(entry, text)` |
| 3 | NotchLayer has no inputs for what it loads; no "result" kind | Fixed: [2] `monitorName`, `payload`, `component`, `args`, `activities`, `pinned`; the loader marker names result cards |
| 4 | Mode host and card contracts not wired | Fixed: markers for args/notchSerial, active, closeRequested, clockRect, takesClock (M-20), scrim, sizeSpring; result card closeRequested/hovered; ActivityCard picked |
| 5 | Unread dot colours wrong | Fixed: `ink.sec`, `accent` when allowlisted |
| 6 | `bar.clock.format` does not exist | Fixed: HH:mm via format.js time |
| 7 | Quiet and narrow do not reach the date; RestGroup has no introProgress | Fixed: [2] `Notch.quiet`, `Notch.narrow` (shared change MonitorShell passes the Bar's); showDate = setting && !narrow && !quiet; the Notch fades the rest group with introProgress |
| 8 | `notch.hoverExpand` ignored | Fixed in the CompactSlot wiring marker |
| 9 | Compact slots during a mode and under fullscreen | Fixed in the `_slots` marker (none under a mode; only recording under `hide`) |
| 10 | maskItem under `hide` would swallow clicks over a fullscreen window | Fixed in the marker |
| 11 | Refresh results update `lastIpcObject` in place; the model changes only on add/remove | Fixed: rebuild on `lastIpcObjectChanged`, coalesced (checked in phase 5) |
| 12 | PwNode has no state; camera "in use" undetectable | Fixed: a camera is in use while its Video/Source has an Active link group (`Pipewire.linkGroups`); status.js node field `linked` replaces `running` [2] |
| 13 | `extraHints ["value"]` needed for the progress hint | Fixed in the server marker |
| 14 | Images not cached | Fixed: [3] `Notifications._cacheImage(record, live)` into `Paths.notifCache` |
| 15 | `serverActive` has no source; doctor fallback | Marker: a one-shot GetServerInformation call. The doctor check is the P-20 fallback only; decided after the probe |
| 16 | Record has no hold reason | Fixed: [2] record field `held` |
| 17 | M-36 nudges the battery at critical | Fixed: [2] `StatusItem._nudge`, `_lastNudge`, [3] `nudge()`, marker in StatusCluster |
| 18 | Media fallbacks without metadata | Fixed: app icon on `raised`, the player's name as title |
| 19 | `_hiddenTrack` per monitor | Fixed: [2] `Media.hiddenTrack`, `Media.hidden`; [3] `Media.hideUntilChanged()`; removed from MediaActivity |
| 20 | "a key step unmutes" not in the spec | Fixed: dropped (the spec is the source) |
| 21 | "Nothing to play" only for XF86AudioPlay | Fixed: toggle only |
| 22 | RestGroup clockRect comment vs marker | Fixed: item coordinates, the Notch maps |
| 23 | Brightness is lazy; the first key finds no device | Accepted: shared change `shell/shell.qml` (Brightness in the eager services list) |
| 24 | Spec/shared list incomplete | Fixed: list below |
| 25 | Bar marker lacks window/fallback/introProgress/primary tray monitor | Fixed |
| 26 | WorkspaceStrip wiring incomplete | Fixed |
| 27 | `CompactSlot.hovered` marker | Fixed |
| 28 | `inject` without `Paths.test` guard | Fixed in the marker |
| 29 | UPower percentage 0..1 | Fixed in the marker |
| 30 | 100 ms polling; "40 %" literal; long markers | Fixed: single-shot timers at the deadline; `stripMaxWidthFraction`; Notch and Notifications markers split per change point |
| 31 | windowtitlev2 named twice in Hypr | Rejected: two change points (leave the refresh list, route to `_onTitle`) |
| 32 | `keepOnReload false` undecided | Decided: `true` (a dev reload keeps the server and the live objects, so actions of shown toasts keep working) |

**Shared change points, complete list after this review** (each its own `S3 shared:` commit):
`shell/windows/MonitorShell.qml` (Notch `hide`, `quiet`, `narrow`; `keyboardFocus` also while
`notch.wantsKeyboard`), `shell/shell.qml` (Brightness eager), `shell/core/js/rules.js` (TODO(S3)
comment), `shell/core/js/bulge.js` + `shell/components/Bulge.qml` (shape), `hypr/binds.lua` +
`shell/registry/Shortcuts.qml` (Caps Lock), `shell/registry/Ipc.qml` (summaries),
`shell/config/settings-schema.json` + `design/10-settings.md` (showDate wording),
`tests/e2e/nested.py` (fake hardware), `design/probes.md`. Spec lines: 05 §2 (reply field takes
the keyboard), 05 §6 / 07 / 09 / notch.md §11 (Caps Lock through a bind and `hl.get_devices()`,
no Keyboard service), 07 §6 (Brightness: `APTUS_SYSFS`, re-read after own writes, no watch),
bar.md §8 (`activespecialv2`; camera = a Video/Source with an active PipeWire link).

Checked after the fixes: `tests/lint.sh` 146 files, 0 warnings.

### Phase 5 · probe (2026-11-09/10)

**What was done.** The whole stage was implemented once on the throwaway branch `s3-probe`
(3fc86e6, kept as the reference for phase 7): the JS logic, all eleven services, every bar and
notch component, the Frame change, the MonitorShell and `shell.qml` wiring, the fake MPRIS player.
It ran in the nested session (one 931×1002 output plus a headless 1920×1080 one), driven over
`hyprctl -i`, `notify-send`/`gdbus` inside the session, the fake player and `grim`.

**How it was checked.** qmllint 0 warnings on the probe; a JS smoke test; screenshots of rest,
toast with actions, critical toast and OSD over a fullscreen window, event, compact media cover,
a 1080p bar with title, pill icons and date; `pw-dump` (read only) for PipeWire clients; per-thread
`/proc` counters for the idle budget; P-17 and P-20 (design/probes.md).

**Result.** Works end to end: notifications on the nested bus become toasts (markup, buttons,
stack, held, critical without timeout, sender close), keys step the test double and show the OSD
(the real volume is untouched), `media-toggle` reaches the fake player (`Pause` logged), "Nothing to
play" without a player, the strip, title, tray and status cluster draw, the date hides below
1280 px. No PipeWire client from the test shell. P-17 pass (axes at 60 fps), P-20 pass (no doctor
check needed).

**Budgets measured (07 §12, nested, two outputs):** CPU 0.20 % over 60 s at rest; main thread
1.5 wakeups/s (all threads 5–12/s, render and Wayland threads included); RSS 268–269 MB, over the
260 MB budget. The baseline against the phase-4 stubs was interrupted by a reboot; phase 7 measures
it to see what S3 adds.

**Gaps found, by phase** (filled in phase 7 from the probe code; none changes the design):

| Phase | Gap | Resolution |
|---|---|---|
| 2 | Notch: `_widths` (compact widths for `assignSlots`), `_pinnedSince`, `_currentLayer`/`_currentContent`, `_bulgeW`/`_bulgeH`/`_cove`, `_barNow`, a `ListModel` of layers (a Repeater over a JS array recreates its delegates) | added |
| 2 | services: Hypr `_workspaceEvents` + one coalescing rebuild timer + an Instantiator on `lastIpcObjectChanged`; Media `trackKey`; Brightness `_queue` (one brightnessctl at a time, newest value wins), `_scanned`; Network/Bt `_started` (no event for the state at start); Audio `_b` (the backend item, untyped); Bt `_bt`/`_adapter` (qmllint has no Bluetooth types) | added |
| 2 | bar: WorkspacePill `fullWidth`/`numberWidth` (the strip's collapse measures every pill at every level), WorkspaceStrip `_trailTo`/`_trailIsLeft` (M-02 trailing edge) | added |
| 3 | Notch `_noteWidth`, `_pickCurrent`, `_entry(id)`; ActivityCard `_step`; Notifications `_setToast`, `_closeToast`, `_drop`, `_monitorOf`, `_alive` (a toast entry can vanish through `rules.expire`) | added |
| 4 | `_slots` ↔ slot width formed a binding loop | width notes deferred with `Qt.callLater` |
| 4 | layer delegates anchored to a parent that is null while they are removed | x from the bulge width |
| 4 | Frame's whole-frame opacity took the notch body away under a fullscreen window (content floated without a body) | the frame fades out while a bodies-only copy fades in; the notch's bulge casts a shadow while hidden (no shared change) |
| 4 | a toast with buttons overflowed with two body lines | one body line when buttons show (the 104/132 heights fit one) |
| 4 | the critical warning glyph hid behind the fallback bell | shown for every critical notification (`nid` ≠ 0); system toasts keep their own glyph |
| 4 | surfaces lacked `import qs.services`; Network's `_wifi` property clashed with `_wifiChanged`; `Process.onExited` arrow parameters fail qmllint | import added; `_wifiDevice`; `onRunningChanged` |
| 4 | the media card's play/pause is an IconButton; notch.md §5 wants the 36 px round primary button | phase 7: a primary round button of `card.mediaPrimaryButtonSize` |
| 4 | image-data images (`image://qsimage`) cannot be copied to the cache | the toast shows the live image; the history keeps no image for them (today.md §6 note in phase 7) |
| 4 | tray submenus come from a nested `QsMenuOpener` read when the menu opens; DBusMenu may load children lazily | phase 7: checked with a real tray item; else the row opens the item's own menu |
| — | not probed yet: Caps Lock bind, a real tray item, output removal with surfaces open, the hot edge push, brightness on the fake sysfs (needs the nested.py change) | phase 7 |

**Catch-up (2026-11-10, after the phase-6 review).** The skill wants the gaps filled in phases
2–4 with their rules, before phase 6; the table above was first only carried to phase 7. Now done
in its own commit: a script compared every root-level declaration of the probe's 43 changed files
with the skeleton (82 missing: the private state, helpers and the two `activity`/`monitorName`
slot properties) and put them in, each documented, properties with neutral defaults and
`TODO(phase)` for their binding, functions with stub bodies; plus `TODO(phase)` markers at the
phase-4 change sites of the table (the layer `ListModel`, the `Qt.callLater` width notes, the
delegate x, Hypr's coalescing rebuild, the toast's single body line and critical glyph, the round
play button, image-data, tray submenus). qmllint 146 files, 0 warnings. Child objects (timers,
instantiators, models) stay `TODO(phase)` markers, as in phase 4.

### Phase 6 · invariants (2026-11-10)

**Done** (assertions only; the stubs keep their `throw`, no TODO removed, new `TODO(phase)` markers
for the postconditions):
- Every S3 JS library has an `invariant()` that throws "<lib> invariant: …", and every public
  function checks its input before the stub's throw. Rule: tokens, settings, internal state and
  the callers' arguments are checked; data from the hardware, Hyprland or D-Bus is clamped, never
  refused (a refused battery reading would break the bar).
  - `notch.js`: a legal notch state and passive top (`viewOf`); `checkLayers` (positive unique
    uids, a key and a layer kind each, never two current layers), `checkView` (the key is its
    identity, a card names a known activity, a mode a known mode, rest/hidden carry nothing), the
    serial ahead of every uid; `checkCandidates` (known activities once each, a side, a width) and
    `checkSlots` (two different activities, no candidate lost); toast heights ascending; a known
    bulge kind and an event width range; `checkPassive` (rules.js kinds, unique ids) and positive
    passive timings once entries exist (Motion gives 0 before tokens load); `checkCountdown` (one
    without a total never runs); pager ids once and a ±1 step; a real `Date`.
  - `notifications.js`: `checkRecord` (non-zero integer id, an app name, a freedesktop urgency, no
    `default`/`inline-reply` among the actions, progress −1 or 0–100, a known hold reason),
    `checkContext` (a known `notch.overFullscreen`), `checkDecision` (critical is never held or
    sent to Today; priority 2 exactly for critical toasts), `checkTiming`, `checkStack` (≤ 3
    icons, distinct apps), a stack toast only for ≥ 2 and a live passive id, a held summary only
    for ≥ 1 and a known reason, a system toast with a title and a timeout unless critical,
    strings into the markup functions, `checkHistory` (each id once), history limits ≥ 1.
  - `hypr.js`: unique monitor names, workspace ids and focus order; a name limit ≥ 2; the strip
    mode; a ±1 wheel step; `isAddress` ("0x" plus hex digits) for `bumpFocus` and `patchTitle`;
    `checkStrip` (pills once each, in id order, one active at most, no special workspace).
  - `levels.js`: battery thresholds 0 < crit < warn ≤ 100, a ±1 step of a positive size inside
    min < max, a keyboard level inside 1..max, finite OSD levels, known OSD kinds; `checkOsd`.
  - `media.js` (each player key once, a list for `media.ignore`), `status.js` (a node list, a
    string from nmcli), `bar.js` (`checkBarTokens`: thresholds and title widths in order; the
    `bar.battery.percent` / `bar.bluetooth` enums; strip widths ≥ 0; the throttle state; tray max
    a whole number ≥ 0; a Deck section; a window for the window menu, a normal workspace for the
    pill menu; `checkMenu`: an id and label per row, each id once, submenus too).
- QML guards (refuse and log, never throw): `Brightness._refused` (under APTUS_TEST only a tree
  from `APTUS_SYSFS` and only `aptus_test…` devices are written; `fakehw.py` now names its devices
  `aptus_test_backlight` and `aptus_test::kbd_backlight`, so a real `brightnessctl` that slipped
  onto PATH finds no such device: before, the fake used the real names `intel_backlight` and
  `tpacpi::kbd_backlight`), `Audio._refused` (under APTUS_TEST every setter writes the double,
  never PipeWire), `Notifications.inject` (refused outside the test).
- Tests: the S3 QML tests are now real (55 cases across levels, medialogic, statuslogic,
  hyprmodel, barlogic, notchlogic, notifylogic, glyphs) plus one `test_invariants_reject_broken_state`
  per library (7: the refused cases, and the `check*` helpers accepting good input) and
  `test_restart_ids_do_not_collide`: 63 in all. `tst_glyphs` shapes every glyph name S3 uses (the JS lists,
  the menus, the names written in the QML) with the bundled font and requires one icon-wide glyph.

**Checked.** On the branch: the 7 invariant tests pass against the stubs (each check fires before
the stub's throw); the other S3 cases fail with "not implemented" until phase 7 (56 cases);
unit 97 passed; qmllint 146 files, 0 warnings. Against the probe (scratch copy of `s3-probe` with
the checks inserted into its functions by script): every S3 test passes except
`test_restart_ids_do_not_collide`; the glyph test fails as it should when a bogus name is added.

**Found** (fixed in phase 7):
- Notification ids restart at 1 with every shell start, but read-back history records kept their
  old ids: the first new notification replaced (and `markRead`/`removeRecord` would hit) an
  unrelated old record. Read-back records get `ARCHIVE_ID − index` (`ARCHIVE_ID` = −1000000,
  below every server and injected id); the record comment says so.
- The probe's `Hypr._onActiveWindow` turns an empty `activewindowv2` (no window focused) into the
  address "0x" and bumps it into the focus order; `isAddress` refuses it, phase 7 ignores the
  empty event.
- The probe's `StatusCluster` passes `Config.get(...)` for the two bar enums, which is undefined
  until Config has loaded; the enum check would log at start. Phase 7 passes the schema defaults
  as fallbacks.
- The fake hardware used the real device names (above).
- From phase 5: the structural gaps of its table come over with the probe code in phase 7;
  nothing in it belongs to phase 6. (Wrong: see the review below and the phase-5 catch-up.)

### Review of phase 6 (fresh reviewer, diff 664e61d..26db87c)

The reviewer ran the seven invariant tests (pass) and read the diff against the skill's rules.
18 findings; all fixed but the alternative in 10:

| # | Finding | Response |
|---|---|---|
| 1 | The phase-5 catch-up was never done; its table said "added" | fixed: catch-up commit (phase 5 section above), then the invariants for it (Brightness `_queue`, Audio `_b`, below) |
| 2 | `test_persistence_round_trip` still expected the old ids [2, 1] | fixed: times [3000, 2000], ids `ARCHIVE_ID`, `ARCHIVE_ID − 1` |
| 3 | `checkOsd` and the `isFinite`/`level ≤ max` preconditions refuse hardware levels (a sink at 130 % from pavucontrol) | fixed: only the maximum is checked (`volumeOsd(level, muted, max, device)` now takes it from `osd.volumeMax`/`volumeBoostMax` instead of a boost flag); the level is clamped into 0..max, NaN is 0; tests for 130 %, NaN, a keyboard level above max |
| 4 | `hypr.js` refused duplicate workspace ids and monitor names (Hyprland data; a placeholder can repeat an id for a moment) | fixed: a later duplicate is dropped (TODO), a monitor listed twice counts once; test; `Hypr._onTitle` skips an event whose address is not one before `patchTitle` (phase 7) |
| 5 | A damaged state file could empty the history and the next save overwrite it | fixed: `parse` clamps `held`, drops a record failing `checkRecord` and a repeated id; test with `"held":"asleep"`, `"constructor"`, urgency 7 |
| 6 | Re-keying breaks the link to notifications the server still tracks after a reload with `keepOnReload` | fixed: `parse(…, keep)`; records whose id the server tracks at load keep it. P-23: a reload happens only with `APTUS_DEV` (file watching), a normal start is a new process with nothing tracked, so `keep` is empty there |
| 7 | The Audio guard was a tautology once `testDouble` = `Paths.test` | fixed: a write is refused while the PipeWire backend exists under APTUS_TEST (`_b`), and the backend appearing there is logged |
| 8 | `checkSlots` only counted | fixed: every candidate exactly once, each slot on its own side; tests |
| 9 | A critical progress notification had priority 0, so its fallback toast lost priority 2 | fixed: priority 2 exactly for critical, whatever it shows (`decide` too, phase 7) |
| 10 | The suite is red at the phase-6 commit (the behaviour cases fail on the stubs) | noted here: from phase 6 until the phase-7 commit `tests/run` is red by design (stubs keep their `throw`); the behaviour cases came in phase 6 because the checks were run against the probe with them (a check that refuses good input shows there). Keeping the skips instead: rejected for that reason |
| 11 | `HELD_WHILE[x] !== undefined` accepts "constructor" | fixed: `isHoldReason` (own keys only) |
| 12 | `systemToast` accepted a missing title | fixed: a non-empty string |
| 13 | `checkStack` without list checks; apps not bound by count; a test fixture with no apps | fixed: lists, 1 ≤ apps ≤ count; fixture fixed |
| 14 | `pillMenu` took a negative id for special; named workspaces have negative ids (−1337 down) | fixed: `special` alone; `workspaceRecords` tells special by the name (`special`, `special:…`); tests |
| 15 | No postconditions for `dropLayer` and `nextLayers` | fixed: `dropLayer` only drops a leaving layer; `checkNext` (one current layer with the view's key, none at rest/hidden, the serial never back) |
| 16 | Brightness compared the sysfs root with "/sys" only | fixed: under APTUS_TEST the tree must lie inside HOME (the Paths rule); the e2e fake hardware moves into the test HOME |
| 17 | `appsOf` re-checked the focus order per workspace | fixed: `workspaceRecords` checks it once |
| 18 | The `dropLayer` refusal test tripped the wrong check | fixed: one current layer, refused because it is current |

**Checked.** qmllint 146 files, 0 warnings; the 7 invariant tests pass against the stubs; the
behaviour cases fail with "not implemented" (finding 10).

### Phase 7 · implementation (2026-11-10/11)

**How.** The probe's code (`s3-probe`, 3fc86e6) was brought over file by file onto phase 6: the
JS libraries keep their phase-6 checks and gain the postconditions, the QML keeps the skeleton's
documentation and the phase-6 guards, every `TODO(phase)` is resolved (none left; the remaining
TODOs name their stage, e.g. `TODO(S8)` for the quiet-bar reveal). Then the stage was run in the
nested session until every acceptance row of the brief held, fixing what that showed:
- **Notch.** The expiry timer was stopped by an older `_expire` call (an event after an OSD
  stayed); the held summary was posted inside a SurfaceManager apply and lost; the hover card did
  not collapse (SurfaceManager applies the notch and the passive top one after the other, so
  `view` passed through "rest" and `_sync` cleared the stored card): the hover card is now derived
  from the MonitorState (a `card:` notch without `pinned`), the bulge and both compact slots are
  one hover area (`_pointerIn`), and `viewOf` takes only the monitor state (its hover and
  active-monitor arguments were unused and made `view` depend on fields `_sync` writes). An OSD no
  longer covers a toast whose reply field is open (`_replyEntry`; typing would lose the field),
  and the reply field takes the button row instead of growing the bulge below it.
- **Hypr.** The layout OSD only for a keyboard's own layout change (`_layouts` per keyboard;
  Hyprland's `error` for an unnamed keymap ignored): wtype's virtual keyboard showed "error", then
  the real layout. Malformed and empty events (no focused window) are ignored, titles are patched
  from `windowtitlev2`, the rebuild is coalesced (S1 hand-off).
- **Frame and bulge** (S1 hand-offs): the shadow blurs only the bodies' bounding box plus the blur
  radius; `bulge.js` draws from one normalised set (`framePathOf`, `bodiesPathOf`), `Bulge.qml`
  takes an optional `shape`, and Frame normalises once per change for its three Bulges and the
  shadow box (`shape`, `shadowShape`).
- **Idle.** A status item's tooltip text follows the item only while hovered (`_liveTip`/`_tip`):
  a hidden tooltip label still redrew the layer on every NetworkManager strength signal (~6 s) and
  battery-time change.
- **Tray.** Checked with a real StatusNotifierItem (`tests/e2e/fake_sni.py`, nested bus only,
  DBusMenu with a separator and a submenu): click activates, right click shows the DBusMenu as an
  aptus menu, a row triggers its event, submenus open (they come with the full layout),
  NeedsAttention draws the dot. A tooltip stayed over an open menu (under the menu's catcher the
  hover state is not updated): bar and notch tooltips hide while a menu is open on their monitor
  (`_menuOpen`, WorkspacePill `menuOpen`); the tray's submenu openers are freed at the next open
  (`_subOpeners`).
- **Look** (screenshots at 1920 × 1080, compared with bar.md §2 and notch.md): the rest date in
  `micro` / `ink.meta` (notch.md §3); the keyboard-light OSD marks the current state's dot instead
  of filling up to it (the payload was already state-shaped; levels.js comment fixed); the media
  card's play/pause is the 36 px round primary button; the compact cover (18 px, radius 4) and the
  card cover (88 px, radius 10) checked with a player that has art.
- **Assets.** `shell/assets/sounds/chime.oga`: a soft two-tone chime (A5, E6 after 120 ms, a faint
  A6), 1.5 s, mono 48 kHz Vorbis, peak −6 dBFS, 8 KB, made with sox from sine tones; for S8's
  timers and focus (`timers.sound`, `focus.sound`).
- **Tests.** The e2e suites replace the skips: `test_s3_bar` (8: the strip follows workspaces,
  fullscreen leave with a critical toast above, the hot edge, a pinned card's ways out, the hover
  card, the tray, privacy empty under test, screenshots), `test_s3_keys` (9: volume, mute and mic,
  brightness on the fake backlight, keyboard light, Caps Lock, media keys on the fake player,
  "Nothing to play", an event after an OSD leaves on time, no OSD while the Deck or a mode is open),
  `test_s3_notifications` (12: aptus owns the name, normal toast and history, low to Today only,
  critical without timeout, replaces-id, a burst as one stack toast, Ipc `notch toast`, held under
  fullscreen then the summary (planned as "under DND"; `Dnd` stays S8's stub with no way to
  switch it on, so DND holding is covered by `tst_notifylogic` only), sender close, a toast's ways out, the toast queued behind Spotlight,
  the inline reply: Esc keeps the toast, Enter sends `NotificationReplied`),
  `test_s3_monitors` (1: a headless output added and removed with a toast and a card open),
  `test_s3_budgets` (2), `test_s3_zlog` (1: no shell-log line above info after all others).
  Helpers: `fakehw.py` (sysfs tree and `brightnessctl` fake in the test HOME), `fake_mpris.py`
  (`--art=`), `fake_sni.py`, `s3bus.py` (nested-bus helpers, `FakePlayer`, `FakeTray`, pixel grabs).

**Spec, same stage** (shared commits): notch.md §6 (the reply field in the button row, not
covered by an OSD) and §11 (layout changes per keyboard), 05 §2 (the reply field takes the
keyboard) and §6 (Caps Lock and layout source), 09 §7 (the Caps Lock bind), settings-schema and
10-settings (`bar.clock.showDate` is after the time), bar.md (`activespecialv2`, camera), today.md
(image-data, archive ids), 07 (Brightness sources).

**Checked:**
- `tests/run` (2026-11-11, after the reboots): pytest 97 passed; qmltestrunner 241 passed (S3:
  notifylogic 17, notchlogic 10, hyprmodel 10, barlogic 10, levels 7, statuslogic 5, medialogic 5,
  glyphs 1; bulge 8 with the new shared-set case); qmllint 146 files, 0 warnings.
- `pytest tests/e2e` (45 tests: S1 12, S3 33) in a nested Hyprland. The last full run (2026-11-10)
  was 41/42, the one failure the idle-wakeup budget (3.33/s, fixed below); after the fixes the
  suites ran again on the changed code: notifications + keys 21/21, bar 8/8 (with the tray test,
  after the tooltip change), the budget re-measured on whole minutes. The final full run on the
  phase-7 commit could not be made: after the two reboots on 2026-11-11 the machine is in the
  Umbriel session, and the harness runs only inside Hyprland (it refuses without the real
  session's signature, by design). Open item below.
- Screenshots (rest dark and light, toast with actions, light toast, OSD volume and keyboard
  light, event, compact media with cover, media card, critical toast over a fullscreen window)
  looked at and compared; they were in the session scratchpad, which the reboot wiped, so none
  are kept under `tests/e2e/shots/` yet (`APTUS_SHOTS=<dir>` keeps the next run's).
- P-17 pass, P-20 pass (design/probes.md, 664e61d). `hyprctl configerrors` empty (test_s1) and no
  shell-log line above info (test_s3_zlog; the one known line, `qt.qpa.services … Failed to
  register with host portal`, is the nested session's portal notice) in the last full run.

**Budgets** (07 §12, nested session, shell process):

| Budget | Measured | Limit |
|---|---|---|
| RSS at rest | 251 MB | ≤ 260 MB |
| CPU at rest (60 s) | 0.20 % | < 0.3 % |
| Main-thread wakeups at rest (whole minutes, one clock roll each) | 1.62/s and 1.55/s (before the tooltip fix 2.22 and 3.10/s) | ≤ 2/s |
| CPU while animating (5 toasts, 20 volume steps) | 21.0 % of one core | < 50 % (frame-time stand-in; GPU side is P-21) |

At rest a fresh session wakes the main thread ~0.7 times a second; the clock's minute roll (M-34)
costs ~70–90 switches with the threaded render loop, ~46 with `QSG_RENDER_LOOP=basic`. The phase-5
RSS (268 MB) came down without a baseline run against the stubs; within budget, so not repeated.

**Found in phase 7** (structure the earlier phases did not have; each documented where it lives):
Notch `_replyEntry`, `_pointerIn`, `_hoverCard` (now derived, read-only), `viewOf(state)` without
its two other arguments; Hypr `_layouts`; Frame `shape`, `shadowShape`, `_specs(shadowOnly)`;
`Bulge.shape`, `bulge.js` `framePathOf`/`bodiesPathOf`; StatusItem `_liveTip`/`_tip`; TrayItem
`_subOpeners`; `_menuOpen` in TrayItem, Tray, ActiveWindow, WorkspaceStrip, RestGroup, and
WorkspacePill `menuOpen`; e2e `FakeTray`, `fake_sni.py`, `vpointer.py rclick`, `FakePlayer(art=)`.

**Shared commits of phase 7:** 178447f Ipc (S3 services in `shell state`), 213a3d7 Shortcuts and
cc32429 binds.lua (Caps Lock OSD), d652b73 test_binds_lua (function binds), 1257766 Button
(round), 2b3ce83 shell.qml (Brightness eager), eeea0f9 MonitorShell (notch keyboard, hide, quiet,
narrow), d8919fe notch.md (Caps Lock source), 1efbe02 07 (Brightness sources), 4a500b0 bar.md
(`activespecialv2`, camera), aea6740 today.md (image-data, archive ids), b6d1b40 rules.js (pinned
card timeout in the Notch), 184085b nested.py (fake hardware), 4f528fd bulge.js + Bulge.qml (one
normalise), 3a3fbc7 09 §7, a589dd8 05, af64e27 settings-schema, 4fd0972 10-settings, 2a074bb
notch.md (reply field, layout), e1cf6f3 vpointer.py (right button).

**Note.** One `hyprctl monitors -j` (read only) ran without `-i` against the real session while
looking for the nested output; nothing was changed. Every other call named the nested instance.

**Open:**
- The final full `pytest tests/e2e` on the phase-7 commit and the kept screenshots, in a Hyprland
  session: `APTUS_SHOTS=tests/e2e/shots /home/lenno/Code/Projekte/aptus/.venv/bin/python -m pytest
  -p no:anyio tests/e2e -q` from the worktree.
- Shell-wide: the basic render loop would halve the clock roll's cost (not S3's decision); the
  shared `Tooltip` redraws while hidden when its text changes (S3 freezes its texts; a central fix
  belongs to the components).
- Tray apps that load DBusMenu children lazily may show an empty submenu (Quickshell's
  `QsMenuOpener` reads the layout when the menu opens; it also sends "opened" at start).
- The lock-screen half of the hardware keys is checked again in S6; a real tray app on the laptop
  (only the fake item was tested) in the S3 hands-on round.

### Review of phase 7 (fresh reviewer, diff `1369d8a..4f531c6` without PHASES.md; fixed in "phase 7: review fixes")

The reviewer ran `tests/run` (green: pytest 97, qmltestrunner 241, qmllint 146 files 0 warnings)
and read the diff against the goal, the phase-7 rules and the spec. 32 findings: 1–28 and 30
fixed (9, 24, 25 and 30 in part, the rest of each rejected with its reason; M-31b of 23 deferred
to S8), 29 rejected, 31 in part (its e2e cases come with the final e2e run), 32 agreed.

| # | Finding | Response |
|---|---|---|
| 1 | `onPassiveChanged` ran `_expire` inside a SurfaceManager apply; a dismissal there was overwritten by the rest of the apply | fixed: deferred with `Qt.callLater`, like `_sync` |
| 2 | A replace or a stack join (SurfaceManager.update) did not restart the toast countdown (notch.md §6 rule 3); a stack toast could vanish just after a join | fixed: `_countdownPayloads` (entry id → payload the countdown started for); a new payload object restarts it (checked that QML keeps the payload's identity through `property var` and SurfaceManager's two-level compare) |
| 3 | `_countdowns` kept entries of toasts closed through Notifications | fixed: each tick keeps only entries still in the monitor's passive list |
| 4 | Battery warn and crit toasts shared the key "battery": the warn toast replaced the crit one (priority 0, 9 s) | fixed: keys `battery-low` / `battery-crit`; the crit toast also counts as warned |
| 5 | `_urgentToasted` never cleared; `urgent` never pruned of closed windows | fixed: a workspace leaves `_urgentToasted` once shown or without an urgent window; `_rebuildWindows` drops closed windows from `urgent` |
| 6 | `_cacheImage` copied any path a sender names (`/dev/zero`, a FIFO, huge files), copied again on every replace, never deleted copies | fixed: only a regular file of at most `IMAGE_MAX_BYTES` (8 MB), `timeout 5 cp`; `_setHistory` deletes the copy of a record that leaves (a replace, trim, removal) unless another record uses it, and only files directly in the cache (`_inCache`: a sender's `…/notif/../x` is neither kept nor deleted); copies older than `historyDays` go at start |
| 7 | Records trimmed from the history kept their live Notification | fixed: `_setHistory` dismisses and drops the live object of every record that leaves |
| 8 | `MediaActivity._pausedLong` not armed when created with a player already paused | fixed: `_armPaused()` also at `Component.onCompleted` |
| 9 | MediaCard `_position` stale after a player/track change while paused; `onCanceled` not handled; `interval: 1000` literal | fixed: `_readPosition()` on player, track (`postTrackChanged`), play state and visibility; `onCanceled` ends the drag. The literal: rejected, see 25 |
| 10 | `Qt.callLater(_noteWidth, …)` from both slots kept only the last call's arguments | fixed: widths collect in `_pendingWidths`, one `_flushWidths` later |
| 11 | Wheel handlers step once per event (touchpad, high-resolution, TrackPoint scrolling jump) | fixed: `bar.js wheelSteps` (one step per 120 of `angleDelta`, the rest carried, dropped when the direction turns; `tst_barlogic`); status items take every step, pills, strip and title at most one per event (Hyprland's state lags a second one) |
| 12 | `pillRects` and the pill menu anchor missed the pill box's x | fixed: rects add `content` and `pillBox`; the menu anchor maps from the pill |
| 13 | A pinned card under a toast kept the catcher, the whole-monitor mask and the keyboard | fixed: the Notch's `_pinnedShown` (catcher and mask only while the card shows) and rules.js `keyboard()` (shared, `tst_rules`) |
| 14 | A replace of a stacked notification joined the stack again (count + 1) | fixed: `_stackIds`; a replace of a member updates the stack toast's payload |
| 15 | The pinned-card catcher swallowed bar clicks | fixed: a press on the bar band closes the card and is not accepted, so the bar below gets it |
| 16 | Compact activities stayed while Overview or Capture is open (notch.md §9) | fixed: `_slots` empty then |
| 17 | The recording compact could not show above a fullscreen window (the whole centre row slid out) | fixed: each part of the centre group slides and fades on its own, a slot showing recording stays and keeps input; where it sits under a bulge is `TODO(S9)` |
| 18 | No in-place content crossfade; `NotchLayer.plain` was dead | fixed: the Toast crossfades its content in place (old out over `morphOutMs`, new in over `fade`; M-06 not replayed); `plain` and Toast `entrance` removed |
| 19 | The rest menu did not match notch.md §3 | fixed: Do not disturb ▸ (For 1 hour, Until tomorrow 08:00 as in deck.md, Until I turn it off; Turn off while on), Start focus ▸ (25, 50, 90 min), Open calendar settings (Settings page `today`). Found on the way: the toast menu opened the Settings page `notifications`, which does not exist; now `notch` (where `notifications.*` live) |
| 20 | Pills: no `raised` fill for used inactive pills, empty pills in `ink.sec` (bar.md §3) | fixed: `raised` fill, `ink.faint` for empty pills, "+n" in `ink.meta` |
| 21 | Type and ink deviations (toast and media titles `bodyStrong`, artist `ink.sec`, window glyphs `faint`); body 1 line with buttons vs "2 lines"; media title 1 line vs "two lines" | fixed: titles `title`, artist and window glyphs `ink.meta`. The lines: the 72 toast cut a second body line off (app line + title + one body line fill it), so one body line everywhere (`toast.bodyMaxLines` 1, shared) and notch.md §6/§12 say so (shared); the 132 media card has no room for a second title line |
| 22 | Tray overflow rows have no icons (bar.md §5) | fixed: Menu rows take an `icon` (shared, AppIcon in the lead place); the overflow passes the item's icon |
| 23 | M-35 dot not on `spring.snappy`; M-03 icon literal easing, no crossfade; M-31b instant toggles | fixed: M-35 `SnappySpring`; M-03 the old icon fades out while the new fades in from `title.iconScaleFrom` on the standard curve. M-31b: deferred to S8 (`TODO(S8)` in Bar.qml): `Focus.quietBar` is S8's and cannot be switched on before it, and the hover reveal S8 builds plays the same fade and collapse back |
| 24 | Hover/click cards open on whichever monitor's slot | fixed for hover (only on the active monitor); click: Hyprland makes the clicked monitor the active one (`misc:mouse_move_focuses_monitor`) |
| 25 | Literals: MediaCard 1000, RestGroup + 20 ms, StatusItem `* 3 / 4`, `/ 2` | fixed: `bar.statusOverlaySize`, `bar.statusExtraSize` (shared). Rejected: the 1000 ms is how often a position is re-read from MPRIS and the 20 ms keeps the minute timer from firing just before the boundary; neither is a design duration (the services' timers are literal for the same reason) |
| 26 | `pragma ComponentBehavior: Bound` missing in MediaActivity, ProgressActivity | fixed |
| 27 | CompactSlot `hoverLeft` and `leaveTimer` dead | fixed: removed |
| 28 | `markRead` guard never held (always a new array) | fixed: `N.markRead` returns the same array when nothing changes (`tst_notifylogic`) |
| 29 | `Notifications.available` always true | rejected: `available` gates the IPC path (`notch toast`, the policy, the history), which works without the bus name; owning the name is `serverActive` (P-20), with a warning in the log when another server has it |
| 30 | Volume-up above the maximum lowered it; unplugging at ≤ 15 % gave no warning; Brightness picks the first backlight; Frame normalises twice | fixed: `levels.step` never steps against its direction and `stepVolume` leaves the level alone then (`tst_levels`); unplugging checks the battery at once. Rejected: since Linux 6.1 the kernel registers one backlight per panel (acpi_video only where native does not work), this machine has `intel_backlight` only, and a type preference would be a guess; Frame normalises two different sets once each (all bulges; those with a shadow), and merging depends on neighbours, so the shadow set cannot be filtered from the full one |
| 31 | Missing coverage (progress, urgent, layout OSD, battery, quiet, wheel, ✕/menu, tray overflow, countdown restart); weak burst and monitors tests; privacy test reads PipeWire | in part: unit tests for the pure parts (wheel steps, step direction, markRead, keyboard under a toast). The e2e cases (progress activity from a `value` hint, urgent toast and its repeat, layout OSD, battery toasts, countdown restart on replace, burst count and apps, the monitors test's fixed 1–5 / 6–10 split, ✕ / middle click / toast menu, tray overflow, wheel) are written together with the final e2e run: none can run outside Hyprland now, and an unrun e2e test is not added. The privacy test: rejected, the brief allows reading the real PipeWire state (`pw-dump` only reads) |
| 32 | The final full e2e run and the screenshots are missing | agreed: a blocker before the wave merges (report) |

**Checked:** `tests/run` green after the fixes: pytest 97; qmltestrunner 242 (new cases in
barlogic, levels, notifylogic, rules); qmllint 146 files, 0 warnings. Not checked on screen: the
machine is in the Umbriel session (finding 32), so every fix that changes what the notch and bar
draw (the in-place crossfade, the recording slot under `hide`, the catcher on the bar band, pills,
titles, the rest menu, the M-03 icon) waits for the final e2e run and its screenshots.

**New since phase 7** (found in review): Notch `_countdownPayloads`, `_pinnedShown`,
`_pendingWidths` + `_flushWidths`; Toast `_p`, `_swap`, `_ready` (and no `entrance`); NotchLayer
without `plain`; Notifications `_setHistory`, `_inCache`, `_stackIds`, `N.IMAGE_MAX_BYTES`;
MediaActivity `_armPaused`; MediaCard `_readPosition`; `bar.js wheelSteps`, `WHEEL_UNIT`;
`_wheelCarry` in StatusItem, WorkspacePill, WorkspaceStrip, ActiveWindow; ActiveWindow `_oldIcon`,
`_oldAppName`, `_iconSwap`; Menu rows' `icon`; tokens `bar.statusOverlaySize`,
`bar.statusExtraSize`. CompactSlot loses `hoverLeft`.

**Shared commits of the review fixes:** 4621544 rules.js (keyboard under a covered card), 6dff347
tokens.json (one body line, status glyph sizes), 6300ab8 Menu.qml (row icons), 59d4cfd notch.md
(one body line, one title line).

### Wave-2 review (S3), 2026-11-11

The findings of `/code-review high db4d5fc..18a1af8` for S3 (items 1–10, the 07 note), the three
items the main session's full e2e run on `18a1af8` found (A–C), and the e2e cases phase 7's review
left open (finding 31). Each item was checked against the code first. Every fix has a test that
failed against the file as it was before the fix and passes after it.

| # | Item | Verdict | Fix · test |
|---|---|---|---|
| 1 | Osd shows the device name only from `onPayloadChanged`, which would not run for the first payload | Mechanism wrong: a change handler does run for a binding's first value at creation (checked on Qt 6.11, `tst_osd` loads the Osd as NotchLayer does). Related defect real: the label read `payload.device`, so the next press (no device) showed the value at once, and an OSD of another kind kept the flag | The Osd keeps the name and its kind for `osd.deviceNameMs`; another kind ends it. · `tst_osd` (3) |
| 2 | The strip's Repeater gets a fresh array on every rebuild, so all pills are recreated and the urgent nudge never runs | Real | A `ListModel` synced by workspace id (`bar.js syncIds`: remove, move, insert in place); each pill has `required property int wsId` and looks its record up, so updates reach the existing pill and the nudge fires on the urgent edge. Shared commit `cb4bb3c`: `qs.services` doubles (Hypr, Apps) in the QML mock. · `tst_workspacestrip::test_sync_ids_in_place`, `…_pills_survive_a_rebuild_and_nudge_on_the_urgent_edge` |
| 3 | `_layouts` empty at start: the first layout switch per keyboard shows no OSD | Real | `hyprctl -j devices` once at start (`hypr.js layoutsFromDevices`: every keyboard's `active_keymap`, the main keyboard's as `layout`); values from events win; no OSD at start. · `tst_hyprlayouts` (3), e2e `test_layout_osd_on_the_first_switch_after_the_start` |
| 4 | `decodeURIComponent` on a sender's `file://` URL throws out of `_receive` | Real | `notifications.js imagePath`: a URL that does not decode is no image; the notification arrives and stays live. Found by the full e2e run (`test_s3_zlog`): the toast still handed that URL to its Image, which logged a warning; the toast now shows from the live notification only image-data, icons and local files (`liveImage`). · `tst_notifications::test_a_malformed_image_url_is_no_image`, `tst_notifylogic::test_image_path_and_live_image`, e2e (the bad URL in `test_image_is_copied_once_for_its_replaces`, then `test_shell_log_has_no_warnings`) |
| 5 | `clearAll()` leaves toasts, Progress items and `held` | Real (all three) | `clearAll` closes the cleared records' toasts and the stack toast, removes their Progress items, dismisses the live objects and empties the held list. · `tst_notifications::test_clear_all_closes_toasts_progress_and_held` |
| 6 | The record gets the copy's path whether the copy worked or not; every replace copies again | Real | One copy job per source (a `Process`) prints "ok", the source's size and mtime and the copy; the record gets the image only then (no image when it fails); a replace with an unchanged source reuses the copy; a copy no record uses any more is deleted. Found by the e2e test on the way: Quickshell hands an `image-path` hint that is not a `file://` URL as `image://icon/<hint>`, so a plain path was never copied; `imagePath` takes the path out of it. · `tst_notifications::test_the_image_is_set_once_its_copy_is_confirmed`, `…_a_replace_reuses_the_copy`, `…_a_plain_image_path_hint_is_copied`, e2e `test_image_is_copied_once_for_its_replaces` (five replaces, one file) |
| 7 | The held reason is set once (focus → dnd keeps "focus") and never at a start with DND or Focus on | In part: the start case works (the handler runs for the first value, as in 1; `…_held_summary_when_focus_was_on_at_start` guards it). Focus → dnd: real | Each held record carries its reason; the summary names the reason that held most (`notifications.js heldReason`, ties: focus, dnd, fullscreen). · `tst_notifications::test_held_summary_follows_what_held_most` |
| 8 | `cancellable` matches "cancel" in any case, `cancel()` invokes exactly "cancel" | Real | Progress keeps the sender's own identifier (`cancelAction`) and invokes it. · `tst_notifications::test_progress_cancel_invokes_the_senders_own_action` |
| 9 | Brightness takes the first backlight (`ls \| head -n1`) | Rejected (main session; phase-7 review #30): since Linux 6.1 one backlight per panel, this machine has `intel_backlight` only | none |
| 10 | Literals: WorkspacePill `"transparent"`, MediaCard `interval: 1000` | Pill: real. MediaCard: stays (phase-7 review #25: a poll period, not a design duration) | The pill uses `Tokens.alpha(Tokens.accent, 0)`. · `tests/unit/test_s3_literals.py` (no colour literal in bar, notch or frame) |
| 07 | `Brightness` missing from 07 §3 step 3 | Real | Shared commit `86a0f6f`: step 3 lists it, with its reason (the backlight scan runs at start, so the first brightness key finds the device). · none (text) |
| A | `test_pinned_card_ways_out` fails after `test_fullscreen_leave_and_critical_above` | Shell wrong: `held` counted a held notification its sender had closed, so leaving fullscreen posted a stale "held" summary. That toast covered the next test's pinned card, which then has no keyboard (rules.js `keyboard`, by design), so Esc went to the window | `held` follows the history (`_heldIds`: a record that leaves the history leaves the count). The fullscreen test asserts no summary after leaving and ends drained; the pinned-card test starts drained. New: a pinned card while a toast arrives, then Esc (nothing closes while the toast is on top; Esc closes the card once it is gone). · `tst_notifications::test_a_held_notification_closed_by_its_sender_is_not_summarised`, e2e `test_held_then_closed_by_its_sender_is_not_summarised`, `test_pinned_card_under_a_toast_then_escape` |
| B | `test_hover_card_opens_and_collapses` fails | A consequence of A (the stale toast) | Passes in the full run below. |
| C | `WARN quickshell.service.sni.item: Unable to create pixmap for tray icon` | The fake item's fault: in `NeedsAttention` it had neither an attention icon nor a pixmap | `fake_sni.py` gives `IconPixmap`, `AttentionIconName` and `AttentionIconPixmap` (no whitelist). · `test_s3_zlog.py::test_shell_log_has_no_warnings` |

**E2e cases of phase 7's finding 31**, all run in the nested Hyprland:
`test_progress_activity_from_a_value_hint`, `test_urgent_toast_and_its_repeat` (an X11 kitty
rings its bell: Hyprland reports a Wayland kitty's or foot's bell in the nested session not as
`urgent`), `test_layout_osd_on_the_first_switch_after_the_start`, `test_battery_toasts` (the Power
service reads a battery double under `APTUS_TEST`, `fakehw.py battery`, never UPower),
`test_countdown_restarts_on_replace_and_stack_join`, the burst test now asserts count and apps,
`test_fixed_workspaces_split_one_to_five_and_six_to_ten` (a headless output named eDP-1),
`test_toast_close_button_middle_click_and_menu`, `test_tray_overflow`,
`test_wheel_on_the_strip_steps_through_used_workspaces`. Quiet bar (M-31b) stays with S8.
Helpers: `s3bus.py` (`wheel`, `setting` with `shell reloadConfig`, `passive`, `drained`,
`Window.to_workspace`, `BellWindow`), `fakehw.py battery`. Shared commits: `db3dddc` Ipc.qml
(progress items and the stack in `shell state`), `5253666` vpointer.py (middle button, wheel),
`b638c75` tests/e2e/hyprland.lua (layouts `de,us`: setting them at runtime emits `activelayout`,
which would fill the layouts before the test).

**Seen on the way, not fixed here** (S1's Config, outside this review): Config does not notice a
`settings.json` created after the shell started, nor any later write to it (probe in the nested
session: a plain write, a modify and an atomic replace all went unseen; apparently `FileView`
sets no watch on a file missing at start). The e2e helper `setting` therefore calls
`shell reloadConfig`. A hand-made `settings.json` on a fresh install needs a shell restart or
`aptus msg shell reloadConfig`.

**Checked.**
- `tests/run`: 348 unit tests (1 new: `test_s3_literals`), 281 QML tests (18 new: `tst_osd` 3,
  `tst_workspacestrip` 2, `tst_notifications` 9, `tst_hyprlayouts` 3, `tst_notifylogic` 1), qmllint
  147 files, 0 warnings.
- `pytest tests/e2e`: 62/62 in the nested Hyprland (12 new; A's two tests, B's hover card and C's
  log check pass). The first full run had 61/62: `test_shell_log_has_no_warnings` caught the
  toast's warning for the malformed URL (fixed in 4).
- Each fix has at least one test that failed against the file as it was before the fix; the others
  guard what already worked (`tst_osd` for a later device change and another kind, the start case
  of 7).
