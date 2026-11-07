"""`aptus doctor [isolation | config | deps]`: one line per check, non-zero exit on failure."""
from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Check:
    name: str
    ok: bool
    detail: str = ""
