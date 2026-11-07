"""E2E fixtures: one nested Hyprland per test session (07 §13).

The real session's signature is read first, before anything changes the environment, and
exported as APTUS_REAL_HYPRLAND_SIGNATURE; without it the harness refuses to start.
"""
from __future__ import annotations

import sys
from collections.abc import Iterator
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "lib"))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from nested import Nested  # noqa: E402


@pytest.fixture(scope="session")
def nested(tmp_path_factory: pytest.TempPathFactory) -> Iterator[Nested]:
    """Start the nested Hyprland and the shell in it; stop both at the end."""
    raise NotImplementedError
