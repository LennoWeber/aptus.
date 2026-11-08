"""`aptus-supervise`: runs and restarts the shell (07-architecture §10)."""
from __future__ import annotations

import glob
import logging
import os
import shutil
import signal
import subprocess
import time
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path

from . import hypr
from .log import setup
from .paths import Paths, get


@dataclass(frozen=True)
class RestartPolicy:
    delays: tuple[float, ...] = (0.5, 1.0, 2.0)   # after the 1st, 2nd, 3rd crash
    crash_window: float = 10.0                    # three crashes within this many seconds …
    crash_limit: int = 3                          # … switch to the slow retry
    slow_retry: float = 30.0

    def __post_init__(self) -> None:
        # Invariant: a policy that could spin (a zero delay or window) or has no limit is a bug.
        if (not self.delays or any(d <= 0 for d in self.delays) or self.crash_limit < 1
                or self.crash_window <= 0 or self.slow_retry <= 0):
            raise ValueError(f"supervise invariant: bad restart policy {self}")


@dataclass
class CrashLog:
    times: list[float]                            # monotonic times of recent crashes
    streak: int = 0                               # crashes since the last run of ≥ crash_window s
    started: float = 0.0                          # monotonic start of the current run


def shell_command(paths: Paths) -> list[str]:
    """qs -p <repo>/shell --no-duplicate."""
    return ["qs", "-p", str(paths.shell), "--no-duplicate"]


def shell_env(paths: Paths, env: Mapping[str, str]) -> dict[str, str]:
    """The shell's environment: `env` plus APTUS_DEV=1 while <runtime>/dev exists (aptus dev)."""
    out = dict(env)
    if paths.dev_flag.exists():
        out["APTUS_DEV"] = "1"
    else:
        out.pop("APTUS_DEV", None)       # `aptus dev off` must win over an inherited value
    return out


def next_delay(policy: RestartPolicy, crashes: CrashLog, now: float) -> float:
    """Record a crash at `now` and return the wait before the next start: 0.5, 1, 2 s along a
    streak of short runs (a run of ≥ crash_window s starts a new streak), and the slow retry once
    crash_limit crashes fall inside crash_window (07 §10)."""
    if crashes.streak < 0 or now < crashes.started:
        raise ValueError("supervise invariant: negative streak or a crash before the run started")
    if now - crashes.started >= policy.crash_window:
        crashes.streak = 0
    crashes.streak += 1
    crashes.times[:] = [t for t in crashes.times if now - t <= policy.crash_window] + [now]
    if len(crashes.times) >= policy.crash_limit:
        return policy.slow_retry
    return policy.delays[min(crashes.streak, len(policy.delays)) - 1]


def crashed_out(policy: RestartPolicy, crashes: CrashLog, now: float) -> bool:
    """Whether the crash limit was just reached (lock fallback + notify)."""
    recent = [t for t in crashes.times if now - t <= policy.crash_window]
    return len(recent) == policy.crash_limit


def on_crash_limit(paths: Paths) -> None:
    """hyprlock when the locked marker exists, then the Hyprland notification of 07 §10."""
    log = logging.getLogger("aptus.supervise")
    if paths.locked_marker.exists():
        running = False
        for comm in glob.glob("/proc/[0-9]*/comm"):
            try:
                running = running or Path(comm).read_text().strip() == "hyprlock"
            except OSError:      # the process ended meanwhile
                pass
        if running:
            log.warning("crash limit while locked: hyprlock is already running")
        else:
            # The aptus hyprlock.conf exists only after the first theme render (S2).
            conf = ["-c", str(paths.hyprlock_conf)] if paths.hyprlock_conf.exists() else []
            log.warning("crash limit while locked: starting hyprlock %s", " ".join(conf))
            try:
                subprocess.Popen(["hyprlock", *conf], stdin=subprocess.DEVNULL,
                                 start_new_session=True)
            except OSError as e:
                log.error("cannot start hyprlock: %s", e)
    try:
        hypr.notify("aptus keeps crashing — Super+Return opens a terminal, `aptus logs` shows why",
                    10000)
    except hypr.HyprError as e:
        log.error("cannot show the crash notification: %s", e)


def run(paths: Paths, policy: RestartPolicy, command: Sequence[str]) -> int:
    """Run and restart until SIGTERM/SIGINT; an exit 0 with the restart flag restarts at once,
    an exit 0 without it ends the supervisor."""
    log = logging.getLogger("aptus.supervise")
    crashes = CrashLog(times=[])
    state: dict = {"stop": False, "child": None}

    def forward(signum: int, _frame: object) -> None:
        state["stop"] = True
        child = state["child"]
        if child is not None and child.poll() is None:
            child.send_signal(signum)

    previous = {sig: signal.signal(sig, forward) for sig in (signal.SIGTERM, signal.SIGINT)}
    paths.runtime.mkdir(parents=True, exist_ok=True, mode=0o700)
    paths.restart_flag.unlink(missing_ok=True)       # a stale request from an earlier session
    try:
        while not state["stop"]:
            sink, logger = None, None
            if paths.test:
                sink = open(paths.home / "aptus-shell.log", "ab")
            elif shutil.which("systemd-cat"):
                logger = subprocess.Popen(["systemd-cat", "-t", "aptus-shell"],
                                          stdin=subprocess.PIPE)
                sink = logger.stdin
            try:
                log.info("starting the shell: %s", " ".join(command))
                crashes.started = time.monotonic()
                state["child"] = subprocess.Popen(list(command), env=shell_env(paths, os.environ),
                                                  stdin=subprocess.DEVNULL, stdout=sink,
                                                  stderr=sink)
            except OSError as e:
                log.error("cannot start the shell: %s", e)
                state["child"] = None
                rc = 127
            finally:
                if sink is not None:
                    sink.close()      # the shell holds its own copy; the logger ends with it
            if state["child"] is not None:
                rc = state["child"].wait()
            if logger is not None:
                logger.wait()
            if state["stop"]:
                break
            if rc == 0 and paths.restart_flag.exists():
                paths.restart_flag.unlink(missing_ok=True)
                log.info("restart requested")
                continue
            if rc == 0:
                log.info("the shell exited normally; the supervisor ends")
                break
            now = time.monotonic()
            delay = next_delay(policy, crashes, now)
            log.warning("the shell exited with %s; restarting in %g s", rc, delay)
            if crashed_out(policy, crashes, now):
                on_crash_limit(paths)
            end = time.monotonic() + delay
            while not state["stop"] and time.monotonic() < end:
                time.sleep(min(0.1, max(0.0, end - time.monotonic())))
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)
    return 0


def main(argv: Sequence[str]) -> int:
    setup("supervise")
    p = get()
    return run(p, RestartPolicy(), list(argv) or shell_command(p))
