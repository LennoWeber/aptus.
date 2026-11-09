"""aptus-guard <hyprland-pid> <signature> (02 §7): a transient user service outside Hyprland's
process tree. Waits on Hyprland's pidfd (readable when Hyprland exits) or SIGTERM from the user
manager (logout, shutdown, `aptus-session stop`), then releases the lease it owns, unsets the
scoped variables in the systemd user environment and exits 0; units bound to it (BindsTo) stop
with it. While waiting, a 30 s tick retries bakes queued until their app closed (opt-in, D-02).
Writes <runtime>/guard.state for the shell (07 §7)."""
from __future__ import annotations

from enum import Enum


class GuardState(str, Enum):
    OK = "ok"                  # watching, the lease is held by this session
    SCOPE_ONLY = "scope-only"  # watching, no lease (scope-only session): nothing to release
    FAILED = "failed"          # a release failed (recover retries at the next login)
    RELEASED = "released"      # Hyprland ended (or SIGTERM) and the lease was given back
