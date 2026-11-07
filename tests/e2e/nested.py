"""The nested Hyprland harness (07 §13, design/probes.md "How the nested probes run").

A Hyprland in a window of Lenno's session, with HOME pointing at a temporary directory, a private
session bus (dbus-run-session), HYPRLAND_NO_SD_VARS=1 (no import into the real user manager) and
APTUS_TEST=1. Every hyprctl call names the nested instance (-i); the real session's signature is
exported as APTUS_REAL_HYPRLAND_SIGNATURE so the tools refuse it.
"""
from __future__ import annotations

import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[2]


@dataclass
class Nested:
    root: Path                      # temporary directory: home/, cfg/, logs
    home: Path
    signature: str = ""             # the nested HYPRLAND_INSTANCE_SIGNATURE
    wayland_display: str = ""       # its socket name (wayland-N)
    proc: subprocess.Popen | None = None
    shell_pid: int = 0
    log: list[str] = field(default_factory=list)

    def start(self, timeout: float = 10.0) -> None:
        """Start Hyprland with tests/e2e/hyprland.lua; wait for its socket."""
        raise NotImplementedError

    def stop(self) -> None:
        raise NotImplementedError

    def hyprctl(self, *args: str, as_json: bool = False) -> Any:
        raise NotImplementedError

    def exec(self, command: str) -> None:
        """Run a command inside the nested session (hl.dsp.exec_cmd), so it inherits the private
        bus and the temporary HOME."""
        raise NotImplementedError

    # TODO(phase): start() fills <tmp>/home first: .local/bin/aptus, aptus-session, aptus-supervise →
    #   <repo>/bin links; tests/e2e/hyprland.lua copied to <tmp>/cfg with an aptus → <repo>/hypr link.
    def start_shell(self, timeout: float = 10.0) -> None:
        """Wait until the shell answers `shell state`. The nested session's hyprland.start hook
        (hypr/init.lua) already ran <tmp>/home/.local/bin/aptus-session, so this starts nothing."""
        raise NotImplementedError

    def shortcut(self, name: str) -> None:
        """hl.dsp.global("aptus:<name>") over the socket (virtual keyboards cannot fire binds)."""
        raise NotImplementedError

    def msg(self, target: str, function: str, *args: str) -> str:
        """aptus msg with WAYLAND_DISPLAY set to the nested socket."""
        raise NotImplementedError

    def state(self) -> dict:
        raise NotImplementedError

    def click(self, x: int, y: int) -> None:
        """A left click through vpointer.py (zwlr_virtual_pointer_v1 on the nested socket)."""
        raise NotImplementedError

    def screenshot(self, path: Path) -> Path:
        """grim of the nested output (WAYLAND_DISPLAY = the nested socket)."""
        raise NotImplementedError

    def wait_for(self, predicate, timeout: float = 5.0, interval: float = 0.05) -> Any:
        raise NotImplementedError


def real_signature() -> str:
    """The signature of the session the tests run in (to refuse it); raises when there is none,
    so the harness never runs blind."""
    raise NotImplementedError
