"""Minimal Hyprland IPC client over $XDG_RUNTIME_DIR/hypr/<signature>/.socket.sock.

Hyprland 0.57 with the Lua config takes Lua expressions for `dispatch` and `eval`.
"""
from __future__ import annotations

import json
from collections.abc import Mapping
from pathlib import Path
from typing import Any

from .paths import Paths


class HyprError(Exception):
    """Hyprland is unreachable or answered with an error."""


class RefusedInstance(HyprError):
    """The target is the real session while running under the test harness."""


ENV_SIG = "HYPRLAND_INSTANCE_SIGNATURE"
ENV_REAL_SIG = "APTUS_REAL_HYPRLAND_SIGNATURE"   # set by the e2e harness: never talk to it


def signature(env: Mapping[str, str] | None = None) -> str:
    """HYPRLAND_INSTANCE_SIGNATURE, or HyprError when unset. Under APTUS_TEST=1 it raises
    RefusedInstance when it equals APTUS_REAL_HYPRLAND_SIGNATURE."""
    raise NotImplementedError


def socket_path(paths: Paths, sig: str) -> Path:
    """$XDG_RUNTIME_DIR/hypr/<sig>/.socket.sock (the real runtime dir, also in tests)."""
    raise NotImplementedError


def request(command: str, *, sig: str | None = None, as_json: bool = False,
            timeout: float = 2.0) -> str:
    """One request on the command socket ("j/" prefix with as_json). Raises HyprError."""
    raise NotImplementedError


def request_json(command: str, *, sig: str | None = None) -> Any:
    raise NotImplementedError


def dispatch(lua: str, *, sig: str | None = None) -> None:
    """`dispatch <lua>`: Hyprland 0.57 takes a Lua dispatcher expression."""
    raise NotImplementedError


def eval_lua(lua: str, *, sig: str | None = None) -> None:
    raise NotImplementedError


def notify(text: str, timeout_ms: int = 8000, *, sig: str | None = None) -> None:
    """A Hyprland notification (the supervisor's crash message)."""
    raise NotImplementedError


def config_errors(*, sig: str | None = None) -> list[str]:
    raise NotImplementedError
