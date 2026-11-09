# 02 · Session isolation

> Umbriel stays exactly as it is. Hyprland looks like aptus. Switching between them, in either
> direction and after any kind of crash, always gives the session its own look.

This is the contract every other part of aptus obeys. When a feature and this document disagree,
this document wins and the feature changes.

## 1. The promise, as invariants

| ID | Invariant |
|---|---|
| **I-1** | aptus never edits Umbriel's configuration (`~/.config/umbriel`, i.e. `~/dotfiles/umbriel`), Noctalia's settings (`~/.local/state/noctalia`, `~/.config/noctalia`), the greeter (`/etc/greetd`, `/var/lib/noctalia-greeter`) or any system file. |
| **I-2** | Whenever **no** Hyprland session of this user is running, every file and dconf key that Noctalia themes holds **exactly** (byte-for-byte, same mode) what Noctalia last wrote there. |
| **I-3** | While a Hyprland session runs, the apps in it are painted with aptus's palette. |
| **I-4** | Nothing aptus starts survives the end of the Hyprland session, except the one recovery unit (§7), which can only *restore* Noctalia's state. |
| **I-5** | aptus never installs anything that changes what Noctalia's own hooks do (see §9, side channels). |
| **I-6** | Every violation is detectable: `aptus doctor isolation` reports the exact file, key or process. |

What is deliberately **not** isolated, because it is the machine's state rather than a session's
configuration: volume and default devices, screen brightness, Wi-Fi networks and saved passwords,
Bluetooth pairings, the power profile (tuned-ppd), battery state, the keyring, files in `~`.
aptus changes these only when Lenno asks it to, exactly as Noctalia would.

## 2. What the two sessions share

Both sessions run as the same user on the same home directory. These are the channels through which
one session could reach the other:

| Shared thing | Why it matters | How aptus handles it |
|---|---|---|
| Files under `~/.config`, `~/.cache`, `~/.local` | Apps read the same theme files in both sessions | Own, Scope, Lease (§3) |
| dconf user database (`~/.config/dconf/user`) | `color-scheme`, `icon-theme`, fonts, cursor are read by GTK and the settings portal in both sessions | Lease of a fixed key set (§5) |
| systemd user manager and its environment | It can outlive a session (`UserStopDelaySec`, default 10 s). Variables imported into it reach D-Bus-activated apps and portals of the *next* session | Import as little as possible; unset on release (§6) |
| D-Bus activation environment (dbus-broker) | Uses the systemd user environment | Same as above |
| xdg-desktop-portal processes | May keep running from one session into the next if the user manager persists | They read dconf live; the lease release restores the values, and the portal emits the change |
| `~/dotfiles` git repository | Several Noctalia artifacts are tracked in it (kitty theme, `hyprtoolkit.conf`, fastfetch theme, `nvim/lua/matugen.lua`) | Prefer Scope for tracked files; for leased tracked files see D-03 in [12-decisions.md](12-decisions.md) |
| Long-lived processes (tmux server, Zen, Spotify) | They can survive a logout and be reused in the other session | Every reload hook runs again after release (§5.6) |
| XDG autostart (`~/.config/autostart`) | Umbriel runs XDG autostart entries | aptus never creates autostart entries |
| User systemd units (`~/.config/systemd/user`) | Enabled units start in every session | Only `aptus-recover.service` is installed; everything else is a transient unit bound to the Hyprland session |
| User fonts (`~/.local/share/fonts`) | Visible to every app in both sessions | aptus never installs fonts; its icon font is loaded from the repo by QML |
| Packages | Noctalia's GTK hook switches to `adw-gtk3-dark` if that theme exists | aptus never installs `adw-gtk3` (see §9) |
| The greeter | Shown before either session | Never touched; stays Noctalia's |

## 3. Mechanisms

aptus reaches an app's look through exactly one of five mechanisms. They are listed from safest to
most delicate; aptus always uses the safest one that works for a target.

### Own
A file only aptus reads, under aptus's own paths (`~/.local/state/aptus`, `~/.config/aptus`,
`~/.cache/aptus`), or a file in a shared directory that is provably **inert** outside Hyprland
(nothing in Umbriel loads it). Zero effect on Umbriel.

### Scope
An environment variable or command-line flag that points an app at an Own file, set **only** in the
Hyprland session (`hl.env` in `hyprland.lua`). Processes started by Umbriel never see it.

