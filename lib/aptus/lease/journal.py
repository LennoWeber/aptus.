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
from typing import Any


class State(str, Enum):
    TAKING = "taking"          # before data recorded, slots being written
    HELD = "held"              # every slot carries aptus paint
    RELEASING = "releasing"    # restoring; stays here while a slot failed (recover retries)
    RELEASED = "released"      # moved to history/


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
    file:  before {exists, sha256, mode, size}, after {sha256}
    ini-sections: before {exists, sections_sha256, sections: [{name, anchor, text}]},
                  after {sections_sha256}
    dconf: before {set, value}, after {value}"""
    id: str                    # "<target>.<name>" (e.g. "gtk3.artifact", "dconf.color-scheme")
    kind: str                  # "file" | "ini-sections" | "dconf"
    target: str                # the targets.toml id whose reload hook runs for this slot
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
