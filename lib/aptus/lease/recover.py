"""Owner liveness and recovery (02 §5.7). Recovery runs from aptus-recover.service when the user
manager starts and at the start of every aptus session; it acts only when the journal says a lease
is taking/held/releasing and the owner is dead, and then performs release (§5.6). It never takes.

    owner alive ⇔ owner.boot_id == current boot_id
                ∧ /proc/<hyprland_pid> exists ∧ /proc/<hyprland_pid>/comm == "Hyprland"
                ∧ $XDG_RUNTIME_DIR/hypr/<signature>/.socket.sock accepts a connection
"""
from __future__ import annotations

from pathlib import Path

from ..paths import Paths
from .journal import Owner
from .ops import ReleaseReport


def socket_accepts(path: Path, timeout: float = 0.5) -> bool:
    """Whether a Unix stream socket at `path` accepts a connection (closed right away)."""
    raise NotImplementedError


def owner_alive(paths: Paths, who: Owner) -> bool:
    """The formula above; under APTUS_TEST=1 the real session's signature counts as dead
    (hypr.check_allowed), so a test can never mistake Lenno's Hyprland for its owner."""
    raise NotImplementedError


def recover(paths: Paths) -> ReleaseReport:
    """Under the flock: no journal, `released`, or a live owner → nothing (acted false); else
    release (ops.release) and run the reload hooks of what it restored. A journal that does not
    parse is left alone and reported (JournalError): only a human may decide then."""
    raise NotImplementedError
