"""Everything the lease, the guard and the theme hooks do outside their own files: external tools
(dconf, systemctl, systemd-run, loginctl, dbus-send, tmux, nvim, pywalfox, spicetify, bat) and
signals to processes.

Under APTUS_TEST=1 a tool comes only from $HOME/.aptus-test/bin (a fake that records its calls);
without a fake the call is skipped and reported as skipped, never run for real. Signals go only to
processes whose environment carries the given Hyprland signature, and under test also this HOME.
"""
from __future__ import annotations

from dataclasses import dataclass, field


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
