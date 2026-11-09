"""take | update | release | recover | status (02 §5.3–§5.7), always under the lease flock.

Only this package writes a leased slot (CLAUDE.md, 02 §5): aptus-session, aptus-theme and
aptus-guard call these functions in-process, `aptus-lease` is their command line. Every entry
point checks `paths.require_safe_home` (through `lock`).
"""
from __future__ import annotations

from collections.abc import Iterator, Mapping, Sequence
from contextlib import contextmanager
from dataclasses import dataclass, field
from pathlib import Path

from ..paths import Paths
from .journal import Owner, SlotRecord, State
from .preflight import Preflight
from .slots import SlotSpec


class LeaseError(RuntimeError):
    """A lease operation could not run (lock busy, a journal left by a live or unknown owner, no
    owner); nothing was modified by it. The session continues scope-only."""


@dataclass
class TakeReport:
    held: bool = False                       # the journal reached `held`
    preflight: Preflight | None = None       # step 3 (not ok: nothing was taken)
    slots: list[str] = field(default_factory=list)       # slot ids now carrying aptus paint
    skipped: list[str] = field(default_factory=list)     # not taken (absent, its directory absent, unreadable)
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
    reloads: dict[str, str] = field(default_factory=dict)  # target id → reload hook, from the journal


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
    """flock(lease/lock), re-entrant within one process (take calls recover); LeaseError after
    `timeout`. Checks require_safe_home first. Only lease operations run under it: rendering,
    scope and Own files use the theme lock, so a slow `bat cache --build` never delays a release."""
    # TODO(S2): require_safe_home; a module dict path → (fd, depth) for re-entrancy; else open
    #   (O_CREAT, 0600), flock LOCK_EX|LOCK_NB in a 50 ms loop until `timeout`, yield, unlock.
    raise NotImplementedError


def owner(paths: Paths, env: Mapping[str, str]) -> Owner:
    """This session as the lease owner: boot id, the Hyprland pid from
    <hypr runtime>/<signature>/hyprland.lock, the signature, XDG_SESSION_ID, now. LeaseError when
    the signature is missing or refused (hypr.check_allowed) or the pid cannot be found."""
    # TODO(S2): hypr.signature(env) (raises for the real one under test); line 1 of hyprland.lock;
    #   comm must be "Hyprland"; journal.now().
    raise NotImplementedError


def take(paths: Paths, env: Mapping[str, str], specs: Sequence[SlotSpec], who: Owner,
         generation: int) -> TakeReport:
    """02 §5.3 steps 1–7 under the flock: recover a leftover lease; then preflight (another open
    session or a running Noctalia: nothing is taken, the report carries why); record every
    slot's `before` (file copies under slots/), journal `taking` with the planned `after`, write
    each slot, journal `held`. A missing artifact is created only when `spec.create` and its
    directory exists, else skipped. On a failure after `taking` the slots already taken are
    released and `error` says why. LeaseError when a journal is still there after recover (a live
    owner, failed slots, or one that does not parse): Noctalia's only `before` record must never
    be overwritten."""
    # TODO(S2): with lock: recover(paths); if journal.load is not None (after archiving a
    #   leftover `released` one) → LeaseError. preflight.check(paths, env) → not ok: return
    #   TakeReport(preflight=…). For each spec: SlotRecord from the spec (write_path via the
    #   kind), kind.read → before (+ slots/<id>.before atomically), skip rules, after =
    #   kind.planned. journal.save(state taking) — nothing is modified before this point. Write
    #   each slot (kind.write, status held, save after each); journal held. Any exception after
    #   `taking`: save, release(paths), error. invariants.transition on every state change.
    raise NotImplementedError


def update(paths: Paths, specs: Sequence[SlotSpec], generation: int) -> UpdateReport:
    """02 §5.4: write the specs of slots this lease holds; `before` is never touched, `after_prev`
    keeps the previous paint until the new one is in place. A slot not in the journal is
    ignored (it is taken at the next session start). LeaseError when no lease is held."""
    # TODO(S2): with lock: journal held (else LeaseError); per spec with a held record:
    #   after_prev = after, save; after = kind.write; after_prev = None; save; theme_generation.
    raise NotImplementedError


def release(paths: Paths) -> ReleaseReport:
    """02 §5.6: journal `releasing`; per slot compare with `before` (unchanged), aptus's
    `after`/`after_prev` (restore) or neither (conflict: save the current content, restore
    anyway); verify, retry once, else `failed`; then `released` and history/, or stay
    `releasing` when a slot failed. `reloads` names the hooks the caller runs afterwards (the
    environment is the guard's)."""
    # TODO(S2): with lock: no journal or released → acted false. State releasing, save. Per slot
    #   not restored: record-only → restored; digest == before_digest → unchanged; not ours →
    #   save_conflict; kind.restore with slots/<id>.before; verify twice; failed with error;
    #   save after each slot. No failure: released_at, journal.archive. reloads of restored slots.
    raise NotImplementedError


def recover(paths: Paths) -> ReleaseReport:
    """02 §5.7 under the flock: no journal, `released` (archived), or a live owner → nothing
    (acted false); else release. JournalError (not caught) for a journal that does not parse:
    only a human may decide then. Never takes."""
    # TODO(S2): with lock: journal.load (JournalError propagates); released → archive;
    #   owner and liveness.owner_alive → return; else release(paths).
    raise NotImplementedError


def status(paths: Paths) -> Status:
    """Read-only summary for `aptus-lease status` and the doctor (no lock)."""
    # TODO(S2): journal.load, owner_alive, failed slot ids, len(conflicts/).
    raise NotImplementedError


def held_by(paths: Paths, signature: str, pid: int | None = None) -> bool:
    """Whether a journal that is not `released` belongs to the session with `signature` (and
    `pid` when given): apply's lease mode, the guard's ownership check."""
    # TODO(S2): journal.load (False when unreadable); state != released; owner fields match.
    raise NotImplementedError


def save_conflict(paths: Paths, stamp: str, rec: SlotRecord) -> Path:
    """conflicts/<stamp>/<slot id>: what someone else wrote into a leased slot."""
    # TODO(S2): kind.current bytes, atomic.write_bytes (0600), mkdir parents.
    raise NotImplementedError
