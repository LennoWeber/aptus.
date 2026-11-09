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
