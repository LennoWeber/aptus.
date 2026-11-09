"""Everything the lease, the guard and the theme hooks do outside their own files: external tools
(dconf, systemctl, systemd-run, loginctl, dbus-send, tmux, nvim, pywalfox, spicetify, bat) and
signals to processes.

Under APTUS_TEST=1 a tool comes only from $HOME/.aptus-test/bin (a fake that records its calls);
without a fake the call is skipped and reported as skipped, never run for real. Signals go only to
processes whose environment carries the given Hyprland signature, and under test also this HOME.
"""
from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass, field

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


def tool(paths: Paths, name: str) -> str | None:
    """The executable for `name`: under APTUS_TEST=1 only $HOME/.aptus-test/bin/<name>, else from
    PATH; None when there is none (the call is skipped)."""
    # TODO(S2): test: paths.test_bin/name if it is an executable file else None; else shutil.which.
    raise NotImplementedError


def run(paths: Paths, argv: Sequence[str], *, timeout: float = TIMEOUT,
        stdin: str | None = None) -> ToolResult:
    """Run argv[0] (resolved by `tool`) with the rest as arguments; never raises for a failing
    or missing tool, the result says what happened."""
    # TODO(S2): tool() None → ToolResult(skipped=True); subprocess.run(capture_output, text,
    #   timeout, input=stdin); TimeoutExpired → timed_out; log every call at debug.
    raise NotImplementedError


def boot_id() -> str:
    """/proc/sys/kernel/random/boot_id without the newline."""
    # TODO(S2): read /proc/sys/kernel/random/boot_id, strip.
    raise NotImplementedError


def comm(pid: int) -> str | None:
    """/proc/<pid>/comm, None when the process is gone."""
    # TODO(S2): read /proc/<pid>/comm, strip; None on OSError.
    raise NotImplementedError


def environ(pid: int) -> dict[str, str]:
    """/proc/<pid>/environ ({} when unreadable: another user's or a gone process)."""
    # TODO(S2): read /proc/<pid>/environ, split on NUL and the first '='; {} on OSError.
    raise NotImplementedError


def processes(paths: Paths, names: Sequence[str]) -> list[Proc]:
    """This user's processes whose comm is one of `names`; under APTUS_TEST=1 only those whose
    environment has this HOME (a test never sees Lenno's processes)."""
    # TODO(S2): scan /proc digits, uid == os.getuid() (stat), comm in names; under test keep only
    #   those whose environ HOME == str(paths.home).
    raise NotImplementedError


def session_processes(paths: Paths, names: Sequence[str], signature: str) -> list[Proc]:
    """`processes` narrowed to those whose HYPRLAND_INSTANCE_SIGNATURE is `signature`."""
    # TODO(S2): filter processes() by environ HYPRLAND_INSTANCE_SIGNATURE == signature.
    raise NotImplementedError


def signal_session(paths: Paths, names: Sequence[str], signal_name: str, signature: str) -> list[int]:
    """Send `signal_name` (e.g. "SIGUSR1") to every `session_processes` match; returns the pids
    signalled. Refuses the real session's signature under test (hypr.check_allowed)."""
    # TODO(S2): hypr.check_allowed(signature); signal.Signals[signal_name]; os.kill each,
    #   ProcessLookupError ignored.
    raise NotImplementedError
