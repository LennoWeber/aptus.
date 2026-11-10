# 08 · Theming pipeline

## 1. Overview

```
 theme/tokens.json ─┐
 settings (mode,    ├─► resolve ──► resolved palette ──┬─► Tokens (QML)  ── crossfade M-30 (400 ms)
 accent, glass,     │   (§3)        (one JSON object)  │
 contrast)          │                                  └─► aptus-theme render (§4)
 wallpaper hue ─────┘                                         │ gen-<n>/ (every target's file)
                                                              ▼
                                                     aptus-theme apply (§6)
                                     ┌────────────────────┼─────────────────────┐
                               Lease targets         Scope targets          Own targets
                           (aptus-lease update)   (scope/ mirrors, env)   (aptus-icons, qt6ct,
                                     └────────────────────┼──────────────────── hypr generated.lua)
                                                          ▼
                                                   reload hooks (§7)
```

The shell recolours itself first (instantly, from the same resolution in QML); apps follow in the
background a moment later. Nothing waits for apps.

## 2. Inputs

| Input | From |
|---|---|
| Palettes, accents, washes, signal colours | `theme/tokens.json` ([03](03-visual-language.md) §2) |
| `appearance.mode` (`dark` / `light` / `auto`) | settings |
| `appearance.accent` (six names or `wallpaper`) | settings; the wallpaper hue from `Wallpaper` |
| `appearance.glass`, `appearance.contrast` | settings |
| Sun times for `auto` | computed from `weather.location` (NOAA algorithm, no network); without a location: 07:00 / 19:00 |

## 3. Resolution

Deterministic and identical in Python (`lib/aptus/theme/resolve.py`) and QML (`core/Tokens.qml`); a
test resolves every combination (2 modes × 6 accents × 2 contrasts × glass on/off) in both and
requires identical JSON.

1. **Mode:** explicit, or for `auto` Linen between sunrise and sunset, Ember otherwise. The next
   change is scheduled at the exact time.
2. **Accent:** the named one, or for `wallpaper` the nearest hue among the six (circular distance in
   OKLCH hue); ties go to the current accent.
3. **Base roles** from the palette of the mode (ground, raised, raisedHot, sunken, line, inks,
   warn, crit, onAccent, scrim, shadow).
4. **Contrast high:** `ink.sec` and `ink.meta` move 35 % of the way to `ink.main` in OKLab.
5. **Glass:** `groundAlpha` = 0.86 (0.92 when the wallpaper's mean lightness is in the wrong half
   for the mode); solid: 1.
6. **Derived roles** (all in OKLab, then rounded to 8-bit sRGB):

| Role | Rule |
|---|---|
| `wash.hover/current/currentHover/pressed` | `ink.main` over `ground` at 6 / 10 / 14 / 18 % |
| `accentWash` | accent over ground at 16 % |
| `selection.bg` | accent over ground at 28 % (Ember) / 22 % (Linen); `selection.fg` = `ink.main` |
| `border.active` | accent; `border.inactive` = `line` |
| `link` | accent |
| `ansi[0..15]` | table below |

### Terminal colours (ANSI 16)

Text colours measured against the terminal background (`ground`), APCA Lc. `0`/`8` are the
"black" pair, used mostly as backgrounds and for faint text.

