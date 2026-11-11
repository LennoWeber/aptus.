"""take | update | release | recover | status (02 §5.3–§5.7), always under the lease flock.

Only this package writes a leased slot (CLAUDE.md, 02 §5): aptus-session, aptus-theme and
aptus-guard call these functions in-process, `aptus-lease` is their command line. Every entry
point checks `paths.require_safe_home` (through `lock`).
"""
from __future__ import annotations

import logging
import time
from collections.abc import Iterator, Mapping, Sequence
from contextlib import contextmanager
from dataclasses import dataclass, field
from pathlib import Path

from .. import atomic, hypr
from ..paths import Paths, require_safe_home
from . import invariants, journal, kinds, liveness, locks, preflight, system
from .journal import Journal, JournalError, Owner, SlotKind, SlotRecord, SlotStatus, State
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
    unchanged: list[str] = field(default_factory=list)   # carried this paint already: not written
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

_log = logging.getLogger("aptus.lease")


@contextmanager
def lock(paths: Paths, timeout: float = LOCK_TIMEOUT) -> Iterator[None]:
    """flock(lease/lock) through locks.exclusive, re-entrant within one thread (take calls
    recover); LeaseError after `timeout`. Checks require_safe_home first. Only lease operations
    run under it: rendering, scope and Own files use the theme lock, so a slow `bat cache
    --build` never delays a release."""
    require_safe_home(paths)
    paths.lease.mkdir(mode=0o700, parents=True, exist_ok=True)
    with locks.exclusive(paths.lease_lock, timeout,
                         lambda: LeaseError(f"the lease lock is busy (waited {timeout:.0f} s)")):
        yield


def signature(env: Mapping[str, str] | None = None) -> str:
    """This session's HYPRLAND_INSTANCE_SIGNATURE (of `env`, default this process) as
    hypr.signature checks it; "" when it is missing or refused under test (no lease then)."""
    try:
        return hypr.signature(env)
    except hypr.HyprError:
        return ""


def owner(paths: Paths, env: Mapping[str, str]) -> Owner:
    """This session as the lease owner: boot id, the Hyprland pid from
    <hypr runtime>/<signature>/hyprland.lock, the signature, XDG_SESSION_ID, now. LeaseError when
    the signature is missing or refused (hypr.check_allowed) or the pid cannot be found."""
    try:
        sig = hypr.signature(env)
    except hypr.HyprError as e:
        raise LeaseError(str(e)) from e
    lockfile = paths.hypr_runtime / sig / "hyprland.lock"
    try:
        pid = int(lockfile.read_text().splitlines()[0])
    except (OSError, ValueError, IndexError) as e:
        raise LeaseError(f"no Hyprland pid in {lockfile}: {e}") from e
    if system.comm(pid) != "Hyprland":
        raise LeaseError(f"pid {pid} of {lockfile} is not Hyprland")
    return Owner(boot_id=system.boot_id(), hyprland_pid=pid, hyprland_signature=sig,
                 logind_session=env.get("XDG_SESSION_ID", ""), taken_at=journal.now())


def _record(spec: SlotSpec) -> SlotRecord:
    """The journal record of a spec; `write` false only for a dconf key without a value."""
    write_path = str(kinds.module("file").write_path(spec.path)) if spec.path is not None else ""
    return SlotRecord(id=spec.id, kind=spec.kind, target=spec.target, reload=spec.reload,
                      path=str(spec.path or ""), write_path=write_path, key=spec.key,
                      sections=list(spec.sections),
                      write=spec.kind != SlotKind.DCONF or spec.value is not None)


def _prepare(paths: Paths, spec: SlotSpec, report: TakeReport) -> SlotRecord | None:
    """Step 4 for one slot: `before` (and its slots/ copy), the planned `after`; None = skipped."""
    rec = _record(spec)
    mod = kinds.module(spec.kind)
    try:
        snap = mod.read(paths, rec)
    except Exception as e:                                  # unreadable, dconf missing, …
        _log.warning("slot %s skipped: %s", spec.id, e)
        report.skipped.append(spec.id)
        return None
    if spec.kind != SlotKind.DCONF and not snap.record.get("exists") and (
            not spec.create or not Path(rec.write_path).parent.is_dir()):
        report.skipped.append(spec.id)
        return None
    rec.before = snap.record
    if snap.data is not None:
        dest = journal.before_file(paths, rec.id)
        invariants.writable(paths, dest, kind="state")
        paths.lease_slots.mkdir(mode=0o700, parents=True, exist_ok=True)
        atomic.write_bytes(dest, snap.data, 0o600)
    rec.after = mod.planned(spec) if rec.write else mod.before_digest(rec.before)
    return rec


