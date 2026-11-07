"""Every path the session tools use (07-architecture §2, §9).

Resolved once from the environment. Under APTUS_TEST=1 every XDG directory is derived from HOME
(inherited XDG_* variables that point outside HOME are ignored) and runtime flags live in
$HOME/.aptus-run, so a test with a temporary HOME can never write outside it.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Paths:
    test: bool                 # APTUS_TEST=1
    home: Path
    config_home: Path          # $XDG_CONFIG_HOME
    state_home: Path           # $XDG_STATE_HOME
    cache_home: Path           # $XDG_CACHE_HOME
    data_home: Path            # $XDG_DATA_HOME
    runtime_home: Path         # $XDG_RUNTIME_DIR ($HOME/.aptus-run in tests)

    config: Path               # ~/.config/aptus
    state: Path                # ~/.local/state/aptus
    cache: Path                # ~/.cache/aptus
    runtime: Path              # $XDG_RUNTIME_DIR/aptus

    repo: Path                 # the repository (from this file's location)
    bin: Path                  # <repo>/bin
    shell: Path                # <repo>/shell
    hypr_repo: Path            # <repo>/hypr
    tokens: Path               # <repo>/theme/tokens.json
    schema: Path               # <repo>/shell/config/settings-schema.json

    settings: Path             # ~/.config/aptus/settings.json
    calendars: Path            # ~/.config/aptus/calendars.json
    lease: Path                # ~/.local/state/aptus/lease
    theme: Path                # ~/.local/state/aptus/theme
    scope: Path                # ~/.local/state/aptus/scope
    hypr_state: Path           # ~/.local/state/aptus/hypr (generated.lua, binds.local.lua)
    hyprlock_conf: Path        # ~/.local/state/aptus/hyprlock.conf
    locked_marker: Path        # ~/.local/state/aptus/locked
    install_state: Path        # ~/.local/state/aptus/install (backups, removed.lua, baseline.json)
    v1_backup: Path            # ~/.local/state/aptus-v1-backup

    local_bin: Path            # ~/.local/bin
    hypr_config_dir: Path      # ~/.config/hypr
    hyprland_lua: Path         # ~/.config/hypr/hyprland.lua
    hypr_aptus_link: Path      # ~/.config/hypr/aptus  →  <repo>/hypr
    systemd_user: Path         # ~/.config/systemd/user

    restart_flag: Path         # <runtime>/restart
    dev_flag: Path             # <runtime>/dev
    guard_state: Path          # <runtime>/guard.state
