#!/usr/bin/env bash
# aptus installer for Fedora.
# Nothing here may touch suspend or hibernate settings, and every system change asks first.

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DRY_RUN=0
ASSUME_YES=0
WITH_GREETER=0
WITH_COPR=0
BIN_DIR="$HOME/.local/bin"
STATE_DIR="$HOME/.local/state/aptus"
CONFIG_DIR="$HOME/.config/aptus"
QS_DIR="$HOME/.config/quickshell"
HYPR_LUA="$HOME/.config/hypr/hyprland.lua"

say() { printf '%s\n' "$*"; }

# Run a change, or only print it with --dry-run.
do_it() {
    if [ "$DRY_RUN" = 1 ]; then say "  [dry-run] $*"; else "$@"; fi
}

# Ask a yes/no question. --yes answers yes. Default is no.
ask() {
    [ "$ASSUME_YES" = 1 ] && return 0
    local reply
    read -r -p "$1 [y/N] " reply
    [[ "$reply" =~ ^[yYjJ]$ ]]
}

# Link SRC to DST; an existing different file or link is moved aside once (DST.before-aptus).
link_into() {
    local src="$1" dst="$2"
    if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then return 0; fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        do_it mv "$dst" "$dst.before-aptus"
    fi
    do_it mkdir -p "$(dirname "$dst")"
    do_it ln -s "$src" "$dst"
}

check_fedora() {
    if [ ! -r /etc/os-release ] || ! grep -qi '^ID=fedora' /etc/os-release; then
        say "aptus is made for Fedora. This system is not Fedora."
        ask "Continue anyway?" || exit 1
    fi
    command -v qs >/dev/null 2>&1 || say "Warning: quickshell (qs) not found. Install quickshell >= 0.3.2 first."
    command -v hyprctl >/dev/null 2>&1 || say "Warning: hyprctl not found. aptus needs Hyprland."
}

# Every package aptus uses at run time (the greeter adds cage, see install_greeter).
REQUIRED_PACKAGES=(quickshell hyprsunset brightnessctl playerctl grim slurp wl-clipboard cliphist curl
    power-profiles-daemon NetworkManager iio-sensor-proxy wf-recorder libnotify python3)
COPR_REPO=lionheartp/Hyprland   # has quickshell, hyprsunset and cliphist for Fedora
MIN_QUICKSHELL=0.3.2

# The packages among the arguments that are not installed.
missing_packages() {
    local p
    for p in "$@"; do rpm -q "$p" >/dev/null 2>&1 || printf '%s\n' "$p"; done
}

# Enable the COPR for the packages the Fedora repositories do not have. Only with --copr, and it asks first:
# a COPR is a third-party source that can replace system packages.
enable_repos() {
    say "Not in the enabled repositories: $*"
    if [ "$WITH_COPR" != 1 ]; then
        say "They are in the COPR $COPR_REPO. Run again with --copr to enable it (asks first), or install them yourself."
        return 1
    fi
    ask "Enable the COPR $COPR_REPO (third-party packages, runs sudo dnf copr enable)?" || return 1
    do_it sudo dnf -y copr enable "$COPR_REPO"
}

check_quickshell_version() {
    command -v qs >/dev/null 2>&1 || return 0
    local have
    have="$(qs --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    [ -n "$have" ] || return 0
    if [ "$(printf '%s\n%s\n' "$MIN_QUICKSHELL" "$have" | sort -V | head -1)" != "$MIN_QUICKSHELL" ]; then
        say "Warning: quickshell $have is older than $MIN_QUICKSHELL, aptus needs $MIN_QUICKSHELL or newer."
    fi
}