def _set_state(paths: Paths, j: Journal, new: State) -> None:
    invariants.transition(j.state, new)
    j.state = new
    journal.save(paths, j)


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
    invariants.check_specs(paths, specs)
    report = TakeReport()
    with lock(paths):
        try:
            recover(paths)
            left = journal.load(paths)
        except JournalError as e:
            raise LeaseError(f"the lease journal does not parse, a human must look: {e}") from e
        if left is not None:
            raise LeaseError(f"a lease journal is still there ({left.state.value}); "
                             "run aptus-lease recover or aptus doctor isolation")
        report.preflight = preflight.check(paths, env)
        if not report.preflight.ok:
            return report
        try:
            records = [(r, spec) for spec in specs if (r := _prepare(paths, spec, report))]
        except Exception as e:                              # writing slots/<id>.before failed
            report.error = f"recording before failed: {e}"
            return report
        j = Journal(state=State.TAKING, owner=who, theme_generation=generation,
                    slots=[r for r, _ in records])
        invariants.transition(None, State.TAKING)
        journal.save(paths, j)                              # nothing was modified before this
        try:
            for rec, spec in records:
                if rec.write:
                    rec.after = kinds.module(rec.kind).write(paths, rec, spec)
                rec.status = SlotStatus.HELD
                journal.save(paths, j)
            _set_state(paths, j, State.HELD)
        except Exception as e:
            report.error = f"{type(e).__name__}: {e}"
            _log.error("take failed, releasing what was taken: %s", report.error)
            undo = release(paths)
            if undo.failed:
                report.error += f"; release failed for {', '.join(undo.failed)}"
            return report
    report.held = True
    report.slots = [r.id for r in j.slots]
    return report


def _digest(paths: Paths, mod, rec: SlotRecord) -> dict | None:
    """mod.digest, None when the slot cannot be read."""
    try:
        return mod.digest(paths, rec)
    except Exception:  # noqa: BLE001 - an unreadable slot is just not known
        return None


def _settle(paths: Paths, mod, rec: SlotRecord) -> None:
    """After a failed write: `after` is the paint the slot carries now (writes are atomic, so
    mostly the previous one) and after_prev is cleared, so release never mistakes a later paint
    for a conflict. When the slot cannot be read both stay: release accepts either."""
    now = _digest(paths, mod, rec)
    if now is None:
        return
    if now != rec.after and rec.after_prev is not None:   # the write did not land
        rec.after = rec.after_prev
    rec.after_prev = None


def update(paths: Paths, specs: Sequence[SlotSpec], generation: int) -> UpdateReport:
    """02 §5.4: write the specs of slots this lease holds; `before` is never touched, `after_prev`
    keeps the previous paint until the new one is in place. A slot that carries the planned paint
    already is not written (`unchanged`); a slot not in the journal is ignored (it is taken at the
    next session start). A spec that does not match its slot (invariants.check_update) and a
    write that fails are failures of that slot only. LeaseError when no lease is held."""
    invariants.check_specs(paths, specs)
    report = UpdateReport(generation=generation)
    with lock(paths):
        try:
            j = journal.load(paths)
        except JournalError as e:
            raise LeaseError(str(e)) from e
        if j is None or j.state != State.HELD:
            raise LeaseError("no lease is held")
        for spec in specs:
            rec = journal.slot(j, spec.id)
            if rec is None or rec.status != SlotStatus.HELD or not rec.write or \
                    (spec.kind == SlotKind.DCONF and spec.value is None):
                continue
            try:
                invariants.check_update(spec, rec)
            except invariants.InvariantError as e:
                report.failed[spec.id] = f"InvariantError: {e}"
                continue
            mod = kinds.module(rec.kind)
            want = mod.planned(spec)
            if want == rec.after and rec.after_prev is None and _digest(paths, mod, rec) == want:
                report.unchanged.append(spec.id)
                continue
            rec.after_prev, rec.after = rec.after, want
            journal.save(paths, j)
            try:
                rec.after = mod.write(paths, rec, spec)
                rec.after_prev = None
                report.written.append(spec.id)
            except Exception as e:
                report.failed[spec.id] = f"{type(e).__name__}: {e}"
                _settle(paths, mod, rec)
            journal.save(paths, j)
        if j.theme_generation != generation:
            j.theme_generation = generation
            journal.save(paths, j)
    return report


def _before_data(paths: Paths, rec: SlotRecord) -> bytes | None:
    """slots/<id>.before of a file slot that existed, verified against before.sha256."""
    if rec.kind != SlotKind.FILE or not rec.before.get("exists"):
        return None
    data = journal.before_file(paths, rec.id).read_bytes()
    if kinds.sha256(data) != rec.before.get("sha256"):
        raise LeaseError(f"slots/{rec.id}.before does not match the recorded before")
    return data


