"""Unit-test fixtures: every unit test runs with APTUS_TEST=1 and a temporary HOME (07 §13).
The e2e tests have their own conftest (they need the real session's signature to refuse it)."""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "lib"))


@pytest.fixture(autouse=True)
def test_home(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """HOME → <tmp>/home, APTUS_TEST=1, XDG_* and the Hyprland signature removed, and a fake
    APTUS_REAL_HYPRLAND_SIGNATURE so hypr.check_allowed fails closed for anything real."""
    raise NotImplementedError
