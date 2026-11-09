"""Slot kinds (02 §5.5): file, ini-sections, dconf. Each kind reads the current state of a slot as
the journal's `before` shape, writes aptus's paint, restores `before`, and gives the digest that
`after` records and release compares against."""
from __future__ import annotations

from dataclasses import dataclass
from types import ModuleType
from typing import Any


@dataclass
class Snapshot:
    """The state of one slot as a kind reads it: `record` is the journal shape (`before`, or the
    `after` digest), `data` the bytes kept in slots/<id>.before (file slots only)."""
    record: dict[str, Any]
    data: bytes | None = None


KINDS = ("file", "ini-sections", "dconf")       # SlotKind values

# Every kind module has the same six functions (rec: journal.SlotRecord, spec: slots.SlotSpec):
#   read(paths, rec) -> Snapshot           current state in the journal's `before` shape
#   digest(paths, rec) -> dict             current state in the `after` shape (what release compares)
#   before_digest(before) -> dict          the `after`-shaped digest of a recorded `before`
#   planned(spec) -> dict                  the `after` digest that writing `spec` produces
#   write(paths, rec, spec) -> dict        write aptus's paint; returns the digest now in place
#   restore(paths, rec, data) -> None      put `before` back (data: slots/<id>.before for files)
#   current(paths, rec) -> bytes           what is in the slot now, for conflicts/<time>/<id>


def module(kind: str) -> ModuleType:
    """The module implementing `kind` (a SlotKind or its value); ValueError for anything else."""
    raise NotImplementedError


def sha256(data: bytes) -> str:
    """Hex SHA-256, the digest every kind records."""
    raise NotImplementedError