| # | Name | Ember | Lc | Linen | Lc |
|---|---|---|---|---|---|
| 0 | black | `#2c2722` | — | `#3a3229` | 88 |
| 1 | red | `#fa9d86` (= crit) | 62 | `#b03522` (= crit) | 70 |
| 2 | green | `#9acfae` (= jade) | 69 | `#25704f` | 69 |
| 3 | yellow | `#ecbf68` (= warn) | 71 | `#875400` (= warn) | 71 |
| 4 | blue | `#94c3dc` (= sky) | 66 | `#1f5f86` | 73 |
| 5 | magenta | `#b9aeea` (= iris) | 62 | `#5546a8` | 75 |
| 6 | cyan | `#8ccfc8` | 69 | `#1b6a69` | 71 |
| 7 | white | `#d3c8b3` (= ink.sec) | 73 | `#8a7e70` | 57 |
| 8 | bright black | `#948a7d` | 39 | `#685d4f` (= ink.meta) | 72 |
| 9 | bright red | `#ffb8a6` | 73 | `#c4452c` | 63 |
| 10 | bright green | `#b6e2c5` | 82 | `#2c7f5b` | 63 |
| 11 | bright yellow | `#f6d593` | 83 | `#9a6206` | 65 |
| 12 | bright blue | `#b3d8ec` | 79 | `#2a6f99` | 67 |
| 13 | bright magenta | `#d2cbf5` | 77 | `#6557b8` | 69 |
| 14 | bright cyan | `#ace2dc` | 82 | `#237a78` | 65 |
| 15 | bright white | `#efe6d4` (= ink.main) | 91 | `#a0948a` | 46 |

Terminal background `ground`, foreground `ink.main`, cursor accent, cursor text `onAccent`.
ANSI colours do not change with the accent (so `ls` and `git diff` stay familiar); only cursor,
selection and the prompt's accent segments do.

The result is one JSON object, `resolved.json`, written into every generation.

## 4. The renderer

`aptus-theme render` (Python, stdlib only):

- **Input hash:** SHA-256 over the template context (without the generation number), the
  inputs, the manifest, and every template file. Equal to the current generation's hash →
  nothing to do (10 ms).
- **Output:** `~/.local/state/aptus/theme/gen-<n>/` containing each target's rendered file(s)
  (dconf targets: `<id>/dconf.json`, key → value) and `resolved.json`; then the symlink `current`
  is swapped atomically to it and `theme/resolved.json` (a stable file the shell watches) is
  rewritten. Every target except `never` is rendered whatever its `when` says (installing an
  app needs no new generation). A target that fails keeps the previous generation's output.
  The last three generations are kept. Render, apply and the guard's bake retry serialise on
  `theme/lock` (flock, re-entrant per thread); the lease's own flock is always taken inside it,
  never the other way round.
- **Template language** (deliberately tiny, no logic): `{{ role }}` or `{{ role | filter }}`.

| Filter | Output for `#9acfae` |
|---|---|
| (none), `hex` | `#9acfae` |
| `hexnoh` | `9acfae` |
| `rgb` | `154, 207, 174` |
| `rgba(0.86)` | `rgba(154, 207, 174, 0.86)` |
| `hyprrgba(0.86)` | `rgba(9acfaedb)` |
| `argb(0.86)` | `#db9acfae` (Qt) |
| `hsl` | `hsl(142, 37%, 71%)` |
| `int` | `10145710` (decimal, for KDE/VS Code where needed) |
| `csv` | `154,207,174` (KDE) |
| `hue`, `saturation`, `lightness` | `142`, `37`, `71` (HSL parts, rounded half up) |

Plus `{{ mode }}` (`dark`/`light`), `dark.<role>` / `light.<role>` (both palettes), `ansi0`…`ansi15`,
`{{ accent.name }}`, `{{ papirus.folder }}`, `{{ gnome.accent }}`, `{{ font.ui }}`, `{{ font.mono }}`,
`font.<uiApp|documentApp|monoApp>[.family|.size]`, `cursor.theme`, `cursor.size`, `frame.edge`,
`window.gap`, `glass` and `reduce_motion` (Lua booleans), `generation`, `dir.*`. An unknown role
or filter is a render error for that target only.

## 5. The target manifest

`theme/targets.toml`: one entry per target. Adding an app is adding an entry and a template.