def _release_slot(paths: Paths, rec: SlotRecord, stamp: str, report: ReleaseReport) -> None:
    """One slot of 02 §5.6; any failure marks the slot failed (recover retries)."""
    mod = kinds.module(rec.kind)
    try:
        if not rec.write:
            rec.status = SlotStatus.RESTORED
            return
        want = mod.before_digest(rec.before)
        now = mod.digest(paths, rec)
        if now == want:
            rec.status = SlotStatus.RESTORED
            report.unchanged.append(rec.id)
            return
        if now != rec.after and (rec.after_prev is None or now != rec.after_prev):
            save_conflict(paths, stamp, rec)
            report.conflicts.append(rec.id)
        data = _before_data(paths, rec)
        for _ in range(2):
            mod.restore(paths, rec, data)
            if mod.digest(paths, rec) == want:
                break
        else:
            raise LeaseError("the restored slot does not match its before")
        rec.status, rec.error = SlotStatus.RESTORED, ""
        report.restored.append(rec.id)
        if rec.reload != "none":
            report.reloads[rec.target] = rec.reload
    except Exception as e:
        rec.status, rec.error = SlotStatus.FAILED, f"{type(e).__name__}: {e}"
        report.failed[rec.id] = rec.error
        _log.error("slot %s not restored: %s", rec.id, rec.error)


def release(paths: Paths, expect: tuple[str, int] | None = None) -> ReleaseReport:
    """02 §5.6: journal `releasing`; per slot compare with `before` (unchanged), aptus's
    `after`/`after_prev` (restore) or neither (conflict: save the current content, restore
    anyway); verify, retry once, else `failed`; then `released` and history/, or stay
    `releasing` when a slot failed. `reloads` names the hooks the caller runs afterwards (the
    environment is the guard's). With `expect` = (signature, pid) only that owner's lease is
    released (checked under the flock)."""
    report = ReleaseReport()
    with lock(paths):
        j = journal.load(paths)
        if j is None:
            return report
        if j.state == State.RELEASED:
            journal.archive(paths, j)
            return report
        if expect is not None and (j.owner is None or (j.owner.hyprland_signature,
                                                       j.owner.hyprland_pid) != tuple(expect)):
            return report
        report.acted = True
        if j.state != State.RELEASING:
            _set_state(paths, j, State.RELEASING)
        stamp = time.strftime("%Y%m%dT%H%M%S")
        for rec in j.slots:
            if rec.status != SlotStatus.RESTORED:
                _release_slot(paths, rec, stamp, report)
                journal.save(paths, j)
        if report.failed:
            return report
        j.released_at = journal.now()
        _set_state(paths, j, State.RELEASED)
        journal.archive(paths, j)
    _log.info("lease released: %d restored, %d unchanged, %d conflicts", len(report.restored),
              len(report.unchanged), len(report.conflicts))
    return report


def recover(paths: Paths) -> ReleaseReport:
    """02 §5.7 under the flock: no journal, `released` (archived), or a live owner → nothing
    (acted false); else release. JournalError (not caught) for a journal that does not parse:
    only a human may decide then. Never takes."""
    with lock(paths):
        j = journal.load(paths)
        if j is None:
            return ReleaseReport()
        if j.state == State.RELEASED:
            journal.archive(paths, j)
            return ReleaseReport()
        if j.owner is not None and liveness.owner_alive(paths, j.owner):
            return ReleaseReport()
        _log.warning("recovering a %s lease of a dead owner", j.state.value)
        return release(paths)


def status(paths: Paths) -> Status:
    """Read-only summary for `aptus-lease status` and the doctor (no lock). JournalError for a
    journal that does not parse."""
    s = Status()
    j = journal.load(paths)
    if j is not None:
        s.state, s.owner, s.slots, s.generation = j.state, j.owner, len(j.slots), j.theme_generation
        s.failed = [r.id for r in j.slots if r.status == SlotStatus.FAILED]
        s.owner_alive = j.owner is not None and liveness.owner_alive(paths, j.owner)
    if paths.lease_conflicts.is_dir():
        s.conflicts = sum(1 for _ in paths.lease_conflicts.iterdir())
    return s


def held_by(paths: Paths, signature: str, pid: int | None = None) -> bool:
    """Whether a journal that is not `released` belongs to the session with `signature` (and
    `pid` when given): apply's lease mode, the guard's ownership check."""
    try:
        j = journal.load(paths)
    except JournalError:
        return False
    return (j is not None and j.state != State.RELEASED and j.owner is not None
            and j.owner.hyprland_signature == signature
            and (pid is None or j.owner.hyprland_pid == pid))


def holds(paths: Paths, signature: str) -> bool:
    """The session with `signature` holds the lease in state `held` (not taking, not half
    released): apply's lease mode, the environment import, `aptus-lease update`."""
    try:
        j = journal.load(paths)
    except JournalError:
        return False
    return (j is not None and j.state == State.HELD and j.owner is not None
            and j.owner.hyprland_signature == signature)


def save_conflict(paths: Paths, stamp: str, rec: SlotRecord) -> Path:
    """conflicts/<stamp>/<slot id>: what someone else wrote into a leased slot."""
    dest = paths.lease_conflicts / stamp / rec.id
    invariants.writable(paths, dest, kind="state")
    dest.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    atomic.write_bytes(dest, kinds.module(rec.kind).current(paths, rec), 0o600)
    return dest
