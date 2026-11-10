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

import contextlib
import json
import logging
import os
import select
import signal
import sys
import time
from collections.abc import Callable, Sequence
from enum import Enum
from typing import Any

from .. import atomic, hypr, log
from .. import paths as paths_mod
from ..paths import Paths
from ..theme import hooks
from . import invariants, journal, ops, preflight, system
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

_log = logging.getLogger("aptus.guard")


def write_state(paths: Paths, state: GuardState, detail: str = "") -> None:
    """<runtime>/guard.state: the state word, then the detail on a second line (atomic)."""
    invariants.writable(paths, paths.guard_state, kind="state")
    paths.make_runtime()
    atomic.write_text(paths.guard_state, f"{state.value}\n{detail}\n", 0o644)


def pidfd(pid: int) -> int:
    """os.pidfd_open(pid); ProcessLookupError when it is already gone."""
    return os.pidfd_open(pid)


def wait(fd: int, stop_fd: int, poll: float, on_poll: Callable[[], bool]) -> str:
    """Block until the pidfd is readable ("exited"), SIGTERM wrote to `stop_fd` ("stopped"), or
    `on_poll` (called every `poll` seconds) returns True ("other-session")."""
    p = select.poll()
    p.register(fd, select.POLLIN)
    p.register(stop_fd, select.POLLIN)
    while True:
        ready = {f for f, _ in p.poll(int(poll * 1000))}
        if fd in ready:
            return "exited"
        if stop_fd in ready:
            with contextlib.suppress(OSError):
                os.read(stop_fd, 64)
            return "stopped"
        if on_poll():
            return "other-session"


def other_session_opened(paths: Paths, signature: str, pid: int, last: list[Any]) -> bool:
    """True when logind's user record changed since the last call (inode, mtime) and another
    open graphical session is listed while this session holds the lease. Its own logind session
    is the journal owner's. A failing loginctl keeps the lease (logged)."""
    try:
        st = os.stat(paths.logind_user)
        key: Any = (st.st_ino, st.st_mtime_ns)
    except OSError:
        key = None
    if key == last[0]:
        return False
    last[0] = key
    try:
        j = journal.load(paths)
    except journal.JournalError:
        return False
    if j is None or j.owner is None or not ops.held_by(paths, signature, pid):
        return False
    listed = preflight.sessions(paths)
    if listed is None:
        _log.warning("cannot list login sessions; the lease stays held")
        return False
    found = preflight.others(listed, j.owner.logind_session)
    if found:
        _log.warning("another session opened (%s): releasing", ", ".join(s.id for s in found))
    return bool(found)


def release_if_ours(paths: Paths, pid: int, signature: str) -> ReleaseReport:
    """ops.release of the journal when it belongs to `pid` and `signature` (taking, held or
    releasing; checked under the flock); `acted` false for a scope-only session or another
    owner."""
    return ops.release(paths, expect=(signature, pid))


def aptus_values(paths: Paths) -> dict[str, str]:
    """The values aptus imports (hypr/env.lua): only these are ever unset."""
    try:
        with open(paths.tokens, encoding="utf-8") as f:
            cursor = json.load(f)["cursor"]
    except (OSError, ValueError, KeyError):
        cursor = {"theme": "Adwaita", "size": 24}
    return {"APTUS_SESSION": "1", "QT_QPA_PLATFORMTHEME": "qt6ct",
            "XCURSOR_THEME": str(cursor["theme"]), "HYPRCURSOR_SIZE": str(cursor["size"])}


