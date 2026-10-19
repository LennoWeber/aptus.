#!/usr/bin/env bash
# aptus installer for Fedora.
# Signatures only. Bodies and the main entry point come in phase 7.
# Nothing here may touch suspend or hibernate settings, and every system change asks first.

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DRY_RUN=0
ASSUME_YES=0
WITH_GREETER=0
BIN_DIR="$HOME/.local/bin"
STATE_DIR="$HOME/.local/state/aptus"
CONFIG_DIR="$HOME/.config/aptus"
QS_DIR="$HOME/.config/quickshell"
HYPR_LUA="$HOME/.config/hypr/hyprland.lua"

not_implemented() {
    echo "not implemented: ${FUNCNAME[1]}" >&2
    return 1
}

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

# Enable the repositories (COPR) needed for Quickshell and friends.
enable_repos() { not_implemented; }

# Install packages with dnf.
# TODO(phase 7): quickshell: the user's machine has 0.3.2 from COPR lionheartp/Hyprland (errornointernet/quickshell is also enabled); require >= 0.3.2, hyprsunset, hypridle, brightnessctl, playerctl, grim, hyprshot, iio-sensor-proxy, cliphist.
install_packages() { not_implemented; }

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
# TODO(phase 7): ask before touching ~/.config/hypr/hyprland.lua, back it up first, add only the lines of hypr/hyprland.lua.snippet.
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
# TODO(phase 7): add aptus to SHELLS, label(), bin_for(); other_shell() only knows two shells, so activate() must stop ALL other shells, not one fallback.
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

# cliphist is needed for the clipboard history. Only checks; installing is the user's call.
ensure_cliphist() {
    if command -v cliphist >/dev/null 2>&1; then return 0; fi
    say "cliphist is missing (clipboard history). Install it with:  sudo dnf install cliphist"
    say "(it is in the COPR lionheartp/Hyprland, or get a release binary from github.com/sentriz/cliphist)"
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
    do_it sudo rm -rf "$GREETER_SHARE" /usr/local/bin/aptus-greeter-session
    say "Old login screen restored; it is used at the next login screen."
}

main() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            --dry-run) DRY_RUN=1 ;;
            --yes) ASSUME_YES=1 ;;
            --greeter) WITH_GREETER=1 ;;
            --uninstall-greeter) uninstall_greeter; exit 0 ;;
            -h|--help) say "usage: install.sh [--dry-run] [--yes] [--greeter | --uninstall-greeter]"; exit 0 ;;
            *) say "unknown option: $arg"; exit 2 ;;
        esac
    done
    check_fedora
    link_config
    install_launcher
    patch_shell_switch
    install_hyprland_binds
    ensure_cliphist
    check_lid_policy
    [ "$WITH_GREETER" = 1 ] && install_greeter
    # TODO(phase 7, last section): enable_repos and install_packages are still stubs.
    say "Done. Start with: aptus   (or: shell-switch to aptus)"
}

# Only run when executed, not when sourced (the tests source this file).
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
