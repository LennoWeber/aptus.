"""The lease journal (02-isolation §5.1, §5.2): ~/.local/state/aptus/lease/journal.json, the only
source of truth, written atomically under the lease flock before anything is modified.

States: taking → held → releasing → released (02 §5.3, §5.6). A slot's `before` is Noctalia's
state (kind-specific shape, see kinds/), its `after` the planned (pending) or written (held) aptus
paint, `after_prev` the paint of the previous generation while an update is in flight, so release
recognises aptus's own paint after a crash at any step.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any

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
    # TODO(S2): local time with a ±HH:MM offset (time.strftime %z, colon inserted).
    raise NotImplementedError


def to_dict(j: Journal) -> dict[str, Any]:
    """The JSON shape of 02 §5.2 (enums as their values)."""
    # TODO(S2): dataclasses.asdict; enums to their values.
    raise NotImplementedError


def from_dict(d: dict[str, Any]) -> Journal:
    """Inverse of to_dict; JournalError for an unknown version, state or slot kind."""
    # TODO(S2): version 1 only; State/SlotKind/SlotStatus from values; Owner and SlotRecord from
    #   their fields; any KeyError/TypeError/ValueError → JournalError.
    raise NotImplementedError


def load(paths: Paths) -> Journal | None:
    """The journal, None when there is none; JournalError when it is unreadable."""
    # TODO(S2): missing → None; json.load + from_dict; OSError/ValueError → JournalError.
    raise NotImplementedError


def save(paths: Paths, j: Journal) -> None:
    """Write journal.json atomically (atomic.write_json: temp, fsync, rename, fsync dir)."""
    # TODO(S2): mkdir lease/ (0700); atomic.write_json(paths.lease_journal, to_dict(j), 0o600).
    from . import invariants  # imported here: invariants imports this module
    invariants.check_journal(paths, j)
    raise NotImplementedError


def archive(paths: Paths, j: Journal) -> Path:
    """Write the released journal to history/<time>.json, remove journal.json and the slots/
    copies it referenced, keep the newest HISTORY_KEEP entries; returns the history file."""
    # TODO(S2): write history/<stamp>.json (0600), unlink journal.json and slots/<id>.before of its
    #   slots, keep the newest HISTORY_KEEP files.
    raise NotImplementedError


def last_released(paths: Paths) -> Journal | None:
    """The newest journal in history/ (the doctor compares slots against its `before`)."""
    # TODO(S2): newest history/*.json through from_dict; None when none parses.
    raise NotImplementedError


def slot(j: Journal, slot_id: str) -> SlotRecord | None:
    # TODO(S2): linear search by id.
    raise NotImplementedError
