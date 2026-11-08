"""Unit-test fixtures: every unit test runs with APTUS_TEST=1 and a temporary HOME (07 §13).
The e2e tests have their own conftest (they need the real session's signature to refuse it)."""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "lib"))


@pytest.fixture(autouse=True)
def test_home(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """HOME → <tmp>/home, APTUS_TEST=1, XDG_* and the Hyprland signature removed, and a fake
    APTUS_REAL_HYPRLAND_SIGNATURE so hypr.check_allowed fails closed for anything real."""
    home = tmp_path / "home"
    home.mkdir()
    for name in list(os.environ):
        if name.startswith("XDG_"):
            monkeypatch.delenv(name)
    for name in ("HYPRLAND_INSTANCE_SIGNATURE", "WAYLAND_DISPLAY", "DISPLAY", "APTUS_DEV",
                 "APTUS_LOG", "INVOCATION_ID", "QS_CONFIG_PATH"):
        monkeypatch.delenv(name, raising=False)
    monkeypatch.setenv("HOME", str(home))
    monkeypatch.setenv("APTUS_TEST", "1")
    monkeypatch.setenv("APTUS_REAL_HYPRLAND_SIGNATURE", "aptus-unit-tests-real-session")
    # Safety net: tools that could reach the real session fail loudly if a test forgets a fake.
    guard = tmp_path / "guard-bin"
    guard.mkdir()
    for tool in ("qs", "hyprctl", "hyprlock", "systemctl", "systemd-run", "systemd-cat"):
        stub = guard / tool
        stub.write_text(f"#!/bin/sh\necho 'unit tests: {tool} is blocked' >&2\nexit 99\n")
        stub.chmod(0o755)
    monkeypatch.setenv("PATH", f"{guard}{os.pathsep}{os.environ.get('PATH', '/usr/bin')}")
    return home
