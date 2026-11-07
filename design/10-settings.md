# 10 · Settings reference

Every setting aptus has. The schema (`shell/config/settings-schema.json`) is generated to match
this document, and a test fails if they differ ([07-architecture.md](07-architecture.md) §8).
`~/.config/aptus/settings.json` stores only values that differ from these defaults.

Types: `bool`, `int` (with range), `enum` (listed values), `string`, `path` (`~` allowed), `time`
(`HH:MM`), `list<…>`, `map<…>`. "Live" means the change applies within a frame; every setting is
live unless noted.

## Appearance

| Key | Type | Default | Values / range | Notes |
|---|---|---|---|---|
| `appearance.mode` | enum | `dark` | `dark`, `light`, `auto` | `auto`: Linen from sunrise to sunset ([08](08-theming.md) §3) |
| `appearance.accent` | enum | `jade` | `jade`, `apricot`, `sky`, `iris`, `rose`, `sand`, `wallpaper` | |
| `appearance.glass` | bool | `false` | | Hyprland reload for the layer rule |
| `appearance.textScale` | enum | `1.0` | `1.0`, `1.1`, `1.25` | scales type tokens; `bar.height` follows |
| `appearance.contrast` | enum | `normal` | `normal`, `high` | |
| `motion.reduce` | enum | `auto` | `auto`, `on`, `off` | `auto` reads `enable-animations` |
| `frame.edge` | enum | `6` | `0`, `6` | 0 hides the side and bottom edges; gaps follow |
| `bar.height` | derived | 32 | 32 / 35 / 40 | from `appearance.textScale`, not settable |

## Wallpaper

| Key | Type | Default | Values / range | Notes |
|---|---|---|---|---|
| `wallpaper.dir` | path | `~/Pictures/Wallpapers` | an existing folder | |
| `wallpaper.fill` | enum | `fill` | `fill`, `fit`, `center`, `tile` | |
| `wallpaper.focus` | enum | `center` | `center`, `top`, `bottom`, `left`, `right` | crop anchor for `fill` |
| `wallpaper.rotate` | enum | `off` | `off`, `30m`, `1h`, `3h`, `daily` | |
| `wallpaper.rotateFavourites` | bool | `false` | | rotate through favourites only |

The chosen images themselves are state (`wallpaper.json`), not settings.

## Bar and frame

| Key | Type | Default | Values / range | Notes |
|---|---|---|---|---|
| `bar.workspaces.show` | enum | `used` | `used`, `fixed` | |
| `bar.workspaces.icons` | bool | `true` | | app icons in pills |
| `bar.title.show` | bool | `true` | | active window title |
| `bar.clock.showDate` | bool | `true` | | `Sat 7 Nov` before the time |
| `bar.tray.max` | int | `3` | 0–6 | 0 = everything in the overflow |
| `bar.tray.hidden` | list<string> | `[]` | tray item ids | |
| `bar.tray.order` | list<string> | `[]` | tray item ids | the order shown (dragged in Settings); items not listed follow in registration order |
| `bar.tray.monitor` | enum | `primary` | `primary`, `all` | primary = the external monitor when one is connected, else eDP-1 |
| `bar.battery.percent` | enum | `auto` | `auto`, `always`, `never` | auto: ≤ 30 %, or charging |
| `bar.bluetooth` | enum | `connected` | `connected`, `always` | |
| `deck.tiles` | list<enum> | `["wifi", "bluetooth", "dark", "dnd", "nightlight", "awake", "focus", "power"]` | those 8 ids, any order, any subset, each at most once | |
| `deck.openPages` | bool | `false` | | clicking a status item opens its page directly |

## Notch and notifications

| Key | Type | Default | Values / range | Notes |
|---|---|---|---|---|
| `notifications.timeout` | enum/int | `auto` | `auto`, 3–30 (s) | auto = clamp(4 s + 40 ms × chars, 4–9 s) |
| `notifications.stackWindow` | int | `2` | 0–10 (s) | burst grouping window |
| `notifications.allowlist` | list<string> | `[]` | desktop ids | may interrupt DND and focus |
| `notifications.historyDays` | int | `7` | 1–30 | |
| `notifications.historyMax` | int | `200` | 50–1000 | |
| `notch.overFullscreen` | enum | `critical` | `critical`, `none`, `all` | |
| `notch.hoverExpand` | bool | `true` | | resting on a live activity expands its card |
| `media.ignore` | list<string> | `[]` | MPRIS identities | never the active player |
| `timers.sound` | bool | `true` | | chime when a timer or alarm ends |

