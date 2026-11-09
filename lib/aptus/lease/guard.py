"""aptus-guard <hyprland-pid> <signature> (02 §7): a transient user service outside Hyprland's
process tree, started by aptus-session *before* the lease is taken (no lease without a guard).
Waits on Hyprland's pidfd (readable when Hyprland exits) or SIGTERM from the user manager
(logout, shutdown, `aptus-session stop`), then releases the lease if this session owns it, runs
the release hooks, unsets the variables the session imported and exits 0; units bound to it
(BindsTo) stop with it. While waiting it also
- polls logind's record of this user (/run/systemd/users/<uid>, 1 s): when another graphical
  session opens while the lease is held (Umbriel logged in on another VT), it releases at once
  and the session continues scope-only (02 §7 exit matrix);
- retries bakes queued until their app closed (30 s tick; opt-in, D-02).
Writes <runtime>/guard.state for the shell (07 §7)."""
from __future__ import annotations

from collections.abc import Callable, Sequence
from enum import Enum

from ..paths import Paths
from .ops import ReleaseReport


class GuardState(str, Enum):
    OK = "ok"                  # watching (lease or scope-only: session.json says which)
    SCOPE_ONLY = "scope-only"  # released mid-session because another session opened
    FAILED = "failed"          # a release failed (recover retries at the next login)
    RELEASED = "released"      # Hyprland ended (or SIGTERM) and the lease was given back


TICK = 30.0                    # seconds between bake retries while waiting
POLL = 1.0                     # seconds between checks of logind's user record
UNIT = "aptus-guard"           # the transient unit name (systemd-run --unit)
# Unset on release (02 §6), each only while it still holds aptus's value: XCURSOR_SIZE stays
# (Umbriel uses 24 too). Values: APTUS_SESSION=1, QT_QPA_PLATFORMTHEME=qt6ct, the cursor theme
# and size of tokens.json.
UNSET = ("APTUS_SESSION", "QT_QPA_PLATFORMTHEME", "XCURSOR_THEME", "HYPRCURSOR_SIZE")


def write_state(paths: Paths, state: GuardState, detail: str = "") -> None:
    """<runtime>/guard.state: the state word, then the detail on a second line (atomic)."""
    # TODO(S2): atomic.write_text(paths.guard_state, f"{state.value}\n{detail}\n").
    raise NotImplementedError


def pidfd(pid: int) -> int:
    """os.pidfd_open(pid); ProcessLookupError when it is already gone."""
    # TODO(S2): os.pidfd_open.
    raise NotImplementedError


def wait(fd: int, stop_fd: int, poll: float, on_poll: Callable[[], bool]) -> str:
    """Block until the pidfd is readable ("exited"), SIGTERM wrote to `stop_fd` ("stopped"), or
    `on_poll` (called every `poll` seconds) returns True ("other-session")."""
    # TODO(S2): select.poll on both fds with a timeout to the next poll; on_poll in between.
    raise NotImplementedError


def other_session_opened(paths: Paths, signature: str, last_mtime: list[float]) -> bool:
    """True when logind's user record changed since the last call and preflight now lists another
    open graphical session while this session holds the lease."""
    # TODO(S2): stat paths.logind_user (mtime into last_mtime[0]); unchanged → False; else
    #   ops.held_by(signature) and preflight.others(preflight.sessions(), own id).
    raise NotImplementedError


def release_if_ours(paths: Paths, pid: int, signature: str) -> ReleaseReport | None:
    """ops.release when a journal that is not `released` belongs to `pid` and `signature`
    (taking, held or releasing); else None (scope-only session, or another owner)."""
    # TODO(S2): ops.held_by(paths, signature, pid) → ops.release(paths).
    raise NotImplementedError


def unset_environment(paths: Paths) -> list[str]:
    """`systemctl --user unset-environment` of the UNSET variables that still hold aptus's value in
    `systemctl --user show-environment`; returns the names unset. Called only after this
    session's own lease was released (scope-only sessions never imported anything)."""
    # TODO(S2): system.run show-environment, parse NAME=value, compare with aptus's values;
    #   invariants.check_unset(names, UNSET) before the unset-environment call.
    raise NotImplementedError


def run(paths: Paths, pid: int, signature: str) -> int:
    """Watch Hyprland `pid`; on exit or SIGTERM: release_if_ours, the release hooks
    (hooks.run_reloads), unset_environment, guard.state, return 0 (1 when the release failed).
    On another session opening: the same release, guard.state scope-only, and keep watching."""
    # TODO(S2): self-pipe (signal.set_wakeup_fd) for SIGTERM/SIGINT; write_state ok; pidfd
    #   (gone → treat as exited); loop wait(); bake retry every TICK inside on_poll.
    raise NotImplementedError


def main(argv: Sequence[str]) -> int:
    """aptus-guard <hyprland-pid> <signature>; refuses an unsafe HOME and the real session's
    signature under test."""
    # TODO(S2): log.setup("guard"); parse two args (2 on misuse); paths.require_safe_home;
    #   hypr.check_allowed(signature); run.
    raise NotImplementedError
