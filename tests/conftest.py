"""Shared fixtures. Every test runs with APTUS_TEST=1 and a temporary HOME (07 §13)."""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "lib"))


@pytest.fixture(autouse=True)
def test_home(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """HOME → <tmp>/home, APTUS_TEST=1, XDG_* and the Hyprland signature removed."""
    raise NotImplementedError