### Lease (the principle: *swap the paint, not the wiring*)
Noctalia has already wired every app it themes to read one generated file (its "artifact"): kitty
includes `themes/noctalia.conf`, GTK imports `noctalia.css`, Zen imports
`~/.cache/noctalia/zen-browser/zen-userChrome.css`, and so on. aptus does **not** touch that wiring.
For the duration of the Hyprland session it swaps the *content* of Noctalia's artifact for aptus's
paint, and puts Noctalia's content back when the session ends. The wiring stays Noctalia's, so
nothing in Umbriel's setup ever changes shape.

A lease is journaled before anything is written, released by an out-of-process guard when Hyprland
exits for any reason, and recovered at the next login if even the guard could not run (§5, §7).

### Bake (opt-in, default off)
A few apps compile their theme into their own installation (Spicetify patches Spotify's files;
LibreOffice merges colours into its profile registry). Swapping a source file does nothing until a
slow re-bake runs, and the baked result would survive into Umbriel. These stay Noctalia-coloured in
Hyprland by default. With `isolation.bakeTargets` enabled, aptus re-bakes at lease take and again at
release (only while the app is closed). See D-02.

### Never
Umbriel's own files, the greeter, system files. aptus does not read-modify-write them under any
setting.

## 4. Target table

Every app Noctalia themes today (from `~/.local/state/noctalia/settings.toml`, `[theme.templates]`),
plus the shared GNOME and KDE settings, plus apps aptus themes that Noctalia does not. "Tracked"
means the file is tracked in `~/dotfiles`.