## Spotlight

| Key | Type | Default | Values / range | Notes |
|---|---|---|---|---|
| `spotlight.superTap` | bool | `true` | | tap Super alone opens Spotlight (P-02) |
| `spotlight.superHoldKeys` | bool | `true` | | hold Super 1 s peeks at Keys |
| `spotlight.pinned` | list<string> | `[]` | desktop ids, ≤ 8 | empty = the 8 most-used apps by frecency |
| `spotlight.aliases` | map<string,string> | `{}` | alias → desktop id | e.g. `"tb": "thunderbird.desktop"` |
| `spotlight.searchEngine` | enum/string | `duckduckgo` | `duckduckgo`, `startpage`, `google`, `brave`, `kagi`, or a URL with `%s` | |
| `spotlight.webShortcuts` | map<string,string> | see below | keyword → URL with `%s` | |
| `spotlight.providers.<id>.enabled` | bool | `true` | ids: `apps`, `windows`, `actions`, `settings`, `calculator`, `files`, `clipboard`, `emoji`, `jot`, `timers`, `commands`, `workspaces`, `keys`, `web` | |
| `spotlight.providers.<id>.boost` | int | `0` | −2 … +2 | adds boost × 5 to the provider's `typeBias` ([spotlight.md](surfaces/spotlight.md) §6) |
| `spotlight.preview` | bool | `true` | | preview pane when the selection has one |
| `files.roots` | list<path> | `["~"]` | | |
| `files.exclude` | list<string> | `["~/.cache", "~/.local/share/Trash", "~/.var", "~/.steam", "node_modules", ".git"]` | paths or folder names | |
| `files.showHidden` | bool | `false` | | |
| `clipboard.maxItems` | int | `500` | 50–5000 | |
| `clipboard.ignoreClasses` | list<string> | `["org.keepassxc.KeePassXC", "Bitwarden"]` | window classes | never stored |
| `clipboard.terminalClasses` | list<string> | `["kitty", "com.mitchellh.ghostty", "foot", "Alacritty", "aptus.scratch"]` | window classes | paste with `Ctrl+Shift+V` |
| `apps.launchInScopes` | bool | `true` | | `systemd-run --scope` per launched app |
| `switcher.scope` | enum | `monitor` | `monitor`, `all` | |

Default web shortcuts: `gh` GitHub search, `yt` YouTube, `w` Wikipedia (en), `wd` Wikipedia (de),
`aw` ArchWiki, `fp` Fedora packages, `mdn` MDN, `osm` OpenStreetMap, `ddg` DuckDuckGo.

## Today and calendar

| Key | Type | Default | Values / range | Notes |
|---|---|---|---|---|
| `today.weekNumbers` | bool | `true` | | |
| `calendar.remindBefore` | int | `10` | 0–60 (min) | 0 = only at start |
| `calendar.refreshMinutes` | int | `10` | 5–120 | |
| `weather.location` | object/null | `{ "name": "Berlin, Germany", "lat": 52.52, "lon": 13.405 }` | an object of that shape, or `null` | set by search (D-21); `null` = no weather, sun times 07:00/19:00 |
| `weather.units` | enum | `metric` | `metric`, `imperial` | |
| `jot.file` | path | `~/Notes/inbox.md` | | created when missing |
| `jot.attachmentsDir` | string | `attachments` | relative to the jot file's folder | |
| `jot.dateHeadings` | bool | `true` | | `## Sat 7 Nov 2026` headings |

Calendar sources live in `~/.config/aptus/calendars.json` (0600), edited in the settings window.

## Focus and do not disturb

