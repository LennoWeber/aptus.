"""Owner liveness (02 §5.7); recovery itself is ops.recover. Recovery runs from
aptus-recover.service when the user manager starts and at the start of every aptus session.

    owner alive ⇔ owner.boot_id == current boot_id
                ∧ /proc/<hyprland_pid> exists ∧ /proc/<hyprland_pid>/comm == "Hyprland"
                ∧ $XDG_RUNTIME_DIR/hypr/<signature>/.socket.sock accepts a connection

Imports nothing of ops (ops imports this module).
"""
from __future__ import annotations

import socket
from pathlib import Path

from .. import hypr
from ..paths import Paths
from . import system
from .journal import Owner


def socket_accepts(path: Path, timeout: float = 0.5) -> bool:
    """Whether a Unix stream socket at `path` accepts a connection (closed right away)."""
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(timeout)
    try:
        s.connect(str(path))
        return True
    except OSError:
        return False
    finally:
        s.close()


def owner_alive(paths: Paths, who: Owner) -> bool:
    """The formula above; under APTUS_TEST=1 the real session's signature counts as dead
    (hypr.check_allowed), so a test can never mistake Lenno's Hyprland for its owner."""
    try:
        if who.boot_id != system.boot_id():
            return False
    except OSError:
        return False
    if system.comm(who.hyprland_pid) != "Hyprland":
        return False
    try:
        hypr.check_allowed(who.hyprland_signature)
    except hypr.RefusedInstance:
        return False
    return socket_accepts(hypr.socket_path(paths, who.hyprland_signature))
