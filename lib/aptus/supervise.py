"""`aptus-supervise`: runs and restarts the shell (07-architecture §10)."""
from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class RestartPolicy:
    delays: tuple[float, ...] = (0.5, 1.0, 2.0)   # after the 1st, 2nd, 3rd crash
    crash_window: float = 10.0                    # three crashes within this many seconds …
    crash_limit: int = 3                          # … switch to the slow retry
    slow_retry: float = 30.0


@dataclass
class CrashLog:
    times: list[float]                            # monotonic times of recent crashes