| Key | Type | Default | Values / range | Notes |
|---|---|---|---|---|
| `focus.durations` | list<int> | `[25, 50, 90]` | three values, 5–240 | the picker's segments |
| `focus.default` | int | `50` | one of `focus.durations` | |
| `focus.breakMinutes` | int | `10` | 1–60 | |
| `focus.autoBreak` | bool | `false` | | start the break without asking |
| `focus.sound` | bool | `true` | | chime at the end |
| `focus.dailyGoal` | int | `240` | 0–720 (min) | 0 hides the goal ring |
| `focus.endForMeetings` | bool | `false` | | |
| `focus.quietBar` | bool | `true` | | quiet bar while focusing |
| `dnd.schedule` | object/null | `null` | `{ "from": "22:00", "to": "07:00", "days": [1,2,3,4,5,6,7] }` | days 1–7 (Monday = 1), each at most once |

## Capture

| Key | Type | Default | Values / range | Notes |
|---|---|---|---|---|
| `capture.dir` | path | `~/Pictures/Screenshots` | | created when missing |
| `capture.recordDir` | path | `~/Videos/Recordings` | | created when missing |
| `capture.fileName` | string | `Screenshot %Y-%m-%d %H-%M-%S` | strftime pattern | recordings use `Recording …` |
| `capture.copy` | bool | `true` | | copy screenshots to the clipboard |
| `capture.countdown` | bool | `false` | | 3-2-1 before recording |
| `capture.recordAudio` | enum | `none` | `none`, `system`, `mic`, `both` | |
| `capture.colourFormat` | enum | `hex` | `hex`, `rgb`, `hsl`, `oklch` | |
| `capture.includeShell` | bool | `false` | | keep open shell surfaces in screenshots |

## Sound and display

| Key | Type | Default | Values / range | Notes |
|---|---|---|---|---|
| `audio.step` | int | `5` | 1–10 (%) | `Shift` = 1 % |
| `audio.allowBoost` | bool | `false` | | volume up to 150 % |
| `brightness.step` | int | `5` | 1–10 (%) | never below 1 % |
| `nightLight.schedule` | enum | `off` | `off`, `sunset`, `custom` | needs `hyprsunset` |
| `nightLight.temperature` | int | `4000` | 2500–6000 (K) | |
| `nightLight.from` | time | `20:00` | | for `custom` |
| `nightLight.to` | time | `07:00` | | for `custom` |

## Power and session

| Key | Type | Default | Values / range | Notes |
|---|---|---|---|---|
| `idle.dimAfter` | int | `270` | 0 (never), 30–3600 (s) | must be < `idle.lockAfter` |
| `idle.lockAfter` | int | `300` | 0 (never), 60–7200 (s) | |
| `idle.screenOffAfter` | int | `600` | 0 (never), 60–7200 (s) | |
| `idle.lockedScreenOffAfter` | int | `60` | 10–600 (s) | |
| `power.lidAction` | enum | `lock` | `lock`, `suspend` | D-01 |
| `power.lidDocked` | enum | `disable-internal` | `disable-internal`, `keep-on` | applies with `power.lidAction = lock` and an external monitor connected |
| `power.allowSuspend` | bool | `false` | | shows Suspend in the sheet and Spotlight |
| `session.closeTimeout` | int | `6` | 2–30 (s) | graceful logout |
| `lock.showNotificationCount` | bool | `true` | | counts only, never content |
| `lock.showMedia` | bool | `true` | | |
| `lock.fingerprint` | bool | `false` | | needs an enrolled finger (P-22) |

## Apps and isolation

| Key | Type | Default | Values / range | Notes |
|---|---|---|---|---|
| `isolation.bakeTargets` | list<enum> | `[]` | `spicetify`, `libreoffice` | opt-in; changes those apps in Umbriel too until switched back ([02](02-isolation.md) §4) |

Validation rules beyond types: `idle.dimAfter < idle.lockAfter ≤ idle.screenOffAfter` (when
non-zero); `focus.default ∈ focus.durations`; paths (also every entry of a `list<path>`) must be inside `$HOME`. A violation falls back
to the default for the offending key and says so once. In `settings-schema.json` these are the
`rules` of kind `order`, `member` and `insideHome`. A key that is not settable (`derived`, such as
`bar.height`) is ignored in the file with a problem line. `Config.set` refuses a value that breaks a
rule and returns the message. `mustExist` (`wallpaper.dir`) is not checked when loading (QML has no
synchronous file check); the settings window's folder picker checks it.
