"""aptus-guard <hyprland-pid> <signature> (02 §7): a transient user service outside Hyprland's
process tree, started by aptus-session *before* the lease is taken (no lease without a guard).
Waits on Hyprland's pidfd (readable when Hyprland exits) or SIGTERM from the user manager
(logout, shutdown, `aptus-session stop`), then unsets the variables the session imported,
releases the lease if this session owns it (retried when it raises), runs the release hooks and
exits 0; units bound to it (BindsTo) stop with it. While waiting it also
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
RETRIES = 4                    # attempts of a release that raised (a busy lock, a full disk)
BACKOFF = 2.0                  # seconds between those attempts (all of them fit in the 90 s stop)
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


READY_TIMEOUT = 5.0            # seconds aptus-session waits for a new guard's "ok"


def active(paths: Paths) -> bool:
    """The guard's unit is active (`systemctl --user is-active`)."""
    r = system.run(paths, ["systemctl", "--user", "is-active", "--quiet", f"{UNIT}.service"])
    return r.ok


def ready(paths: Paths) -> bool:
    """The guard watches: guard.state says `ok` (written once its pidfd is open and its signal
    handling is set up) and the unit is active."""
    try:
        word = paths.guard_state.read_text(encoding="utf-8").split("\n", 1)[0]
    except OSError:
        return False
    return word == GuardState.OK.value and active(paths)


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
    """True when logind's user record changed since the last conclusive check (inode, mtime)
    and another open graphical session is listed while this session holds the lease. Its own
    logind session is the journal owner's. A change is only used up by a check that listed the
    sessions while the lease was held: one that lands before the take finished, or while
    loginctl fails (the lease stays held, logged once), is checked again at the next poll."""
    try:
        st = os.stat(paths.logind_user)
        key: Any = (st.st_ino, st.st_mtime_ns)
    except OSError:
        key = None
    if key == last[0]:
        return False
    try:
        j = journal.load(paths)
    except journal.JournalError:
        return False
    if j is None or j.owner is None or not ops.held_by(paths, signature, pid):
        return False
    listed = preflight.sessions(paths)
    if listed is None:
        if last[0] != ("retry", key):
            _log.warning("cannot list login sessions; the lease stays held")
        last[0] = ("retry", key)
        return False
    last[0] = key
    found = preflight.others(listed, j.owner.logind_session)
    if found:
        _log.warning("another session opened (%s): releasing", ", ".join(s.id for s in found))
    return bool(found)


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
    if not r.ok:
        _log.warning("systemctl --user show-environment failed: %s", r.stderr.strip() or "skipped")
        return []
    env = dict(line.split("=", 1) for line in r.stdout.splitlines() if "=" in line)
    ours = aptus_values(paths)
    names = [n for n in UNSET if env.get(n) == ours[n]]
    if not names:
        return []
    invariants.check_unset(names, UNSET)
    r = system.run(paths, ["systemctl", "--user", "unset-environment", *names])
    if not r.ok:
        _log.warning("unset-environment %s failed: %s", names, r.stderr.strip())
        return []
    return names


def after_release(paths: Paths, report: ReleaseReport, signature: str) -> GuardState:
    """Once a release acted: the environment unset (also when a slot failed: Umbriel must not
    get aptus's variables because of one slot), then the release hooks; the resulting state.
    Never raises: a step that fails is logged and the next one still runs (the release is done,
    the journal is gone, so nothing would repeat these steps)."""
    if not report.acted:
        return GuardState.RELEASED
    for what, step in (("unset-environment", lambda: unset_environment(paths)),
                       ("the release hooks", lambda: hooks.run_reloads(paths, report.reloads,
                                                                       signature))):
        try:
            step()
        except Exception as e:  # noqa: BLE001 - the slots are back whatever a hook does
            _log.error("%s failed after the release: %s: %s", what, type(e).__name__, e)
    if report.failed:
        _log.error("release failed for %s; recover retries at the next login",
                   ", ".join(sorted(report.failed)))
        return GuardState.FAILED
    return GuardState.RELEASED


def give_back(paths: Paths, pid: int, signature: str) -> GuardState:
    """The guard's release: the environment first while this session holds the lease (a guard
    killed half-way then leaves no variable behind; recover restores the slots), then ops.release
    of the journal when it belongs to `pid` and `signature` (taking, held or releasing; checked
    under the flock; `acted` false for a scope-only session or another owner), then after_release
    once with its report. A release that raises (the lease
    lock busy for 10 s, a full disk) is tried RETRIES times, BACKOFF apart; then FAILED (recover
    retries later). Only the release is retried: a retry after it succeeded would find no
    journal and skip the hooks."""
    for attempt in range(1, RETRIES + 1):
        try:
            if ops.held_by(paths, signature, pid):
                unset_environment(paths)
            report = ops.release(paths, expect=(signature, pid))
        except Exception as e:  # noqa: BLE001 - the guard keeps trying, it never just dies
            _log.warning("release attempt %d of %d failed: %s: %s", attempt, RETRIES,
                         type(e).__name__, e)
            if attempt < RETRIES:
                time.sleep(BACKOFF)
            continue
        return after_release(paths, report, signature)
    return GuardState.FAILED


def _stop_pipe() -> int:
    r, w = os.pipe2(os.O_NONBLOCK | os.O_CLOEXEC)
    signal.set_wakeup_fd(w)
    for s in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(s, lambda *_: None)
    return r


def run(paths: Paths, pid: int, signature: str) -> int:
    """Watch Hyprland `pid`; on exit or SIGTERM: give_back (environment, release
    with retries, hooks), guard.state, return 0 (1 when the release failed).
    On another session opening: the same release, guard.state scope-only, and keep watching."""
    stop = _stop_pipe()
    try:
        fd: int | None = os.pidfd_open(pid)
    except ProcessLookupError:
        fd = None
    if fd is not None:
        write_state(paths, GuardState.OK)          # aptus-session takes the lease only after this
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
        state = give_back(paths, pid, signature)
        write_state(paths, GuardState.SCOPE_ONLY if state == GuardState.RELEASED else state,
                    preflight.NOTICE_OTHER_SESSION)
    _log.info("Hyprland %d %s: releasing", pid, why)
    state = give_back(paths, pid, signature)
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