# Install what is missing with dnf. Shows the list and asks; nothing else on the system changes.
# There is no way back for packages (remove them with dnf if you want them gone).
install_packages() {
    if ! command -v dnf >/dev/null 2>&1; then
        say "dnf not found. Install these yourself: ${REQUIRED_PACKAGES[*]}"
        return 0
    fi
    local missing=() unavailable=() installable=() p
    mapfile -t missing < <(missing_packages "${REQUIRED_PACKAGES[@]}")
    if [ "${#missing[@]}" -eq 0 ]; then
        check_quickshell_version
        return 0
    fi
    say "Missing packages: ${missing[*]}"
    for p in "${missing[@]}"; do
        if dnf -q repoquery --available "$p" 2>/dev/null | grep -q .; then installable+=("$p"); else unavailable+=("$p"); fi
    done
    if [ "${#unavailable[@]}" -gt 0 ] && enable_repos "${unavailable[*]}"; then
        installable+=("${unavailable[@]}")
    fi
    if [ "${#installable[@]}" -eq 0 ]; then return 0; fi
    if ask "Install ${installable[*]} with sudo dnf?"; then
        do_it sudo dnf install -y "${installable[@]}"
    fi
    check_quickshell_version
}

# Link config/ and theme/ into ~/.config/aptus and shell/ into ~/.config/quickshell/aptus (next to noctalia-shell and others).
link_config() {
    do_it mkdir -p "$CONFIG_DIR"
    local d
    for d in config theme hypr; do
        link_into "$ROOT/$d" "$CONFIG_DIR/$d"
    done
    link_into "$ROOT/shell" "$QS_DIR/aptus"
}

# Generate hypr/binds.generated.lua from config/hotkeys.json (owner aptus only) and offer to load it from hyprland.lua.
install_hyprland_binds() {
    if [ ! -f "$HYPR_LUA" ]; then
        say "$HYPR_LUA not found, skipping the Hyprland integration."
        return 0
    fi
    if grep -q -- '-- >>> aptus >>>' "$HYPR_LUA"; then
        say "Hyprland integration already present."
        return 0
    fi
    say "This block would be appended to $HYPR_LUA:"
    sed -n '/-- >>> aptus >>>/,/-- <<< aptus <<</p' "$ROOT/hypr/hyprland.lua.snippet"
    if ask "Append it? (backup: $HYPR_LUA.before-aptus)"; then
        [ -e "$HYPR_LUA.before-aptus" ] || do_it cp "$HYPR_LUA" "$HYPR_LUA.before-aptus"
        if [ "$DRY_RUN" = 1 ]; then
            say "  [dry-run] append block"
        else
            { printf '\n'; sed -n '/-- >>> aptus >>>/,/-- <<< aptus <<</p' "$ROOT/hypr/hyprland.lua.snippet"; } >>"$HYPR_LUA"
        fi
    fi
}

# Put bin/aptus into ~/.local/bin and link the config into ~/.config/quickshell/aptus.
install_launcher() {
    do_it mkdir -p "$BIN_DIR" "$STATE_DIR"
    link_into "$ROOT/bin/aptus" "$BIN_DIR/aptus"
    link_into "$ROOT/bin/aptus-patch-shell-switch" "$BIN_DIR/aptus-patch-shell-switch"
    link_into "$ROOT/bin/aptus-settings-watchdog" "$BIN_DIR/aptus-settings-watchdog"
    # The window look is read from the state dir, so a settings change can rewrite it.
    if [ ! -e "$STATE_DIR/hyprland-look.lua" ]; then
        do_it cp "$ROOT/hypr/aptus-look.lua" "$STATE_DIR/hyprland-look.lua"
    fi
    case ":$PATH:" in *":$BIN_DIR:"*) ;; *) say "Note: $BIN_DIR is not in your PATH." ;; esac
}

# Teach the user's shell-switch about aptus (ask first, back up the script).
patch_shell_switch() {
    local target
    target="$(command -v shell-switch || true)"
    if [ -z "$target" ]; then
        say "shell-switch not found. Start aptus directly with: aptus"
        return 0
    fi
    say "shell-switch found: $target"
    "$ROOT/bin/aptus-patch-shell-switch" --dry-run "$target"
    if ask "Patch shell-switch so it knows aptus? (backup: $target.before-aptus)"; then
        do_it "$ROOT/bin/aptus-patch-shell-switch" "$target"
    fi
}

