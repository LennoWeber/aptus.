"""`aptus-supervise`: runs and restarts the shell (07-architecture §10)."""
from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass

from .paths import Paths


@dataclass(frozen=True)
class RestartPolicy:
    delays: tuple[float, ...] = (0.5, 1.0, 2.0)   # after the 1st, 2nd, 3rd crash
    crash_window: float = 10.0                    # three crashes within this many seconds …
    crash_limit: int = 3                          # … switch to the slow retry
    slow_retry: float = 30.0


@dataclass
class CrashLog:
    times: list[float]                            # monotonic times of recent crashes


# TODO(phase): qs stdout/stderr → `systemd-cat -t aptus-shell` (07 §10); under APTUS_TEST →
#   $HOME/aptus-shell.log instead, so a test shell never writes to the journal (decision 8).
# TODO(phase): main() takes an flock on <runtime>/supervise.lock; a second supervisor exits 0.
def shell_command(paths: Paths) -> list[str]:
    """qs -p <repo>/shell --no-duplicate."""
    raise NotImplementedError


def shell_env(paths: Paths, env: Mapping[str, str]) -> dict[str, str]:
    """The shell's environment: `env` plus APTUS_DEV=1 while <runtime>/dev exists (aptus dev)."""
    raise NotImplementedError


def next_delay(policy: RestartPolicy, crashes: CrashLog, now: float) -> float:
    """Record a crash at `now` and return the wait before the next start: 0.5, 1, 2 s, then the
    slow retry once crash_limit crashes fall inside crash_window."""
    raise NotImplementedError


def crashed_out(policy: RestartPolicy, crashes: CrashLog, now: float) -> bool:
    """Whether the crash limit was just reached (lock fallback + notify)."""
    raise NotImplementedError


def on_crash_limit(paths: Paths) -> None:
    """hyprlock when the locked marker exists, then the Hyprland notification of 07 §10."""
    raise NotImplementedError


def run(paths: Paths, policy: RestartPolicy, command: Sequence[str]) -> int:
    """Run and restart until SIGTERM/SIGINT; an exit 0 with the restart flag restarts at once,
    an exit 0 without it ends the supervisor."""
    raise NotImplementedError


def main(argv: Sequence[str]) -> int:
    raise NotImplementedError
