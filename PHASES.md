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