def unset_environment(paths: Paths) -> list[str]:
    """`systemctl --user unset-environment` of the UNSET variables that still hold aptus's value in
    `systemctl --user show-environment`; returns the names unset. Called only after this
    session's own lease was released (scope-only sessions never imported anything)."""
    r = system.run(paths, ["systemctl", "--user", "show-environment"])
    if r.skipped or r.code != 0:
        _log.warning("systemctl --user show-environment failed: %s", r.stderr.strip() or "skipped")
        return []
    env = dict(line.split("=", 1) for line in r.stdout.splitlines() if "=" in line)
    ours = aptus_values(paths)
    names = [n for n in UNSET if env.get(n) == ours[n]]
    if not names:
        return []
    invariants.check_unset(names, UNSET)
    r = system.run(paths, ["systemctl", "--user", "unset-environment", *names])
    if r.skipped or r.code != 0:
        _log.warning("unset-environment %s failed: %s", names, r.stderr.strip())
        return []
    return names


def after_release(paths: Paths, report: ReleaseReport, signature: str) -> GuardState:
    """The release hooks and the environment, once a release acted; the resulting state."""
    if not report.acted:
        return GuardState.RELEASED
    hooks.run_reloads(paths, report.reloads, signature)
    if report.failed:
        _log.error("release failed for %s; recover retries at the next login",
                   ", ".join(sorted(report.failed)))
        return GuardState.FAILED
    unset_environment(paths)
    return GuardState.RELEASED


def _stop_pipe() -> int:
    r, w = os.pipe2(os.O_NONBLOCK | os.O_CLOEXEC)
    signal.set_wakeup_fd(w)
    for s in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(s, lambda *_: None)
    return r


def run(paths: Paths, pid: int, signature: str) -> int:
    """Watch Hyprland `pid`; on exit or SIGTERM: release_if_ours, the release hooks
    (hooks.run_reloads), unset_environment, guard.state, return 0 (1 when the release failed).
    On another session opening: the same release, guard.state scope-only, and keep watching."""
    stop = _stop_pipe()
    write_state(paths, GuardState.OK)
    try:
        fd: int | None = pidfd(pid)
    except ProcessLookupError:
        fd = None
    last: list[Any] = [None]
    next_tick = [time.monotonic() + TICK]

    def on_poll() -> bool:
        if time.monotonic() >= next_tick[0]:
            next_tick[0] = time.monotonic() + TICK
            try:
                hooks.retry_queued(paths)
            except Exception as e:  # noqa: BLE001 - a bake never stops the guard
                _log.warning("bake retry failed: %s", e)
        return other_session_opened(paths, signature, pid, last)

    why = "exited"
    while fd is not None:
        why = wait(fd, stop, POLL, on_poll)
        if why != "other-session":
            break
        state = after_release(paths, release_if_ours(paths, pid, signature), signature)
        write_state(paths, GuardState.SCOPE_ONLY if state == GuardState.RELEASED else state,
                    preflight.NOTICE_OTHER_SESSION)
    _log.info("Hyprland %d %s: releasing", pid, why)
    state = after_release(paths, release_if_ours(paths, pid, signature), signature)
    write_state(paths, state)
    return 1 if state == GuardState.FAILED else 0


def main(argv: Sequence[str]) -> int:
    """aptus-guard <hyprland-pid> <signature>; refuses an unsafe HOME and the real session's
    signature under test."""
    args = list(argv)
    if len(args) != 2 or not args[0].isdigit() or not args[1]:
        print("usage: aptus-guard <hyprland-pid> <signature>", file=sys.stderr)
        return 2
    paths = paths_mod.get()
    try:                                  # before the logs: under test they go to $HOME
        paths_mod.require_safe_home(paths)
    except paths_mod.UnsafeHome as e:
        print(f"aptus-guard: refusing: {e}", file=sys.stderr)
        return 3
    logger = log.setup("guard")
    log.setup("lease", "aptus-guard")
    log.setup("theme", "aptus-guard")
    try:
        hypr.check_allowed(args[1])
    except hypr.HyprError as e:
        logger.error("refusing: %s", e)
        return 3
    try:
        return run(paths, int(args[0]), args[1])
    except Exception:
        logger.exception("the guard failed; recover releases at the next login")
        write_state(paths, GuardState.FAILED, "the guard failed")
        return 1
