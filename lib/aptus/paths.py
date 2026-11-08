"""Every path the session tools use (07-architecture §2, §9).

Resolved once from the environment. Under APTUS_TEST=1 every XDG directory is derived from HOME
(inherited XDG_* variables that point outside HOME are ignored) and runtime flags live in
$HOME/.aptus-run, so a test with a temporary HOME can never write outside it.
"""
from __future__ import annotations

import os
import pwd
from collections.abc import Mapping
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
    hypr_runtime: Path         # the real $XDG_RUNTIME_DIR/hypr (Hyprland's sockets; also in tests,
                               # where only the nested instance may be addressed, see hypr.py)

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
    lease_lock: Path           # lease/lock (flock target)
    lease_journal: Path        # lease/journal.json
    lease_slots: Path          # lease/slots/
    lease_conflicts: Path      # lease/conflicts/
    lease_history: Path        # lease/history/
    theme: Path                # ~/.local/state/aptus/theme
    theme_current: Path        # theme/current → gen-<n>
    scope: Path                # ~/.local/state/aptus/scope
    hypr_state: Path           # ~/.local/state/aptus/hypr
    generated_lua: Path        # hypr/generated.lua
    binds_local: Path          # hypr/binds.local.lua
    agenda: Path               # ~/.local/state/aptus/agenda.json
    clipboard_db: Path         # ~/.local/state/aptus/clipboard.db
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
    clip_changed: Path         # <runtime>/clip.changed
    session_status: Path       # <runtime>/session.json
    intro_flag_prefix: Path    # <runtime>/intro. (+ HYPRLAND_INSTANCE_SIGNATURE)

    cache_bat: Path            # ~/.cache/aptus/bat
    cache_agenda_http: Path    # ~/.cache/aptus/agenda-http


ENV_TEST = "APTUS_TEST"
TEST_RUNTIME = ".aptus-run"     # $HOME/.aptus-run in tests


def resolve(env: Mapping[str, str] | None = None) -> Paths:
    """Resolve every path from `env` (default os.environ). Under APTUS_TEST=1 an XDG variable
    pointing outside HOME is ignored and the runtime directory is $HOME/.aptus-run."""
    env = os.environ if env is None else env
    test = env.get(ENV_TEST) == "1"
    home = Path(env.get("HOME") or pwd.getpwuid(os.getuid()).pw_dir)

    def xdg(name: str, default: Path) -> Path:
        value = env.get(name, "")
        if not value or not os.path.isabs(value):      # the XDG spec ignores relative values
            return default
        p = Path(value)
        if test and not inside(p, home):
            return default
        return p

    real_runtime = Path(env.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}")
    config_home = xdg("XDG_CONFIG_HOME", home / ".config")
    state_home = xdg("XDG_STATE_HOME", home / ".local" / "state")
    cache_home = xdg("XDG_CACHE_HOME", home / ".cache")
    data_home = xdg("XDG_DATA_HOME", home / ".local" / "share")
    runtime_home = home / TEST_RUNTIME if test else real_runtime

    config = config_home / "aptus"
    state = state_home / "aptus"
    cache = cache_home / "aptus"
    runtime = runtime_home / "aptus"
    repo = Path(__file__).resolve().parents[2]
    lease = state / "lease"
    theme = state / "theme"
    hypr_state = state / "hypr"
    hypr_config_dir = config_home / "hypr"
    return Paths(
        test=test, home=home,
        config_home=config_home, state_home=state_home, cache_home=cache_home,
        data_home=data_home, runtime_home=runtime_home,
        hypr_runtime=real_runtime / "hypr",
        config=config, state=state, cache=cache, runtime=runtime,
        repo=repo, bin=repo / "bin", shell=repo / "shell", hypr_repo=repo / "hypr",
        tokens=repo / "theme" / "tokens.json",
        schema=repo / "shell" / "config" / "settings-schema.json",
        settings=config / "settings.json", calendars=config / "calendars.json",
        lease=lease, lease_lock=lease / "lock", lease_journal=lease / "journal.json",
        lease_slots=lease / "slots", lease_conflicts=lease / "conflicts",
        lease_history=lease / "history",
        theme=theme, theme_current=theme / "current",
        scope=state / "scope", hypr_state=hypr_state,
        generated_lua=hypr_state / "generated.lua", binds_local=hypr_state / "binds.local.lua",
        agenda=state / "agenda.json", clipboard_db=state / "clipboard.db",
        hyprlock_conf=state / "hyprlock.conf", locked_marker=state / "locked",
        install_state=state / "install", v1_backup=state_home / "aptus-v1-backup",
        local_bin=home / ".local" / "bin",
        hypr_config_dir=hypr_config_dir, hyprland_lua=hypr_config_dir / "hyprland.lua",
        hypr_aptus_link=hypr_config_dir / "aptus",
        systemd_user=config_home / "systemd" / "user",
        restart_flag=runtime / "restart", dev_flag=runtime / "dev",
        guard_state=runtime / "guard.state", clip_changed=runtime / "clip.changed",
        session_status=runtime / "session.json", intro_flag_prefix=runtime / "intro.",
        cache_bat=cache / "bat", cache_agenda_http=cache / "agenda-http",
    )


def get() -> Paths:
    """The paths of this process: resolved once normally; under APTUS_TEST=1 resolved on every
    call (the test fixture changes HOME per test, a cache would outlive it)."""
    if os.environ.get(ENV_TEST) == "1":
        return resolve()
    cached = getattr(get, "cached", None)
    if cached is None:
        cached = resolve()
        get.cached = cached        # type: ignore[attr-defined]
    return cached


def inside(path: Path, root: Path) -> bool:
    """Whether `path` (resolved, symlinks followed) is `root` or below it."""
    return Path(path).resolve().is_relative_to(Path(root).resolve())
