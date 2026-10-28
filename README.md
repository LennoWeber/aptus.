# shell.

A desktop shell for Fedora and Hyprland, built with [Quickshell](https://quickshell.org) (QML). Light, quiet, made
for a 2-in-1 laptop: everything works with keyboard, mouse and touch. Technical name: `aptus`.

Status: usable, still changing. Plan and decisions: [PHASES.md](PHASES.md).

![Control center](docs/screenshots/control-center.png)

![Launcher with a system action](docs/screenshots/launcher.png)

## What is in it

- **Bar** with workspaces, window title, status icons, clock; dropdowns for sound, network, Bluetooth, battery, night light, calendar.
- **Control center** (blurred overlay with tiles): sound, display, network, Bluetooth, power profile, caffeine, focus, VPN, hotspot, capture, timer, weather, media, calendar, system monitor.
- **Launcher** with five modes: apps, calculator and system actions (`wifi off`, `timer 10m`, `lock screen`), web search (optional suggestions), settings, AI (docked chat panel for command-line AI tools), clipboard history.
- **Settings app** with draft, save, a 15 second confirmation and an external watchdog that restores the old file if the shell dies.
  Bar and island each have a *Glass* switch (`bar.glass`, `island.glass`): a see-through fill with the picture behind it blurred.
  The island grows when something shows (`island.morph`: *spring*, *calm* or *off*) and never gets narrower than at rest. `island.style` picks *aptus* (light, solid), *phone* (pure black, like the iPhone island) or *glass* (dark see-through glass with a lit edge).
  The sidebar is grouped (Look, Desktop, Apps, System); every page has a short description and sub-headings, and search results say where a setting lives (`Dock › Apps`).
- **Dock** (Settings → Dock, off by default): kept apps and open windows, looks *glass*, *solid* and *minimal*, zoom under the pointer, a hop while an app starts, a size slider (`dock.iconSize`, 32 to 96), optional space reservation like the bar (`dock.reserveSpace`) and auto-hide. The kept apps are edited in the settings (order, remove, add from the installed apps) or with a right click on an icon.
- **Lock screen** (PAM), **greeter** for greetd, idle policy: lock after 5 minutes, screen off after 10. **Never suspend or hibernate.**
- **Touch and tablet mode:** edge swipes, bar hides in tablet mode, screen follows the orientation sensor, built-in on-screen keyboard.
- **Wallpaper** drawn by the shell, with a picker; **power menu** (lock, log out, restart, shut down).

## Requirements

Fedora, Hyprland 0.56+ (Lua config), Quickshell 0.3.2+, plus the packages in `packages/aptus-dnf.txt` (grouped: required, session,
backup, optional). `bin/aptus-packages` reads that list and only prints; it never installs:

```sh
bin/aptus-packages check                              # per group: all installed, or what is missing
bin/aptus-packages command required session backup   # the sudo dnf command for what is missing
```

## Install

```sh
./install.sh --dry-run        # show what it would do
./install.sh                  # installs missing packages (asks, sudo dnf), links the config, adds the Hyprland block (asks first, makes a backup)
./install.sh --copr           # also offer the COPR lionheartp/Hyprland for packages Fedora does not have (asks first)
./install.sh --greeter        # optional: replace the login screen (asks, backs up /etc/greetd/config.toml)
./install.sh --uninstall      # remove the links and the Hyprland block, put back the files they replaced (asks)
./install.sh --uninstall-greeter
```

`--yes` answers the questions with yes except the COPR, which needs `--copr`. Packages are never removed by the uninstall.

aptus is meant as the main shell. With the user's `shell-switch` it starts at login; a second shell (Noctalia) stays installed
as a backup and takes over if aptus does not come up. The window look (a little transparency, strong blur) is in `hypr/aptus-look.lua`;
the installer copies it to `~/.local/state/aptus/hyprland-look.lua` again whenever it changed.

Start with `aptus`. Send commands to the running shell with `aptus msg <command>`, for example
`aptus msg panel-toggle control-center`, `aptus msg session lock`, `aptus msg tablet-toggle`.

## Colours for the apps

Themes: **Super+T** opens a small picker with eight themes, and pressing it again (or the arrow keys) moves on; the shell shows each at once, **Enter** keeps it (the apps follow then), **Esc** goes back. The setting is `appearance.theme`, also in the settings app:

| Theme | Look |
|---|---|
| `light`, `dark` | the neutral palettes (default `light`) |
| `ocean`, `forest`, `dusk` | dark, tinted slate blue, fir green, indigo, each with one accent |
| `sand`, `sky` | light, warm cream with terracotta, cool ice blue with royal blue |
| `wallpaper` | made from the colours of the current wallpaper (`appearance.wallpaperTone`: `auto` follows its brightness, or `light`, `dark`) |
| `auto` | light, or dark while the night light runs |

The shell fades over 300 ms and repaints all apps in the background (`aptus-theme-apps --theme <id> --all --quiet`). `aptus msg theme-mode-set ocean` sets a theme from a script, `aptus msg theme-next 1` steps through them. The wallpaper theme is made by `bin/aptus-wallpaper-theme PICTURE` (Pillow) into `~/.local/state/aptus/wallpaper-theme.json`.

Wallpaper: `wallpaper.fit` is `fill` (default, covers and crops), `fit` (whole picture, bars in the theme colour), `stretch`, `center` (original size) or `tile`; it applies to the desktop, the lock screen and the login screen. With the aptus login screen installed (`./install.sh --greeter`), the login screen shows your desktop wallpaper and keeps it in step by itself (`appearance.loginWallpaper`, default on). The polkit rule that allows this without a password is installed with the greeter; run the installer again after updating if the login picture does not follow.

`aptus-theme-apps` paints the programs around the shell with the same palette (`theme/tokens.json`, light or dark, templates in `theme/apps`):

```
aptus-theme-apps                    # kitty, ghostty, GTK, Qt, btop, zathura, gsettings (light)
aptus-theme-apps --mode dark --all  # everything, dark
aptus-theme-apps --only starship,zen --dry-run
```

`--all` adds Starship (`~/.config/starship/aptus.toml`, selected by fish through `STARSHIP_CONFIG`), fish, Neovim (`colorscheme aptus`), yazi, fastfetch (`~/.config/fastfetch/aptus-config.jsonc`, used by the `fastfetch` alias in fish), cava, window borders, hyprlock, Zen and Thunderbird (`userChrome.css`, `userContent.css`; start Thunderbird once so it has a profile) and a Spicetify theme (set `light` or `dark` and applied by the script; restart Spotify to see it). Zen and Thunderbird follow the system colour scheme, which the script sets with gsettings; restart the browser once after the first run. Replaced files are kept as `NAME.before-aptus`; nothing is installed.

## Keys (defaults)

| Key | Action |
|---|---|
| Mod+Space or Mod+D | launcher |
| Mod+A / Mod+Shift+B / Mod+Shift+C | AI / web / clipboard mode |
| Mod+L | lock |
| Mod+X | power menu |
| Mod+W | wallpaper picker |

## Safety

- If the shell dies while the screen is locked, it stays locked. Switch to a console with Ctrl+Alt+F3, log in and start the shell again.
- The greeter installer keeps your old greetd config as `config.toml.before-aptus`; the way back is in the installer output.
- A settings change that is not confirmed within 15 seconds is reverted.

## Layout

`shell/` QML shell, `greeter/` login screen, `config/` defaults, `theme/` design values, `bin/` helper scripts, `hypr/` Hyprland snippets.
Lint: `./aptus-lint.sh` (qmllint, target 0 warnings).

## License

MIT, see [LICENSE](LICENSE).
