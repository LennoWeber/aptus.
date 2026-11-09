"""Owner liveness (02 §5.7); recovery itself is ops.recover. Recovery runs from
aptus-recover.service when the user manager starts and at the start of every aptus session.

    owner alive ⇔ owner.boot_id == current boot_id
                ∧ /proc/<hyprland_pid> exists ∧ /proc/<hyprland_pid>/comm == "Hyprland"
                ∧ $XDG_RUNTIME_DIR/hypr/<signature>/.socket.sock accepts a connection

Imports nothing of ops (ops imports this module).
"""
from __future__ import annotations

from pathlib import Path

from ..paths import Paths
from .journal import Owner


def socket_accepts(path: Path, timeout: float = 0.5) -> bool:
    """Whether a Unix stream socket at `path` accepts a connection (closed right away)."""
    # TODO(S2): socket.AF_UNIX connect with timeout; False on OSError.
    raise NotImplementedError


def owner_alive(paths: Paths, who: Owner) -> bool:
    """The formula above; under APTUS_TEST=1 the real session's signature counts as dead
    (hypr.check_allowed), so a test can never mistake Lenno's Hyprland for its owner."""
    # TODO(S2): system.boot_id(); system.comm(pid) == "Hyprland"; hypr.check_allowed (Refused →
    #   dead); socket_accepts(hypr.socket_path(paths, signature)).
    raise NotImplementedError