| # | Target | Noctalia's artifact (paint) | Noctalia's wiring (never touched) | aptus mechanism | How it refreshes in Hyprland |
|---|---|---|---|---|---|
| 1 | GTK 3 apps (Nemo, Thunar, …) | `~/.config/gtk-3.0/noctalia.css` | `gtk-3.0/gtk.css` (`@import`, Thunar rules) | **Lease** file | new windows (probe P-05: running GTK 3 apps keep their CSS; `gtk-theme` is never written) |
| 2 | GTK 4 / libadwaita apps | `~/.config/gtk-4.0/noctalia.css` | `gtk-4.0/gtk.css` | **Lease** file | as above; light/dark is live via the portal |
| 3 | GNOME interface keys | dconf `color-scheme` (Noctalia sync), `icon-theme` (Papirus hook) | — | **Lease** dconf keys (§5.5) | live (GSettings + portal signals) |
| 4 | KDE / Qt colour scheme (Dolphin, Okular, KDE dialogs) | `[Colors:*]`, `[ColorEffects:*]`, `[WM]` in `~/.config/kdeglobals`; `~/.local/share/color-schemes/noctalia.colors` | `[General] ColorScheme` | **Lease** INI sections of `kdeglobals` (`noctalia.colors` untouched) | running KDE apps via the `org.kde.KGlobalSettings.notifyChange` D-Bus signal |
| 5 | Qt 6 apps without KDE (qt6ct) | `qt6ct/colors/noctalia.conf` — inert today: Umbriel does not load qt6ct | none | **Scope** `QT_QPA_PLATFORMTHEME=qt6ct` + **Own** `~/.config/qt6ct/qt6ct.conf` (inert outside Hyprland; doctor checks Umbriel never sets the variable) | app restart |
| 6 | kitty | `~/.config/kitty/themes/noctalia.conf` (tracked) | `kitty.conf` `include themes/noctalia.conf` | **Scope** `KITTY_CONFIG_DIRECTORY=~/.local/state/aptus/scope/kitty`: a mirror of `~/.config/kitty` whose entries are symlinks, except `themes/noctalia.conf`, which points at aptus's kitty colours (probe P-06) | `SIGUSR1` to kitty processes of this session |
| 7 | Ghostty | `~/.config/ghostty/themes/noctalia` | `config.ghostty` `theme = noctalia` | **Lease** file | `SIGUSR2` (Ghostty ≥ 1.2 reloads config; probe P-07) |
| 8 | foot | `~/.config/foot/themes/noctalia` | `foot.ini` include | **Lease** file | new windows |
| 9 | Alacritty | `~/.config/alacritty/themes/noctalia.toml` | `alacritty.toml` import | **Lease** file | live (Alacritty watches imports) |
| 10 | btop | `~/.config/btop/themes/noctalia.theme` | `btop.conf` `color_theme` | **Lease** file | next start |
| 11 | cava | `~/.config/cava/themes/noctalia` | cava config | **Lease** file | next start |
| 12 | fuzzel | `~/.config/fuzzel/themes/noctalia` | fuzzel.ini include | **Lease** file | next start |
| 13 | tmux | `~/.config/tmux/themes/noctalia.conf` | `tmux.conf` source | **Lease** file | `tmux source-file` on every running server |
| 14 | Starship prompt | `~/.cache/noctalia/starship-palette.toml`, injected between `# >>> NOCTALIA STARSHIP PALETTE >>>` markers into the starship config | `starship.toml` | **Scope** `STARSHIP_CONFIG=~/.local/state/aptus/scope/starship.toml`, generated from the user's `starship.toml` with the Noctalia block replaced by aptus's palette | next prompt |
| 15 | fastfetch | `~/.config/fastfetch/themes/noctalia.jsonc` (tracked) | fastfetch config | **Lease** file | next run |
| 16 | Neovim (LazyVim colours) | `~/.config/nvim/colors/noctalia.lua` | `colorscheme noctalia` | **Lease** file | `:colorscheme noctalia` sent to every running nvim server socket |
| 17 | Neovim (matugen module) | `~/.config/nvim/lua/matugen.lua` (tracked) | `plugins/noctalia.lua` | **Lease** file | same |
| 18 | Zen browser | `~/.cache/noctalia/zen-browser/zen-userChrome.css`, `zen-userContent.css` | `@import` lines in the profile's `chrome/userChrome.css`, `userContent.css` | **Lease** files | next Zen start (userChrome loads once) |
| 19 | Pywalfox (Zen web content) | `~/.cache/wal/colors.json` | the extension | **Lease** file | `pywalfox update` if installed |
| 20 | Thunderbird | `~/.cache/noctalia/thunderbird/noctalia.css` | profile chrome import | **Lease** file | next start |
| 21 | Vesktop / Discord | `~/.config/vesktop/themes/noctalia*.css` (+ Flatpak path) | Vesktop theme setting | **Lease** files, only if present | live (Vesktop watches CSS) |
| 22 | Claude Code | `~/.claude/themes/noctalia.json` | Claude Code theme setting | **Lease** file | next start |
| 23 | Gemini / Antigravity CLI | `~/.gemini/config/theme.json` | — | **Lease** file | next start |
| 24 | VS Code / Antigravity IDE | extension theme JSON under `~/.vscode/extensions/noctalia.*`, `~/.antigravity-ide/extensions/noctalia.*` | selected colour theme | **Lease** files, only if present | window reload |
| 25 | Steam | `~/.steam/steam/steamui/skins/Material-Theme/css/main/colors/matugen.css` | skin selection | **Lease** file, only if present | Steam restart |
| 26 | Brave | `~/.cache/noctalia/brave-theme/manifest.json` | loaded extension | **Lease** file, only if present | Brave restart |
| 27 | hyprtoolkit apps | `~/.config/hypr/hyprtoolkit.conf` (tracked) | read by hyprtoolkit | **Lease** file | next start |
| 28 | Icon theme (Papirus folders) | folder colours recoloured inside `~/.local/share/icons/Papirus*`; `icon-theme` key | — | **Own** icon theme `aptus-icons-{dark,light}` in `~/.local/share/icons` (inherits Papirus, its own folder icons are symlinks to the Papirus folder colour nearest the accent), selected through the leased `icon-theme` key; Noctalia's recoloured Papirus copies are never touched | new windows |
| 29 | Cursor | dconf `cursor-theme`/`cursor-size` (unchanged by Noctalia today) | — | **Lease** keys + **Scope** `XCURSOR_THEME`, `XCURSOR_SIZE`, `HYPRCURSOR_SIZE` | new windows |
| 30 | Spotify (Spicetify) | `~/.config/spicetify/Themes/{Comfy,Colorful}/color.ini` | baked into Spotify by `spicetify apply` | **Bake**, opt-in (default: stays Noctalia's) | `spicetify apply` while Spotify is closed |
| 31 | LibreOffice | `~/.local/state/noctalia/libreoffice-theme-staging/Theme_Colors.xcu` | merged into the profile registry | **Bake**, opt-in (default: stays Noctalia's) | while LibreOffice is closed |
| 32 | Umbriel | `~/.config/umbriel/noctalia.toml` | Umbriel config | **Never** | — |
| 33 | yazi (not themed by Noctalia) | — | — | **Scope** `YAZI_CONFIG_HOME` → mirror with aptus `theme.toml` | next start |
| 34 | bat (not themed by Noctalia) | — | — | **Scope** `BAT_THEME` + Own theme in aptus's bat cache dir via `BAT_CACHE_PATH` | next run |
| 35 | Hyprland borders, shadows, background colour | — | — | **Own** (`hyprland.lua` is Hyprland-only) | `hyprctl` at runtime |
| 36 | hyprlock (fallback locker) | — | — | **Own** `~/.local/state/aptus/hyprlock.conf`, always started as `hyprlock -c <that file>`; Lenno's `~/.config/hypr/hyprlock.conf` is never touched | next lock |

**Coverage rule.** On every `aptus-session start` and in `aptus doctor`, aptus reads
`[theme.templates]` from Noctalia's settings and compares the enabled templates with this table. A
template without an aptus renderer is reported (`uncovered: <id>`) and that app shows Noctalia's
colours in Hyprland until a renderer exists. Adding a renderer is data, not code
([08-theming.md](08-theming.md) §5).

## 5. The lease protocol

### 5.1 Files

```
~/.local/state/aptus/lease/
  lock                      flock(2) target; held during take, update, release, recover
  journal.json              the only source of truth
  slots/<slot-id>.before    Noctalia's content, byte-for-byte (file slots)
  conflicts/<ISO-time>/     content someone else wrote into a leased slot during the session
  history/                  the last 10 released journals, for the audit
```

### 5.2 Journal

```json
{
  "version": 1,
  "state": "taking | held | releasing | released",
  "owner": {
    "boot_id": "…/proc/sys/kernel/random/boot_id…",
    "hyprland_pid": 2481,
    "hyprland_signature": "acc1aa…",
    "logind_session": "4",
    "taken_at": "2026-11-07T09:12:03+01:00"
  },
  "theme_generation": 37,
  "slots": [
    {
      "id": "gtk3.artifact", "kind": "file",
      "path": "/home/lenno/.config/gtk-3.0/noctalia.css",
      "write_path": "/home/lenno/.config/gtk-3.0/noctalia.css",
      "before": { "exists": true, "sha256": "…", "mode": "0644", "size": 18211 },
      "after":  { "sha256": "…" },
      "status": "held"
    },
    {
      "id": "kde.colors", "kind": "ini-sections",
      "path": "/home/lenno/.config/kdeglobals",
      "sections": ["Colors:*", "ColorEffects:*", "WM"],
      "before": { "exists": true, "sections_sha256": "…", "sections": "…verbatim text of those sections…" },
      "after":  { "sections_sha256": "…" },
      "status": "held"
    },
    {
      "id": "dconf.color-scheme", "kind": "dconf",
      "key": "/org/gnome/desktop/interface/color-scheme",
      "before": { "set": true, "value": "'prefer-dark'" },
      "after":  { "value": "'prefer-dark'" },
      "status": "held"
    }
  ]
}
```

`write_path` differs from `path` when `path` is a symlink: aptus writes through to the resolved
target and never replaces a symlink with a file.

### 5.3 Take (at Hyprland session start)

1. `flock lease/lock`.
2. If `journal.json` exists and `state != released`: run **recover** (§5.7) first.
3. **Preflight.** If `loginctl` lists another *active graphical* session of this user that is not
   this Hyprland (for example an Umbriel session left on another VT): **do not take the lease.**
   aptus runs in *scope-only* mode (Own and Scope targets themed, leased targets stay Noctalia's)
   and the notch says once: "Another session is open — some apps keep Noctalia's colours."
4. For every slot in the enabled target list whose artifact exists or whose key is readable:
   copy the current content to `slots/<id>.before` (write, `fsync`, rename, `fsync` dir) and fill
   `before`. A missing artifact is recorded as `exists: false`; aptus then creates it and release
   deletes it again.
5. Write the journal with `state: "taking"` atomically (temp file in the same directory, `fsync`,
   `rename`, `fsync` directory). **Nothing is modified before this point.**
6. Write aptus's paint into each slot atomically (temp + rename in the slot's own directory, mode
   copied from `before`). Fill `after`, set the slot `status: "held"`.
7. Set `state: "held"`, write the journal, release the flock.
8. Run each target's reload hook ([08-theming.md](08-theming.md) §7).

If any step fails, aptus releases the slots it already took (5.6) and continues in scope-only mode.
A failure never blocks the session from starting.

### 5.4 Update (theme or mode changes during the session)

Same as steps 6–7 for the affected slots, with the flock held: the `before` data is never touched
again, only `after` changes. `theme_generation` is incremented.

### 5.5 Slot kinds

| Kind | Read | Write | Restore |
|---|---|---|---|
| `file` | bytes + mode | temp + rename | temp + rename of `.before`; if `before.exists == false`, unlink |
| `ini-sections` | parse INI keeping order and comments; extract the listed sections (glob on names) | replace those sections in place, keep every other line byte-identical, temp + rename | put the `before` section text back in the same place; other sections stay as they are now (KDE apps may have written them meanwhile) |
| `dconf` | `dconf read KEY` (empty output = not set) | `dconf write KEY VALUE` | `dconf write KEY BEFORE`, or `dconf reset KEY` if it was not set |

The dconf key set is fixed: `org.gnome.desktop.interface` `color-scheme`, `gtk-theme` (recorded,
never changed), `icon-theme`, `cursor-theme`, `cursor-size`, `font-name`, `document-font-name`,
`monospace-font-name`, `accent-color`. No other key is ever written. App preferences stored in dconf
are untouched, so they stay shared between the sessions as they always were.

### 5.6 Release (Hyprland ended)

1. `flock`; set `state: "releasing"`; write the journal.
2. For every held slot:
   - Read the current content. If its hash equals `after`, restore `before`.
   - If it differs (something else wrote into the slot during the session), save the current content
     under `conflicts/<time>/<id>`, then restore `before` anyway. Noctalia's state always wins.
   - Verify the restored hash equals `before.sha256`; on mismatch retry once, then mark the slot
     `status: "failed"` and keep going.
3. Run every target's reload hook again, so processes that outlive the session (tmux server, a
   running Zen) see Noctalia's paint again.
4. Unset the scoped variables in the systemd user environment (§6).
5. Set `state: "released"`, move the journal to `history/`, release the flock.
6. Failed slots stay in the journal with `state: "releasing"`; recovery retries them at the next
   login and `aptus doctor` reports them.

### 5.7 Recover (anything left over)

`aptus-lease recover` runs (a) from `aptus-recover.service` whenever the user manager starts and
(b) at the start of every aptus session. It acts only when the journal says a lease is
held/taking/releasing **and** the owner is dead:

```
owner alive  ⇔  owner.boot_id == current boot_id
             ∧  /proc/<hyprland_pid> exists
             ∧  /proc/<hyprland_pid>/comm == "Hyprland"
             ∧  $XDG_RUNTIME_DIR/hypr/<hyprland_signature>/.socket.sock accepts a connection
```

If the owner is dead it performs release (5.6). If the owner is alive it does nothing. Recovery never
takes a lease.

## 6. Environment: what is set where

Set with `hl.env` in `hyprland.lua`, so only Hyprland's process tree has them:

| Variable | Value | Imported into systemd/D-Bus? |
|---|---|---|
| `APTUS_SESSION` | `1` | yes (lets scripts and the doctor tell the sessions apart) |
| `QT_QPA_PLATFORMTHEME` | `qt6ct` | yes (D-Bus-activated Qt apps must match) |
| `KITTY_CONFIG_DIRECTORY` | `~/.local/state/aptus/scope/kitty` | no |
| `STARSHIP_CONFIG` | `~/.local/state/aptus/scope/starship.toml` | no |
| `YAZI_CONFIG_HOME` | `~/.local/state/aptus/scope/yazi` | no |
| `BAT_THEME`, `BAT_CACHE_PATH` | `aptus`, `~/.cache/aptus/bat` | no |
| `XCURSOR_THEME`, `XCURSOR_SIZE`, `HYPRCURSOR_SIZE` | `Adwaita`, `24`, `24` | yes |

Imported with `systemctl --user import-environment` right after the lease is taken. On release the
guard runs `systemctl --user unset-environment APTUS_SESSION QT_QPA_PLATFORMTHEME XCURSOR_THEME`
(dbus-broker takes its activation environment from systemd, so this covers D-Bus activation too).
`XCURSOR_SIZE` stays: 24 is also Umbriel's value. The variables Hyprland imports by itself
(`WAYLAND_DISPLAY`, `XDG_CURRENT_DESKTOP`, `HYPRLAND_INSTANCE_SIGNATURE`) are Hyprland's existing
behaviour, Umbriel overwrites them on its own start, and aptus leaves them alone.

## 7. Lifecycle and every way a session can end

### Processes

```
Hyprland (started by the greeter via start-hyprland)
 └─ hl.on("hyprland.start") → aptus-session start          (bin/aptus-session)
     1. aptus-lease recover
     2. aptus-theme render            → ~/.local/state/aptus/theme/current/
     3. aptus-lease take              → journal + slots
     4. systemctl --user import-environment …
     5. systemd-run --user --unit=aptus-guard  aptus-guard <hyprland-pid>
     6. systemd-run --user --unit=aptus-clipd  --property=BindsTo=aptus-guard.service …
        systemd-run --user --unit=aptus-sunset --property=BindsTo=aptus-guard.service hyprsunset …
        systemd-run --user --unit=aptus-lid   --property=BindsTo=aptus-guard.service \
                    systemd-inhibit --what=handle-lid-switch --mode=block …   (only with power.lidAction = lock)
     7. exec aptus-supervise qs -p <repo>/shell    (restarts the shell on crash, see 07)

aptus-guard (transient user service, outside Hyprland's process tree)
  - pidfd_open(hyprland_pid); poll until it becomes readable (Hyprland exited)
  - or SIGTERM from the user manager (logout, shutdown)
  → aptus-lease release; unset env; stop bound units; exit 0

aptus-recover.service (the only installed user unit; WantedBy=default.target; Type=oneshot)
  → aptus-lease recover   (no-op unless a dead owner's lease is found)
```

### Exit matrix

| How the session ends | Who restores Noctalia's paint | When |
|---|---|---|
| Logout from aptus (session sheet, `Super+M`) | aptus closes windows, exits Hyprland; the guard releases | within ~1 s of Hyprland exiting |
| Hyprland crashes | guard (pidfd becomes readable) | within ~1 s |
| The shell (Quickshell) crashes | nobody needs to; the supervisor restarts it, the lease stays held | — |
| `aptus-session` itself is killed | guard is independent; the lease stays held while Hyprland runs | at Hyprland exit |
| User manager stops (last session ended) | guard gets SIGTERM, releases | before the manager finishes stopping |
| Reboot / shutdown from Hyprland | aptus logout path first; otherwise guard on SIGTERM | before the user manager stops |
| Power loss, kernel panic, hard reset | `aptus-recover.service` at the next login | as the user manager starts, racing the session start; normally done before the compositor's first client (probe P-04) |
| Log out of Hyprland and into Umbriel within 10 s (user manager survives) | guard released at Hyprland exit, env unset; portals read the restored dconf values live | before Umbriel starts |
| Umbriel session already open on another VT when Hyprland starts | no lease is taken (preflight, §5.3), scope-only mode | — |
| Switching VTs, suspend and resume | nothing changes; the lease stays held because Hyprland is alive | — |

### Ordering for crash recovery (probe P-04)
`pam_systemd` starts `user@1000.service` during login and waits until it reports ready; greetd
starts the session command after that. The user manager reports ready when it reaches
**basic.target**, not default.target (P-04 pre-check, [probes.md](probes.md): `user@1000.service`
became active 0.2 ms after basic.target and 20 ms before default.target). `aptus-recover.service`
cannot be ordered before basic.target: its dconf restore needs `dconf.service`, which is ordered
after basic.target, so that order would deadlock until the timeout. The unit therefore keeps
`DefaultDependencies=no` and `Before=default.target`: it starts the moment the user manager starts
and races the session start. **The designed fallback applies:** the window is the first second of
an Umbriel login after a power loss during Hyprland; recovery still completes then, only apps
launched in that window could start with aptus colours, and the restored dconf values reach
running apps live through the settings portal. P-04 measures the real margin on the laptop.

## 8. Things that must never happen in Hyprland

- **Noctalia must not run in the Hyprland session.** `hyprland.lua` stops starting it, and
  `aptus-session start` refuses to take a lease while a `noctalia` process of this user is running
  (it would rewrite the same artifacts). If it finds one, it says so in the notch and runs
  scope-only.
- aptus must not run in Umbriel: `aptus-session start` exits immediately unless
  `XDG_CURRENT_DESKTOP=Hyprland` and `HYPRLAND_INSTANCE_SIGNATURE` is set.

## 9. Side channels and traps

| Trap | Rule |
|---|---|
| Installing `adw-gtk3` (system or `~/.local/share/themes`) | Forbidden. Noctalia's GTK hook switches `gtk-theme` to `adw-gtk3-dark` whenever it exists, which would change Umbriel. aptus styles stock Adwaita through the leased CSS instead. |
| Installing fonts into `~/.local/share/fonts` | Forbidden. The Material Symbols font ships in the repo and is loaded by `FontLoader`. Inter and JetBrains Mono are already system fonts. |
| XDG autostart entries | Forbidden (Umbriel runs them). |
| Enabling user services other than `aptus-recover.service` | Forbidden. Everything else is a transient unit bound to the guard. |
| `mimeapps.list`, default terminal, default browser | aptus never changes them. |
| Clipboard history | aptus keeps its own database at `~/.local/state/aptus/clipboard.db`, never the default cliphist path. |
| Wallpaper | aptus has its own wallpaper setting; it never reads or writes Noctalia's. |
| Icon theme directories | aptus adds `aptus-icons-*` (inert unless selected); it never modifies `Papirus*`. |
| `qt6ct` package | Safe to install: nothing in Umbriel loads it (doctor verifies Umbriel's environment has no `QT_QPA_PLATFORMTHEME`). |
| `hyprsunset` package | Safe: Noctalia does not reference it; aptus starts it only inside Hyprland. |
| Battery charge thresholds, logind lid policy | Out of scope: machine-wide, would change Umbriel. aptus uses a logind *inhibitor* that lives only as long as the session (see [surfaces/session.md](surfaces/session.md)). |
| Leasing a file tracked in `~/dotfiles` | Allowed only when no Scope alternative exists (fastfetch, hyprtoolkit, nvim matugen). During a Hyprland session `git status` in `~/dotfiles` shows them modified; `aptus doctor` says so. Recommended fix: untrack the Noctalia artifacts (D-03). |

## 10. Audit

`aptus doctor isolation` prints one line per check and exits non-zero on any failure:

1. The journal is `released` (or `held` by a live owner).
2. Outside Hyprland: every slot's current hash equals the last journal's `before` hash; nothing in
   `conflicts/` is newer than the last check.
3. No aptus environment variable is in `systemctl --user show-environment` unless a live Hyprland
   owns a lease.
4. No `aptus-*` unit is running unless Hyprland is running.
5. Umbriel's environment (read from a running Umbriel process if one exists, otherwise from its
   config) has no `QT_QPA_PLATFORMTHEME`.
6. Every enabled Noctalia template is covered (§4 coverage rule).
7. No `adw-gtk3*` theme exists; no font files were added by aptus.
8. `~/.config/umbriel`, `~/.local/state/noctalia/settings.toml` and `/etc/greetd/config.toml` have
   the same hashes as at install time (recorded by `install.sh`), unless their mtime is newer
   than the last Umbriel session start (then Lenno changed them in Umbriel, which is fine).

**Round-trip test** (part of acceptance, [11-roadmap.md](11-roadmap.md)): hash every slot in
Umbriel; log into Hyprland; check the slots now carry aptus paint; kill Hyprland with `SIGKILL`;
log into Umbriel; every hash must equal the first set. Repeat with a hard power-off instead of the
kill.

## 11. Uninstall

`install.sh --uninstall`: releases any held lease, removes the `-- >>> aptus >>>` block from
`hyprland.lua` and offers to put back the Noctalia lines the install removed ([09-hyprland.md](09-hyprland.md) §1, shown as a diff, applied only on approval), disables `aptus-recover.service`, removes
`~/.local/state/aptus/scope`, the `aptus-icons-*` themes and `~/.config/qt6ct/qt6ct.conf` if aptus
created it. Lease history stays for inspection until removed by hand.