```toml
[[target]]
id        = "ghostty"
row       = 7                            # row in 02-isolation §4
noctalia  = ["ghostty"]                  # Noctalia template ids this covers (coverage rule)
template  = "ghostty/theme"
out       = "ghostty/noctalia"           # path inside the generation
mechanism = "lease"                      # lease | scope | own | bake | never
slot      = "~/.config/ghostty/themes/noctalia"
when      = "exists:~/.config/ghostty"   # skip when the app's config dir is absent
reload    = "signal:ghostty:SIGUSR2"

[[target]]
id        = "kitty"
row       = 6
noctalia  = ["kitty"]
template  = "kitty/theme.conf"
out       = "kitty/noctalia.conf"
mechanism = "scope"
files     = [{ template = "kitty/theme.conf", out = "kitty/noctalia.conf", at = "themes/noctalia.conf" }]
scope     = { into = "kitty", mirror = "{config}/kitty" }   # scope/kitty: symlinks, except `at`
reload    = "signal:kitty:SIGUSR1"
```

The full field list is the header of `theme/targets.toml` (`files` with `name`/`slot`/`dest`/`at`,
`kind`, `sections`, `dconf`, `requires`, `present`, `[inert]`). Slot names must differ within a
target (the slot id is `<id>.<name>`); `load` refuses a manifest where they do not.

`reload` kinds: `none`, `signal:<comm>:<SIG>` (only processes whose environment carries this
Hyprland's `HYPRLAND_INSTANCE_SIGNATURE`), `exec:<command>`, `builtin:<name>` (Python functions for
the cases below), `bake:<process>:<command>`.

Targets, by id (rows of [02-isolation.md](02-isolation.md) §4): `gtk3`, `gtk4`, `dconf`, `kde`,
`qt6ct`, `kitty`, `ghostty`, `foot`, `alacritty`, `btop`, `cava`, `fuzzel`, `tmux`, `starship`,
`fastfetch`, `nvim`, `nvim-matugen`, `zen-chrome`, `pywalfox`, `thunderbird`, `vesktop`,
`claude-code`, `gemini`, `vscode`, `steam`, `brave`, `hyprtoolkit`, `icons`, `cursor`, `spicetify`,
`libreoffice`, `yazi`, `bat`, `hyprland`, `hyprlock`. (`umbriel` has no entry: it is never touched.)

## 6. Apply

`aptus-theme apply` = render, then, under `theme/lock`:

1. **Lease targets:** the lease's update (in-process, `aptus.lease.ops.update`, under the lease
   flock) writes each rendered file into its slot (or each dconf key / INI section) and updates
   `after` hashes, only while this session holds the lease. In scope-only mode this step is
   skipped and the report lists the targets that stay Noctalia's.
2. **Scope targets:** rebuild the mirror directories (`scope/kitty`, `scope/yazi`) and generated
   files (`scope/starship.toml`), atomically.
3. **Own targets:** `aptus-icons-{dark,light}` (only on accent change), `~/.config/qt6ct/`,
   `~/.local/state/aptus/hypr/generated.lua`, `~/.local/state/aptus/hyprlock.conf`,
   `~/.cache/aptus/bat`.
4. **Reload hooks** (§7), in parallel, each with a 3 s timeout. A bake whose app runs is written
   to `<runtime>/bake-queue.json`; the guard retries it every 30 s.
5. Report: a JSON summary on stdout (`applied`, `next-start`, `failed` per target); the shell
   shows a toast only for failures.

