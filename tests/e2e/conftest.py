"""E2E fixtures: one nested Hyprland per test session (07 §13).

The real session's signature is read first, before anything changes the environment, and
exported as APTUS_REAL_HYPRLAND_SIGNATURE; without it the harness refuses to start.
"""
from __future__ import annotations

import os
import sys
from collections.abc import Iterator
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "lib"))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from nested import Nested, real_signature  # noqa: E402

# Read before anything else touches the environment (fails closed: no session, no tests).
os.environ.setdefault("APTUS_REAL_HYPRLAND_SIGNATURE", os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", ""))


@pytest.fixture(scope="session")
def nested(tmp_path_factory: pytest.TempPathFactory) -> Iterator[Nested]:
    """Start the nested Hyprland and the shell in it; stop both at the end."""
    if not os.environ.get("APTUS_REAL_HYPRLAND_SIGNATURE"):
        pytest.skip("not inside a Hyprland session")
    real_signature()
    root = tmp_path_factory.mktemp("nested")
    n = Nested(root=root, home=root / "home")
    try:
        n.start()
        n.start_shell(timeout=20)
        yield n
    finally:
        n.stop()
        (root / "harness.log").write_text("\n".join(n.log))
