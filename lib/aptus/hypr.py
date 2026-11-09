"""Minimal Hyprland IPC client over $XDG_RUNTIME_DIR/hypr/<signature>/.socket.sock.

Hyprland 0.57 with the Lua config takes Lua expressions for `dispatch` and `eval`.
"""
from __future__ import annotations

import json
import os
import socket
from collections.abc import Mapping
from pathlib import Path
from typing import Any

from .paths import ENV_TEST, Paths, get


class HyprError(Exception):
    """Hyprland is unreachable or answered with an error."""


class RefusedInstance(HyprError):
    """The target is the real session while running under the test harness."""


ENV_SIG = "HYPRLAND_INSTANCE_SIGNATURE"
ENV_REAL_SIG = "APTUS_REAL_HYPRLAND_SIGNATURE"   # set by the e2e harness: never talk to it


def signature(env: Mapping[str, str] | None = None) -> str:
    """HYPRLAND_INSTANCE_SIGNATURE (HyprError when unset), checked by check_allowed."""
    env = os.environ if env is None else env
    sig = env.get(ENV_SIG, "")
    if not sig:
        raise HyprError(f"{ENV_SIG} is not set (not inside Hyprland?)")
    check_allowed(sig, env)
    return sig


def check_allowed(sig: str, env: Mapping[str, str] | None = None) -> None:
    """Under APTUS_TEST=1 refuse (RefusedInstance) unless APTUS_REAL_HYPRLAND_SIGNATURE is set and
    non-empty and differs from `sig`: a test must never address the session it runs in, and an
    unknown real signature fails closed. Outside tests a no-op."""
    env = os.environ if env is None else env
    if env.get(ENV_TEST) != "1":
        return
    real = env.get(ENV_REAL_SIG, "")
    if not real:
        raise RefusedInstance(f"{ENV_TEST}=1 but {ENV_REAL_SIG} is unknown: refusing every instance")
    if sig == real:
        raise RefusedInstance("refusing to talk to the real Hyprland session under APTUS_TEST=1")


def socket_path(paths: Paths, sig: str) -> Path:
    """<paths.hypr_runtime>/<sig>/.socket.sock."""
    return paths.hypr_runtime / sig / ".socket.sock"


def request(command: str, *, sig: str | None = None, as_json: bool = False,
            timeout: float = 2.0) -> str:
    """One request on the command socket ("j/" prefix with as_json). Every request, whatever the
    source of `sig`, goes through check_allowed first. Raises HyprError."""
    sig = sig or signature()
    check_allowed(sig)
    if "/" in sig or sig in ("", ".", ".."):
        raise HyprError(f"bad instance signature {sig!r}")
    path = socket_path(get(), sig)
    payload = (("j/" if as_json else "") + command).encode("utf-8")
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.settimeout(timeout)
            sock.connect(str(path))
            sock.sendall(payload)
            chunks = []
            while chunk := sock.recv(65536):
                chunks.append(chunk)
    except (OSError, TimeoutError) as e:
        raise HyprError(f"Hyprland socket {path}: {e}") from e
    return b"".join(chunks).decode("utf-8", "replace")


def request_json(command: str, *, sig: str | None = None) -> Any:
    answer = request(command, sig=sig, as_json=True)
    try:
        return json.loads(answer)
    except ValueError as e:
        raise HyprError(f"{command}: not JSON: {answer.strip()[:200]}") from e


def _expect_ok(what: str, command: str, sig: str | None) -> None:
    """Send `command`; anything but an empty answer or "ok" is a HyprError naming `what`."""
    answer = request(command, sig=sig).strip()
    if answer not in ("", "ok"):
        raise HyprError(f"{what}: {answer[:200]}")


def dispatch(lua: str, *, sig: str | None = None) -> None:
    """`dispatch <lua>`: Hyprland 0.57 takes a Lua dispatcher expression."""
    _expect_ok("dispatch", f"dispatch {lua}", sig)


def eval_lua(lua: str, *, sig: str | None = None) -> None:
    _expect_ok("eval", f"eval {lua}", sig)


def notify(text: str, timeout_ms: int = 8000, *, sig: str | None = None) -> None:
    """A Hyprland notification (the supervisor's crash message)."""
    # `hyprctl notify <icon> <ms> <colour> <text>`: icon 0 = warning, colour 0 = default.
    _expect_ok("notify", f"notify 0 {int(timeout_ms)} 0 {' '.join(text.split())}", sig)


def config_errors(*, sig: str | None = None) -> list[str]:
    answer = request_json("configerrors", sig=sig)
    if isinstance(answer, list):
        return [str(e) for e in answer if str(e).strip()]
    return [str(answer)] if answer else []
