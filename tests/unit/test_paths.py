"""paths.resolve under APTUS_TEST and normally (07 §2, decision 8)."""
from __future__ import annotations

import os
from pathlib import Path

import pytest

from aptus import paths

REPO = Path(__file__).resolve().parents[2]


def test_xdg_defaults() -> None:
    p = paths.resolve({"HOME": "/home/someone"})
    home = Path("/home/someone")
    assert not p.test
    assert p.config_home == home / ".config"
    assert p.state_home == home / ".local/state"
    assert p.cache_home == home / ".cache"
    assert p.data_home == home / ".local/share"
    # no XDG_RUNTIME_DIR: the flags go where Paths.qml puts them (it cannot know the uid)
    assert p.runtime_home == home / ".aptus-run"
    assert p.hypr_runtime == Path(f"/run/user/{os.getuid()}/hypr")
    assert p.config == home / ".config/aptus"
    assert p.state == home / ".local/state/aptus"
    assert p.settings == home / ".config/aptus/settings.json"
    assert p.locked_marker == home / ".local/state/aptus/locked"
    assert p.hyprland_lua == home / ".config/hypr/hyprland.lua"
    assert p.hypr_aptus_link == home / ".config/hypr/aptus"
    assert p.v1_backup == home / ".local/state/aptus-v1-backup"
    assert p.runtime == home / ".aptus-run/aptus"
    assert p.restart_flag == p.runtime / "restart"
    assert p.intro_flag_prefix == p.runtime / "intro."


def test_xdg_from_env() -> None:
    p = paths.resolve({"HOME": "/home/someone", "XDG_CONFIG_HOME": "/srv/cfg",
                       "XDG_STATE_HOME": "/srv/state", "XDG_CACHE_HOME": "relative/cache",
                       "XDG_RUNTIME_DIR": "/run/user/4242"})
    assert p.config == Path("/srv/cfg/aptus")
    assert p.state == Path("/srv/state/aptus")
    assert p.cache_home == Path("/home/someone/.cache")       # relative values are ignored
    assert p.runtime == Path("/run/user/4242/aptus")
    assert p.hypr_runtime == Path("/run/user/4242/hypr")


def test_test_mode_ignores_xdg_outside_home(test_home: Path) -> None:
    env = {"HOME": str(test_home), "APTUS_TEST": "1",
           "XDG_CONFIG_HOME": "/home/lenno/.config",
           "XDG_STATE_HOME": str(test_home / "st"),
           "XDG_DATA_HOME": str(test_home / ".." / "outside")}
    p = paths.resolve(env)
    assert p.test
    assert p.config_home == test_home / ".config"
    assert p.state_home == test_home / "st"
    assert p.data_home == test_home / ".local/share"
    for field in ("config", "state", "cache", "settings", "lease", "theme", "install_state",
                  "v1_backup", "local_bin", "hyprland_lua", "systemd_user", "runtime"):
        assert paths.inside(getattr(p, field), test_home), field


def test_test_mode_runtime_in_home(test_home: Path) -> None:
    p = paths.resolve({"HOME": str(test_home), "APTUS_TEST": "1",
                       "XDG_RUNTIME_DIR": "/run/user/1000"})
    assert p.runtime_home == test_home / ".aptus-run"
    assert p.runtime == test_home / ".aptus-run/aptus"
    for flag in (p.restart_flag, p.dev_flag, p.guard_state, p.clip_changed, p.session_status):
        assert flag.parent == p.runtime


def test_repo_paths() -> None:
    p = paths.get()
    assert p.repo == REPO
    assert p.bin == REPO / "bin" and (p.bin / "aptus").is_file()
    assert p.shell == REPO / "shell" and (p.shell / "shell.qml").is_file()
    assert p.hypr_repo == REPO / "hypr" and (p.hypr_repo / "init.lua").is_file()
    assert p.tokens.is_file() and p.schema.is_file()


def test_inside(test_home: Path, tmp_path: Path) -> None:
    assert paths.inside(test_home, test_home)
    assert paths.inside(test_home / "a" / "b", test_home)
    assert not paths.inside(test_home.parent, test_home)
    assert not paths.inside(test_home / ".." / "x", test_home)
    assert not paths.inside(Path(str(test_home) + "-sibling"), test_home)
    outside = tmp_path / "outside"
    outside.mkdir()
    (test_home / "link").symlink_to(outside)
    assert not paths.inside(test_home / "link" / "f", test_home)     # symlinks are followed


def test_below_real_or_as_text(test_home: Path, tmp_path: Path) -> None:
    """paths.below: `real` follows links in both paths, otherwise the text is only normalised."""
    outside = tmp_path / "outside"
    outside.mkdir()
    (test_home / "link").symlink_to(outside)
    assert paths.below(test_home / "link" / "f", test_home, real=False)
    assert not paths.below(test_home / "link" / "f", test_home, real=True)
    assert paths.below(test_home / "link" / "f", outside, real=True)
    assert not paths.below(test_home / ".." / "x", test_home, real=False)
    assert not paths.below(str(test_home) + "-sibling", test_home, real=False)
    assert paths.below("/x/y", "/", real=False) and paths.below("/a/", "/a", real=False)


def test_plain_name() -> None:
    assert all(paths.plain_name(n) for n in ("kitty", "starship.toml", "a..b"))
    assert not any(paths.plain_name(n) for n in ("", ".", "..", ".hidden", "a/b", "/a"))


def test_get_not_cached_in_tests(test_home: Path, tmp_path: Path,
                                 monkeypatch: pytest.MonkeyPatch) -> None:
    assert paths.get().home == test_home
    other = tmp_path / "other"
    other.mkdir()
    monkeypatch.setenv("HOME", str(other))
    assert paths.get().home == other
    # Outside tests the first resolution is kept.
    monkeypatch.setattr(paths.get, "cached", None, raising=False)
    monkeypatch.delenv("APTUS_TEST")
    first = paths.get()
    monkeypatch.setenv("HOME", str(test_home))
    assert paths.get() is first


def test_hypr_runtime_is_real(test_home: Path) -> None:
    p = paths.resolve({"HOME": str(test_home), "APTUS_TEST": "1",
                       "XDG_RUNTIME_DIR": "/run/user/1000"})
    assert p.hypr_runtime == Path("/run/user/1000/hypr")
    p = paths.resolve({"HOME": str(test_home), "APTUS_TEST": "1"})
    assert p.hypr_runtime == Path(f"/run/user/{os.getuid()}/hypr")
    assert not paths.inside(p.hypr_runtime, test_home)
