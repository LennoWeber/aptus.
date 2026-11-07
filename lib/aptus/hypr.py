"""Minimal Hyprland IPC client over $XDG_RUNTIME_DIR/hypr/<signature>/.socket.sock.

Hyprland 0.57 with the Lua config takes Lua expressions for `dispatch` and `eval`.
"""
from __future__ import annotations


class HyprError(Exception):
    """Hyprland is unreachable or answered with an error."""


class RefusedInstance(HyprError):
    """The target is the real session while running under the test harness."""
