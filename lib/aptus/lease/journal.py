"""The lease journal (02-isolation §5.1, §5.2): ~/.local/state/aptus/lease/journal.json, the only
source of truth, written atomically under the lease flock before anything is modified.

States: taking → held → releasing → released (02 §5.3, §5.6). A slot's `before` is Noctalia's
state (kind-specific shape, see kinds/), its `after` the planned (pending) or written (held) aptus
paint, `after_prev` the paint of the previous generation while an update is in flight, so release
recognises aptus's own paint after a crash at any step.
"""
from __future__ import annotations

import dataclasses
import json
import os
import time
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any

from .. import atomic
from ..paths import Paths


class State(str, Enum):
    TAKING = "taking"          # before data recorded, slots being written
    HELD = "held"              # every slot carries aptus paint
    RELEASING = "releasing"    # restoring; stays here while a slot failed (recover retries)
    RELEASED = "released"      # moved to history/


class SlotKind(str, Enum):
    FILE = "file"
    INI = "ini-sections"
    DCONF = "dconf"


class SlotStatus(str, Enum):
    PENDING = "pending"        # before recorded, planned after recorded, maybe not written yet
    HELD = "held"              # aptus paint written
    RESTORED = "restored"      # Noctalia's state back (verified)
    FAILED = "failed"          # restore could not be verified (retried by recover)


@dataclass
class Owner:
    """Who holds the lease: alive ⇔ same boot, /proc/<pid> is Hyprland, its socket answers (§5.7)."""
    boot_id: str
    hyprland_pid: int
    hyprland_signature: str
    logind_session: str
    taken_at: str              # ISO 8601 with offset


@dataclass
class SlotRecord:
    """One leased item. `before`/`after` shapes by kind (02 §5.2):
    file:  before {exists, sha256, mode, size, link}, after {sha256}
    ini-sections: before {exists, mode, link, sections_sha256, sections: [{name, anchor, text}]},
                  after {sections_sha256}
    dconf: before {set, value}, after {value}
    `link` is readlink(path) ("" when path is not a symlink), for the doctor."""
    id: str                    # "<target>.<name>" (e.g. "gtk3.artifact", "dconf.color-scheme")
    kind: SlotKind
    target: str                # the targets.toml id of this slot
    reload: str = "none"       # that target's reload hook, kept here so release and recover do
                               # not depend on a manifest that may have changed since the take
    path: str = ""             # file / ini-sections: the configured path (expanded)
    write_path: str = ""       # the resolved file aptus writes (path with symlinks followed)
    key: str = ""              # dconf: the full key path
    sections: list[str] = field(default_factory=list)   # ini-sections: header globs
    write: bool = True         # False: recorded, never written (dconf gtk-theme)
    before: dict[str, Any] = field(default_factory=dict)
    after: dict[str, Any] = field(default_factory=dict)
    after_prev: dict[str, Any] | None = None
    status: SlotStatus = SlotStatus.PENDING
    error: str = ""            # last failure (failed slots)


@dataclass
class Journal:
    version: int = 1
    state: State = State.RELEASED
    owner: Owner | None = None
    theme_generation: int = 0
    slots: list[SlotRecord] = field(default_factory=list)
    released_at: str = ""      # ISO 8601, set when the state becomes released


HISTORY_KEEP = 10              # released journals kept in history/ (02 §5.1)


class JournalError(RuntimeError):
    """journal.json exists but cannot be read or parsed: nothing may act on it automatically."""


def now() -> str:
    """Local time, ISO 8601 with offset, seconds precision."""
    t = time.localtime()
    off = time.strftime("%z", t)
    return time.strftime("%Y-%m-%dT%H:%M:%S", t) + off[:3] + ":" + off[3:]


def to_dict(j: Journal) -> dict[str, Any]:
    """The JSON shape of 02 §5.2 (enums as their values)."""
    d = dataclasses.asdict(j)
    d["state"] = j.state.value
    for out, rec in zip(d["slots"], j.slots):
        out["kind"] = rec.kind.value
        out["status"] = rec.status.value
    return d


