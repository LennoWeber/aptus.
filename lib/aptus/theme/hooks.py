"""Reload hooks (08 §7), run in parallel with a 3 s timeout each, after apply and again after a
release (so processes that outlive the session see Noctalia's paint again).

Kinds: none · signal:<comm>:<SIG> (only processes of this Hyprland session) · exec:<command>
(only when the command exists) · builtin:<name> (kde, tmux, nvim, hyprland) · bake:<process>:<cmd>
(only while <process> is not running; otherwise queued for the guard)."""
from __future__ import annotations

from collections.abc import Mapping, Sequence
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
    # TODO(S2): split on ':' (exec/bake keep the rest of the line); kinds and BUILTINS checked.
    raise NotImplementedError


def run_all(paths: Paths, targets: Sequence[Target], signature: str) -> list[HookResult]:
    """run_reloads for these targets' `reload` strings."""
    # TODO(S2): run_reloads({t.id: t.reload}).
    raise NotImplementedError


def run_reloads(paths: Paths, reloads: Mapping[str, str], signature: str) -> list[HookResult]:
    """Run each hook (target id → reload string, e.g. ReleaseReport.reloads from the journal) in
    a thread, each with TIMEOUT; a timeout is "next-start". Without a signature (recover at login)
    only the hooks that need none run (kde, tmux, exec)."""
    # TODO(S2): ThreadPoolExecutor; future.result(TIMEOUT) → next-start on timeout; exceptions →
    #   failed.
    raise NotImplementedError


def run_one(paths: Paths, target: Target, signature: str) -> HookResult:
    # TODO(S2): parse; none → next-start; signal → system.signal_session; exec → system.run
    #   (skipped → next-start); builtin → builtin_<name>; bake → bake().
    raise NotImplementedError


def builtin_kde(paths: Paths, signature: str) -> HookResult:
    # TODO(S2): system.run(KDE_SIGNAL).
    raise NotImplementedError


def builtin_tmux(paths: Paths, signature: str) -> HookResult:
    """`tmux -S <socket> source-file ~/.config/tmux/tmux.conf` for every server socket in
    paths.tmux_sockets (a tmux server outlives the session, so this also runs after release)."""
    # TODO(S2): each socket in tmux_sockets: tmux -S <s> source-file ~/.config/tmux/tmux.conf
    #   (missing conf → next-start).
    raise NotImplementedError


def builtin_nvim(paths: Paths, signature: str) -> HookResult:
    """`nvim --server <s> --remote-send '<Cmd>colorscheme noctalia<CR>'` for each socket
    $XDG_RUNTIME_DIR/nvim.* (under test: below HOME only)."""
    # TODO(S2): glob nvim_sockets/nvim.*: nvim --server <s> --remote-send.
    raise NotImplementedError


def builtin_hyprland(paths: Paths, signature: str) -> HookResult:
    """`hyprctl eval` of the border, background, shadow and group colours from generated.lua's
    values (hypr.eval_lua with this signature; refused for the real one under test)."""
    # TODO(S2): hypr.eval_lua(hl.config{...} from theme_resolved) with sig=signature; no signature
    #   → next-start.
    raise NotImplementedError


def bake(paths: Paths, target: Target, hook: Hook) -> HookResult:
    """Run the bake command when `hook.comm` is not running, else queue it (bake_queue)."""
    # TODO(S2): system.processes([comm]) running → queue (bake_queue json) and queued; else
    #   system.run(command).
    raise NotImplementedError


def retry_queued(paths: Paths) -> list[HookResult]:
    """The guard's tick: run each queued bake whose app has closed meanwhile."""
    # TODO(S2): load bake_queue; run those whose app is gone; rewrite the queue.
    raise NotImplementedError
