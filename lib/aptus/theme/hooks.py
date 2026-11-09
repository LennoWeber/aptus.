"""Reload hooks (08 §7), run in parallel with a 3 s timeout each, after apply and again after a
release (so processes that outlive the session see Noctalia's paint again).

Kinds: none · signal:<comm>:<SIG> (only processes of this Hyprland session) · exec:<command>
(only when the command exists) · builtin:<name> (kde, tmux, nvim, hyprland) · bake:<process>:<cmd>
(only while <process> is not running; otherwise queued for the guard)."""
from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass

from ..paths import Paths
from .targets import Target


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


TIMEOUT = 3.0
BUILTINS = ("kde", "tmux", "nvim", "hyprland")
KDE_SIGNAL = ["dbus-send", "--session", "--type=signal", "/KGlobalSettings",
              "org.kde.KGlobalSettings.notifyChange", "int32:0", "int32:0"]


def parse(reload: str) -> Hook:
    """A manifest `reload` string → Hook; ValueError for an unknown kind or builtin."""
    raise NotImplementedError


def run_all(paths: Paths, targets: Sequence[Target], signature: str) -> list[HookResult]:
    """Run each target's hook in a thread, each with TIMEOUT; a timeout is "next-start"."""
    raise NotImplementedError


def run_one(paths: Paths, target: Target, signature: str) -> HookResult:
    raise NotImplementedError


def builtin_kde(paths: Paths, signature: str) -> HookResult:
    raise NotImplementedError


def builtin_tmux(paths: Paths, signature: str) -> HookResult:
    """`tmux -S <socket> source-file ~/.config/tmux/tmux.conf` for every server socket in
    paths.tmux_sockets (a tmux server outlives the session, so this also runs after release)."""
    raise NotImplementedError


def builtin_nvim(paths: Paths, signature: str) -> HookResult:
    """`nvim --server <s> --remote-send '<Cmd>colorscheme noctalia<CR>'` for each socket
    $XDG_RUNTIME_DIR/nvim.* (under test: below HOME only)."""
    raise NotImplementedError


def builtin_hyprland(paths: Paths, signature: str) -> HookResult:
    """`hyprctl eval` of the border, background, shadow and group colours from generated.lua's
    values (hypr.eval_lua with this signature; refused for the real one under test)."""
    raise NotImplementedError


def bake(paths: Paths, target: Target, hook: Hook) -> HookResult:
    """Run the bake command when `hook.comm` is not running, else queue it (bake_queue)."""
    raise NotImplementedError


def retry_queued(paths: Paths) -> list[HookResult]:
    """The guard's tick: run each queued bake whose app has closed meanwhile."""
    raise NotImplementedError