# Check only: closing the lid must never suspend. Never writes to /etc/systemd.
check_lid_policy() {
    command -v systemd-analyze >/dev/null 2>&1 || return 0
    if systemd-analyze cat-config systemd/logind.conf 2>/dev/null | grep -q '^HandleLidSwitch=ignore'; then
        return 0
    fi
    say "Closing the lid may still suspend this laptop. aptus never suspends; to make logind ignore the lid, create"
    say "/etc/systemd/logind.conf.d/50-aptus-lid.conf with:"
    say "    [Login]"
    say "    HandleLidSwitch=ignore"
    say "    HandleLidSwitchExternalPower=ignore"
    say "(aptus locks the screen on lid close by itself.)"
}

GREETER_SHARE=/usr/local/share/aptus
GREETD_CONFIG=/etc/greetd/config.toml

# Opt-in (--greeter): replace the login screen. The old greetd config is saved as config.toml.before-aptus and
# --uninstall-greeter puts it back. Needs sudo for each step; nothing else on the system is changed.
install_greeter() {
    command -v cage >/dev/null 2>&1 || { say "cage is missing:  sudo dnf install cage"; return 1; }
    [ -f "$GREETD_CONFIG" ] || { say "$GREETD_CONFIG not found: greetd is not installed."; return 1; }
    say "The aptus greeter will replace the login screen. Current config:"
    sed 's/^/    /' "$GREETD_CONFIG"
    say "Backup: $GREETD_CONFIG.before-aptus. Way back: ./install.sh --uninstall-greeter, or from a console (Ctrl+Alt+F3):"
    say "    sudo cp $GREETD_CONFIG.before-aptus $GREETD_CONFIG && sudo systemctl restart greetd"
    ask "Install the aptus greeter now?" || return 0

    local tmp
    tmp="$(mktemp -d)"
    "$ROOT/bin/aptus-greeter-build" "$tmp"
    do_it sudo rm -rf "$GREETER_SHARE/greeter" "$GREETER_SHARE/theme"
    do_it sudo mkdir -p "$GREETER_SHARE" /etc/aptus
    do_it sudo cp -r "$tmp/greeter" "$tmp/theme" "$GREETER_SHARE/"
    do_it sudo chmod -R a+rX "$GREETER_SHARE"
    [ -e /etc/aptus/greeter.json ] || do_it sudo cp "$ROOT/config/greeter.json" /etc/aptus/greeter.json
    do_it sudo install -m 755 "$ROOT/bin/aptus-greeter-session" /usr/local/bin/aptus-greeter-session
    # The wallpaper picker's "Use for login screen" runs this helper as root through pkexec.
    do_it sudo install -m 755 -o root -g root "$ROOT/bin/aptus-greeter-wallpaper" /usr/local/bin/aptus-greeter-wallpaper
    do_it sudo install -m 644 "$ROOT/config/polkit/org.aptus.greeter-wallpaper.policy" /usr/share/polkit-1/actions/org.aptus.greeter-wallpaper.policy
    do_it sudo install -d -o greetd -g greetd -m 755 /var/cache/aptus-greeter
    [ -e "$GREETD_CONFIG.before-aptus" ] || do_it sudo cp "$GREETD_CONFIG" "$GREETD_CONFIG.before-aptus"
    if [ "$DRY_RUN" = 1 ]; then
        say "  [dry-run] write $GREETD_CONFIG"
    else
        printf '[terminal]\nvt = 1\n\n[default_session]\ncommand = "/usr/local/bin/aptus-greeter-session"\nuser = "greetd"\n' | sudo tee "$GREETD_CONFIG" >/dev/null
    fi
    rm -rf "$tmp"
    say "Greeter installed. It starts at the next login screen (log out or reboot); greetd is not restarted now,"
    say "so your current session stays. Log: /var/cache/aptus-greeter/greeter.log"
}

