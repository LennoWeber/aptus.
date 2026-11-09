"""Slot kinds (02 §5.5): file, ini-sections, dconf. Each kind reads the current state of a slot as
the journal's `before` shape, writes aptus's paint, restores `before`, and gives the digest that
`after` records and release compares against."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass
class Snapshot:
    """The state of one slot as a kind reads it: `record` is the journal shape (`before`, or the
    `after` digest), `data` the bytes kept in slots/<id>.before (file slots only)."""
    record: dict[str, Any]
    data: bytes | None = None
