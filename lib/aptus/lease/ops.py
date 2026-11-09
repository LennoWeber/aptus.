"""take | update | release | status (02 §5.3–§5.6), always under the lease flock.

Recover (§5.7) is in recover.py; the guard (§7) and aptus-session call these in-process.
"""
from __future__ import annotations

from dataclasses import dataclass, field


class LeaseError(RuntimeError):
    """A lease operation could not run (lock, journal, owner); nothing was modified by it."""


@dataclass
class TakeReport:
    held: bool = False                       # the journal reached `held`
    slots: list[str] = field(default_factory=list)       # slot ids now carrying aptus paint
    skipped: list[str] = field(default_factory=list)     # slots not taken (absent, unreadable)
    error: str = ""                          # why the take was undone (scope-only follows)


@dataclass
class UpdateReport:
    generation: int = 0
    written: list[str] = field(default_factory=list)
    failed: dict[str, str] = field(default_factory=dict)  # slot id → why


@dataclass
class ReleaseReport:
    acted: bool = False                      # a lease existed and was released (or retried)
    restored: list[str] = field(default_factory=list)    # written back to `before`
    unchanged: list[str] = field(default_factory=list)   # already equal to `before`
    conflicts: list[str] = field(default_factory=list)   # someone else wrote it (saved, restored anyway)
    failed: dict[str, str] = field(default_factory=dict)  # slot id → why (journal stays `releasing`)
    targets: list[str] = field(default_factory=list)     # targets whose reload hooks must run again


@dataclass
class Status:
    state: str = "released"                  # journal state, or "none" without a journal
    owner_alive: bool = False
    owner: dict | None = None
    slots: int = 0
    failed: list[str] = field(default_factory=list)
    generation: int = 0
    conflicts: int = 0                       # entries in conflicts/