uninstall_greeter() {
    if [ ! -f "$GREETD_CONFIG.before-aptus" ]; then
        say "No backup $GREETD_CONFIG.before-aptus found; nothing to restore."
        return 0
    fi
    ask "Restore the old greetd config?" || return 0
    do_it sudo cp "$GREETD_CONFIG.before-aptus" "$GREETD_CONFIG"
    do_it sudo rm -rf "$GREETER_SHARE" /usr/local/bin/aptus-greeter-session /usr/local/bin/aptus-greeter-wallpaper /usr/share/polkit-1/actions/org.aptus.greeter-wallpaper.policy
    say "Old login screen restored; it is used at the next login screen."
}

# Remove DST if it is the link into this checkout, and put back what it replaced.
unlink_from() {
    local dst="$1" src="$2"
    if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
        do_it rm "$dst"
        if [ -e "$dst.before-aptus" ] || [ -L "$dst.before-aptus" ]; then do_it mv "$dst.before-aptus" "$dst"; fi
    fi
}

# Undo link_config, install_launcher, patch_shell_switch and install_hyprland_binds. Keeps your settings
# (~/.config/aptus/settings.json) and the state dir; packages and the greeter (--uninstall-greeter) are not touched.
uninstall() {
    say "This removes the aptus links and puts back the files they replaced."
    ask "Continue?" || return 0
    local d f
    for d in config theme hypr; do unlink_from "$CONFIG_DIR/$d" "$ROOT/$d"; done
    unlink_from "$QS_DIR/aptus" "$ROOT/shell"
    for f in aptus aptus-patch-shell-switch aptus-settings-watchdog; do unlink_from "$BIN_DIR/$f" "$ROOT/bin/$f"; done

    local target
    target="$(command -v shell-switch || true)"
    if [ -n "$target" ] && [ -f "$target.before-aptus" ] && ask "Restore shell-switch from $target.before-aptus?"; then
        do_it cp "$target.before-aptus" "$target"
    fi
    if [ -f "$HYPR_LUA" ] && grep -q -- '-- >>> aptus >>>' "$HYPR_LUA" && ask "Remove the aptus block from $HYPR_LUA? (backup: $HYPR_LUA.before-uninstall)"; then
        do_it cp "$HYPR_LUA" "$HYPR_LUA.before-uninstall"
        do_it sed -i '/-- >>> aptus >>>/,/-- <<< aptus <<</d' "$HYPR_LUA"
    fi
    say "Done. Left in place: ~/.config/aptus/settings.json, $STATE_DIR, installed packages."
    say "The login screen is separate: ./install.sh --uninstall-greeter"
}

main() {
    local arg ACTION=
    for arg in "$@"; do
        case "$arg" in
            --dry-run) DRY_RUN=1 ;;
            --yes) ASSUME_YES=1 ;;
            --greeter) WITH_GREETER=1 ;;
            --copr) WITH_COPR=1 ;;
            --uninstall) ACTION=uninstall ;;
            --uninstall-greeter) ACTION=uninstall_greeter ;;
            -h|--help) say "usage: install.sh [--dry-run] [--yes] [--copr] [--greeter] | --uninstall | --uninstall-greeter"; exit 0 ;;
            *) say "unknown option: $arg"; exit 2 ;;
        esac
    done
    # Flags can come in any order, so the removal runs only after all of them are read.
    if [ -n "$ACTION" ]; then "$ACTION"; exit 0; fi
    check_fedora
    install_packages
    link_config
    install_launcher
    patch_shell_switch
    install_hyprland_binds
    check_lid_policy
    [ "$WITH_GREETER" = 1 ] && install_greeter
    say "Done. Start with: aptus   (or: shell-switch to aptus)"
}

# Only run when executed, not when sourced (the tests source this file).
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
