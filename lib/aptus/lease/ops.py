"""take | update | release | status (02 §5.3–§5.6), always under the lease flock.

Recover (§5.7) is in recover.py; the guard (§7) and aptus-session call these in-process.
"""
from __future__ import annotations

from collections.abc import Iterator, Mapping, Sequence
from contextlib import contextmanager
from dataclasses import dataclass, field
from pathlib import Path

from ..paths import Paths
from .journal import Owner, SlotRecord, State
from .slots import SlotSpec


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
    state: State | None = None               # None: no journal (released ones move to history/)
    owner_alive: bool = False
    owner: Owner | None = None
    slots: int = 0
    failed: list[str] = field(default_factory=list)
    generation: int = 0
    conflicts: int = 0                       # entries in conflicts/


LOCK_TIMEOUT = 10.0            # seconds to wait for the flock before giving up (LeaseError)


@contextmanager
def lock(paths: Paths, timeout: float = LOCK_TIMEOUT) -> Iterator[None]:
    """flock(lease/lock), re-entrant within one process (apply holds it around update, scope and
    own); LeaseError after `timeout`."""
    raise NotImplementedError


def owner(paths: Paths, env: Mapping[str, str]) -> Owner:
    """This session as the lease owner: boot id, the Hyprland pid from
    <hypr runtime>/<signature>/hyprland.lock, the signature, XDG_SESSION_ID, now. LeaseError when
    the signature is missing or refused (hypr.check_allowed) or the pid cannot be found."""
    raise NotImplementedError


def take(paths: Paths, specs: Sequence[SlotSpec], who: Owner, generation: int) -> TakeReport:
    """02 §5.3 steps 1, 2, 4–7: recover a leftover lease, record every slot's `before` (copies
    under slots/), journal `taking` with the planned `after`, write each slot, journal `held`.
    On any failure the slots already taken are released and the report says why. Preflight
    (step 3) is the caller's: aptus-session runs it before."""
    raise NotImplementedError


def update(paths: Paths, specs: Sequence[SlotSpec], generation: int) -> UpdateReport:
    """02 §5.4: write the specs of slots this lease holds; `before` is never touched, `after_prev`
    keeps the previous paint until the new one is in place. A slot not in the journal is
    ignored (it is taken at the next session start). LeaseError when no lease is held."""
    raise NotImplementedError


def release(paths: Paths) -> ReleaseReport:
    """02 §5.6: journal `releasing`; per slot compare with `before`, aptus's `after`/`after_prev`
    (restore) or neither (conflict: save the current content, restore anyway); verify, retry once,
    else `failed`; then `released` and history/, or stay `releasing` when a slot failed. The caller
    runs the reload hooks of `targets` and unsets the environment."""
    raise NotImplementedError


def status(paths: Paths) -> Status:
    """Read-only summary for `aptus-lease status` and the doctor."""
    raise NotImplementedError


def held_by(paths: Paths, signature: str) -> bool:
    """Whether the journal is `held` by the session with `signature` (apply's lease mode)."""
    raise NotImplementedError


def save_conflict(paths: Paths, stamp: str, rec: SlotRecord) -> Path:
    """conflicts/<stamp>/<slot id>: what someone else wrote into a leased slot."""
    raise NotImplementedError
