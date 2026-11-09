"""Reload hooks (08 §7), run in parallel with a 3 s timeout each, after apply and again after a
release (so processes that outlive the session see Noctalia's paint again).

Kinds: none · signal:<comm>:<SIG> (only processes of this Hyprland session) · exec:<command>
(only when the command exists) · builtin:<name> (kde, tmux, nvim, hyprland) · bake:<process>:<cmd>
(only while <process> is not running; otherwise queued for the guard)."""
from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Hook:
    kind: str                  # none | signal | exec | builtin | bake
    comm: str = ""             # signal: process name; bake: the app that must be closed
    signal: str = ""           # signal: SIGUSR1, …
    command: str = ""          # exec / bake: the command line
    name: str = ""             # builtin name


@dataclass
class HookResult:
    target: str
    state: str                 # "applied" | "next-start" | "queued" | "failed"
    detail: str = ""