Triggered by: session start (render + take), any change of mode/accent/glass/contrast (debounced
250 ms, after the shell's own crossfade ends), `auto` transitions, and `aptus theme apply`.

## 7. Reload hooks

| Target | Hook | Effect |
|---|---|---|
| GTK 3 / 4 | none (probe P-05: a running GTK 3 app does not re-read user CSS, and `gtk-theme` is never written) | new windows; libadwaita light/dark is live through `color-scheme` |
| dconf keys | written by the lease | live via GSettings and the settings portal |
| KDE / Qt (kdeglobals) | `dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:0 int32:0` | running KDE apps repaint |
| qt6ct | none | next app start |
| kitty | `SIGUSR1` to this session's kitty processes | live |
| Ghostty | `SIGUSR2` (P-07) | live |
| Alacritty | none (it watches imports) | live |
| foot, btop, cava, fuzzel, fastfetch, yazi, bat | none | next start or run |
| tmux | `tmux -S <socket> source-file ~/.config/tmux/tmux.conf` for every server socket in `/tmp/tmux-$UID/` | live |
| Starship | none (re-reads per prompt) | next prompt |
| Neovim | for each socket `$XDG_RUNTIME_DIR/nvim.*`: `nvim --server <s> --remote-send '<Cmd>colorscheme noctalia<CR>'` | live |
| Zen | none | next start (userChrome loads once) |
| Pywalfox | `pywalfox update` if installed | live web content |
| Vesktop | none (watches CSS) | live |
| Hyprland | `hyprctl eval` of a Lua chunk that `dofile`s `generated.lua` and sets `general.col.active_border`, `inactive_border`, `gaps_out`, `decoration.shadow.color`, `misc.background_color` (`builtin:hyprland`; verified nested) | live |
| hyprlock, Thunderbird, Claude Code, Gemini, VS Code, Steam, Brave, hyprtoolkit | none | next start |
| Spotify, LibreOffice (bake, opt-in) | `spicetify apply` / registry merge, only when the app is not running; otherwise queued until it exits (checked every 30 s, given up at session end) | next start |

Release ([02](02-isolation.md) §5.6) runs the same hooks after restoring, so running processes
switch back to Noctalia's paint.

## 8. Own themes

### Icon theme
`~/.local/share/icons/aptus-icons-dark/` and `aptus-icons-light/`: `index.theme` with
`Inherits=Papirus-Dark,hicolor` (resp. `Papirus-Light`), and only `places/{16,22,24,32,48,64}`
directories whose `folder*.svg` entries are symlinks to the Papirus folder colour of the accent
(`folder-teal.svg` → `folder.svg`, and the same for `folder-documents`, `-download`, …). Regenerated
on accent change (≈ 400 symlinks, 50 ms), built in `aptus-icons-<mode>.new` and renamed over the
old one (via `.old`). `icon-theme` (leased dconf key) selects it. Papirus itself is never
modified.

Every Own file outside aptus's state and cache directories is recorded in `theme/own.json`
(`{"v": 1, "created": [paths]}`) **before** it is created, so uninstall (02 §11) knows what is
aptus's even after a crash; a file that existed before aptus is never claimed.

### Qt without KDE (qt6ct)
`~/.config/qt6ct/qt6ct.conf`: `style=Fusion`, `color_scheme_path=~/.config/qt6ct/colors/aptus.conf`,
`custom_palette=true`, `icon_theme=aptus-icons-<mode>`, fonts Inter 11 / JetBrains Mono 11.
Only read when `QT_QPA_PLATFORMTHEME=qt6ct`, which only Hyprland sets.

### Fonts and cursor (leased dconf keys)
`font-name 'Inter 11'`, `document-font-name 'Inter 11'`, `monospace-font-name 'JetBrains Mono 11'`,
`cursor-theme 'Adwaita'`, `cursor-size 24`, `accent-color` = the nearest GNOME accent name
(`teal`, `orange`, `blue`, `purple`, `pink`, `yellow`).

### Hyprland
`~/.local/state/aptus/hypr/generated.lua` (loaded by the aptus block): border colours, background
colour, shadow colour, group colours, `gaps_out` from `frame.edge`, and the reduced-motion
animation overrides when active.

## 9. Failure handling

- A template error or a failed write affects only that target; the previous generation's output
  stays in place.
- A hook that times out is logged; the target is reported as "next start".
- A target whose app is not installed (`when` false) is skipped silently and listed as "Not
  installed" on the settings page.
- If the renderer itself fails at session start, the shell still starts with its own palette;
  apps keep Noctalia's paint (no lease is taken without rendered content).
