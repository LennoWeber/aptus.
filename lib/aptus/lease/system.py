"""Everything the lease, the guard and the theme hooks do outside their own files: external tools
(dconf, systemctl, systemd-run, loginctl, dbus-send, tmux, nvim, pywalfox, spicetify, bat) and
signals to processes.

Under APTUS_TEST=1 a tool comes only from $HOME/.aptus-test/bin (a fake that records its calls);
without a fake the call is skipped and reported as skipped, never run for real. Signals go only to
processes whose environment carries the given Hyprland signature, and under test also this HOME.
"""
from __future__ import annotations

import logging
import os
import shutil
import signal
import subprocess
from collections.abc import Sequence
from dataclasses import dataclass, field

from .. import hypr
from ..paths import Paths


@dataclass
class ToolResult:
    argv: list[str]
    code: int = 0
    stdout: str = ""
    stderr: str = ""
    skipped: bool = False      # no such tool (or no fake under test): nothing ran
    timed_out: bool = False


@dataclass(frozen=True)
class Proc:
    pid: int
    comm: str
    env: dict[str, str] = field(default_factory=dict, compare=False, hash=False)


# Every external tool the lease, the guard and the hooks may run (a fake under test).
TOOLS = ("dconf", "systemctl", "systemd-run", "loginctl", "dbus-send", "tmux", "nvim",
         "pywalfox", "spicetify", "bat")
TIMEOUT = 3.0                  # seconds, for every tool call (08 §6 hook timeout)

_log = logging.getLogger("aptus.lease.system")


def tool(paths: Paths, name: str) -> str | None:
    """The executable for `name`: under APTUS_TEST=1 only $HOME/.aptus-test/bin/<name>, else from
    PATH; None when there is none (the call is skipped)."""
    if paths.test:
        fake = paths.test_bin / name
        return str(fake) if fake.is_file() and os.access(fake, os.X_OK) else None
    return shutil.which(name)


def run(paths: Paths, argv: Sequence[str], *, timeout: float = TIMEOUT,
        stdin: str | None = None) -> ToolResult:
    """Run argv[0] (resolved by `tool`) with the rest as arguments; never raises for a failing
    or missing tool, the result says what happened."""
    argv = list(argv)
    exe = tool(paths, argv[0])
    if exe is None:
        _log.debug("skipped (no %s): %s", argv[0], argv)
        return ToolResult(argv, skipped=True)
    try:
        r = subprocess.run([exe, *argv[1:]], capture_output=True, text=True, timeout=timeout,
                           input=stdin, check=False)
    except subprocess.TimeoutExpired:
        _log.warning("timed out after %.0f s: %s", timeout, argv)
        return ToolResult(argv, code=-1, timed_out=True)
    except OSError as e:
        _log.warning("could not run %s: %s", argv, e)
        return ToolResult(argv, code=-1, stderr=str(e))
    _log.debug("ran %s: %d", argv, r.returncode)
    return ToolResult(argv, r.returncode, r.stdout, r.stderr)


def boot_id() -> str:
    """/proc/sys/kernel/random/boot_id without the newline."""
    with open("/proc/sys/kernel/random/boot_id", encoding="ascii") as f:
        return f.read().strip()


def comm(pid: int) -> str | None:
    """/proc/<pid>/comm, None when the process is gone."""
    try:
        with open(f"/proc/{pid}/comm", encoding="utf-8", errors="replace") as f:
            return f.read().strip()
    except OSError:
        return None


def environ(pid: int) -> dict[str, str]:
    """/proc/<pid>/environ ({} when unreadable: another user's or a gone process)."""
    try:
        with open(f"/proc/{pid}/environ", "rb") as f:
            raw = f.read()
    except OSError:
        return {}
    env = {}
    for item in raw.split(b"\0"):
        name, sep, value = item.partition(b"=")
        if sep:
            env[name.decode(errors="replace")] = value.decode(errors="replace")
    return env


def processes(paths: Paths, names: Sequence[str]) -> list[Proc]:
    """This user's processes whose comm is one of `names`; under APTUS_TEST=1 only those whose
    environment has this HOME (a test never sees Lenno's processes)."""
    uid, found = os.getuid(), []
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        pid = int(entry)
        try:
            if os.stat(f"/proc/{entry}").st_uid != uid:
                continue
        except OSError:
            continue
        c = comm(pid)
        if c is None or c not in names:
            continue
        env = environ(pid)
        if paths.test and env.get("HOME") != str(paths.home):
            continue
        found.append(Proc(pid, c, env))
    return sorted(found, key=lambda p: p.pid)


def session_processes(paths: Paths, names: Sequence[str], signature: str) -> list[Proc]:
    """`processes` narrowed to those whose HYPRLAND_INSTANCE_SIGNATURE is `signature` (none for an
    empty signature)."""
    if not signature:
        return []
    return [p for p in processes(paths, names)
            if p.env.get("HYPRLAND_INSTANCE_SIGNATURE") == signature]


def signal_session(paths: Paths, names: Sequence[str], signal_name: str, signature: str) -> list[int]:
    """Send `signal_name` (e.g. "SIGUSR1") to every `session_processes` match; returns the pids
    signalled. Refuses the real session's signature under test (hypr.check_allowed)."""
    hypr.check_allowed(signature)
    sig = signal.Signals[signal_name]
    sent = []
    for proc in session_processes(paths, names, signature):
        try:
            os.kill(proc.pid, sig)
            sent.append(proc.pid)
        except ProcessLookupError:
            pass
    return sent
