"""aptus-guard <hyprland-pid> <signature> (02 §7): a transient user service outside Hyprland's
process tree. Waits on Hyprland's pidfd (readable when Hyprland exits) or SIGTERM from the user
manager (logout, shutdown, `aptus-session stop`), then releases the lease it owns, unsets the
scoped variables in the systemd user environment and exits 0; units bound to it (BindsTo) stop
with it. While waiting, a 30 s tick retries bakes queued until their app closed (opt-in, D-02).
Writes <runtime>/guard.state for the shell (07 §7)."""
from __future__ import annotations

from collections.abc import Callable, Sequence
from enum import Enum


class GuardState(str, Enum):
    OK = "ok"                  # watching, the lease is held by this session
    SCOPE_ONLY = "scope-only"  # watching, no lease (scope-only session): nothing to release
    FAILED = "failed"          # a release failed (recover retries at the next login)
    RELEASED = "released"      # Hyprland ended (or SIGTERM) and the lease was given back

from ..paths import Paths
from .ops import ReleaseReport

TICK = 30.0                    # seconds between bake retries while waiting
UNIT = "aptus-guard"           # the transient unit name (systemd-run --unit)
# Unset on release (02 §6): XCURSOR_SIZE stays (Umbriel uses 24 too).
UNSET = ("APTUS_SESSION", "QT_QPA_PLATFORMTHEME", "XCURSOR_THEME")


def write_state(paths: Paths, state: GuardState, detail: str = "") -> None:
    """<runtime>/guard.state: the state word, then the detail on a second line (atomic)."""
    raise NotImplementedError


def pidfd(pid: int) -> int:
    """os.pidfd_open(pid); ProcessLookupError when it is already gone."""
    raise NotImplementedError


def wait(fd: int, stop_fd: int, tick: float, on_tick: Callable[[], None]) -> str:
    """Block until the pidfd is readable ("exited") or SIGTERM wrote to `stop_fd` ("stopped"),
    calling `on_tick` every `tick` seconds meanwhile."""
    raise NotImplementedError


def release_if_ours(paths: Paths, pid: int, signature: str) -> ReleaseReport | None:
    """ops.release only when the journal is held by `pid` and `signature`; else None."""
    raise NotImplementedError


def unset_environment(paths: Paths) -> bool:
    """`systemctl --user unset-environment` of UNSET; False when it failed or was skipped."""
    raise NotImplementedError


def run(paths: Paths, pid: int, signature: str) -> int:
    """Watch Hyprland `pid`; on exit or SIGTERM: release, run the release hooks, unset the
    environment, write guard.state, return 0 (1 when the release failed)."""
    raise NotImplementedError


def main(argv: Sequence[str]) -> int:
    """aptus-guard <hyprland-pid> <signature>."""
    raise NotImplementedError