def from_dict(d: dict[str, Any]) -> Journal:
    """Inverse of to_dict; JournalError for an unknown version, state or slot kind."""
    if not isinstance(d, dict) or d.get("version") != 1:
        raise JournalError("unknown journal version")
    try:
        owner = Owner(**d["owner"]) if d.get("owner") else None
        slots = []
        for raw in d.get("slots", []):
            raw = dict(raw)
            raw["kind"] = SlotKind(raw["kind"])
            raw["status"] = SlotStatus(raw.get("status", "pending"))
            slots.append(SlotRecord(**raw))
        return Journal(version=1, state=State(d["state"]), owner=owner,
                       theme_generation=int(d.get("theme_generation", 0)), slots=slots,
                       released_at=str(d.get("released_at", "")))
    except (KeyError, TypeError, ValueError, AttributeError) as e:
        raise JournalError(f"the journal does not parse: {e}") from e


def load(paths: Paths) -> Journal | None:
    """The journal, None when there is none; JournalError when it is unreadable."""
    try:
        with open(paths.lease_journal, encoding="utf-8") as f:
            raw = json.load(f)
    except FileNotFoundError:
        return None
    except (OSError, ValueError) as e:
        raise JournalError(f"{paths.lease_journal}: {e}") from e
    return from_dict(raw)


def save(paths: Paths, j: Journal) -> None:
    """Write journal.json atomically (atomic.write_json: temp, fsync, rename, fsync dir)."""
    from . import invariants  # imported here: invariants imports this module
    invariants.check_journal(paths, j)
    invariants.check_save(load(paths), j)
    invariants.writable(paths, paths.lease_journal, kind="state")
    paths.lease.mkdir(mode=0o700, parents=True, exist_ok=True)
    atomic.write_json(paths.lease_journal, to_dict(j), 0o600)


def before_file(paths: Paths, slot_id: str) -> Path:
    """slots/<id>.before: Noctalia's bytes of a file slot, written at take."""
    return paths.lease_slots / f"{slot_id}.before"


def archive(paths: Paths, j: Journal) -> Path:
    """Write the released journal to history/<time>.json, remove journal.json and the slots/
    copies it referenced, keep the newest HISTORY_KEEP entries; returns the history file. Only a
    released journal whose slots are all restored is archived (invariants.check_journal)."""
    from . import invariants
    if j.state != State.RELEASED:
        invariants.fail(f"archiving a {j.state.value} journal")
    invariants.check_journal(paths, j)
    invariants.writable(paths, paths.lease_history, kind="state")
    paths.lease_history.mkdir(mode=0o700, parents=True, exist_ok=True)
    ns = time.time_ns()
    stamp = time.strftime("%Y%m%dT%H%M%S", time.localtime(ns // 10**9)) + f"-{ns % 10**9:09d}"
    dest = paths.lease_history / f"{stamp}.json"
    atomic.write_json(dest, to_dict(j), 0o600)
    for name in (paths.lease_journal, *(before_file(paths, s.id) for s in j.slots)):
        try:
            os.unlink(name)
        except FileNotFoundError:
            pass
    for old in sorted(paths.lease_history.glob("*.json"))[:-HISTORY_KEEP]:
        old.unlink(missing_ok=True)
    return dest


def last_released(paths: Paths) -> Journal | None:
    """The newest journal in history/ (the doctor compares slots against its `before`)."""
    for f in sorted(paths.lease_history.glob("*.json"), reverse=True):
        try:
            return from_dict(json.loads(f.read_text(encoding="utf-8")))
        except (OSError, ValueError, JournalError):
            continue
    return None


def slot(j: Journal, slot_id: str) -> SlotRecord | None:
    return next((s for s in j.slots if s.id == slot_id), None)
