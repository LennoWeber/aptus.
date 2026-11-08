"""Atomic writes (07 §9)."""
from __future__ import annotations

import os
import stat
from pathlib import Path

import pytest

from aptus import atomic


def test_write_creates_and_replaces(test_home: Path) -> None:
    target = test_home / "file.txt"
    atomic.write_text(target, "one\n")
    assert target.read_text() == "one\n"
    first_inode = target.stat().st_ino
    atomic.write_bytes(target, b"two\n")
    assert target.read_bytes() == b"two\n"
    assert target.stat().st_ino != first_inode          # replaced by rename, not rewritten
    assert sorted(p.name for p in test_home.iterdir()) == ["file.txt"]


def test_mode_kept(test_home: Path) -> None:
    target = test_home / "secret.json"
    target.write_text("{}")
    target.chmod(0o600)
    atomic.write_text(target, "{}\n")
    assert stat.S_IMODE(target.stat().st_mode) == 0o600
    atomic.write_text(target, "{}\n", mode=0o640)
    assert stat.S_IMODE(target.stat().st_mode) == 0o640
    fresh = test_home / "fresh"
    atomic.write_text(fresh, "x")
    assert stat.S_IMODE(fresh.stat().st_mode) == 0o644


def test_no_temp_left_on_error(test_home: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    target = test_home / "settings.json"
    target.write_text("old")

    def boom(src: object, dst: object) -> None:
        raise OSError("disk full")

    monkeypatch.setattr(os, "replace", boom)
    with pytest.raises(OSError):
        atomic.write_text(target, "new")
    assert target.read_text() == "old"
    assert sorted(p.name for p in test_home.iterdir()) == ["settings.json"]


def test_json_format(test_home: Path) -> None:
    target = test_home / "x.json"
    atomic.write_json(target, {"b": 1, "a": [1, "ü"]})
    assert target.read_text(encoding="utf-8") == '{\n  "a": [\n    1,\n    "ü"\n  ],\n  "b": 1\n}\n'


def test_symlink_swap(test_home: Path) -> None:
    gen1, gen2 = test_home / "gen-1", test_home / "gen-2"
    gen1.mkdir()
    gen2.mkdir()
    current = test_home / "current"
    atomic.symlink(Path("gen-1"), current)
    assert os.readlink(current) == "gen-1"
    atomic.symlink(Path("gen-2"), current)
    assert os.readlink(current) == "gen-2" and current.resolve() == gen2
    assert sorted(p.name for p in test_home.iterdir()) == ["current", "gen-1", "gen-2"]
