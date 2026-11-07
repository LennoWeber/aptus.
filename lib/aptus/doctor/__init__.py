"""`aptus doctor [isolation | config | deps]`: one line per check, non-zero exit on failure."""
from __future__ import annotations

from collections.abc import Sequence

from ..paths import Paths

from dataclasses import dataclass


@dataclass(frozen=True)
class Check:
    name: str
    ok: bool
    detail: str = ""


def run(which: Sequence[str], paths: Paths) -> list[Check]:
    """Run the named groups ("config", "deps"; "isolation" arrives with S2), all by default."""
    raise NotImplementedError


def render(checks: Sequence[Check]) -> str:
    """One line per check: "ok   name" / "FAIL name: detail"."""
    raise NotImplementedError


def main(argv: Sequence[str]) -> int:
    raise NotImplementedError
