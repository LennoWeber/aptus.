"""Reload hooks (08 §7), run in parallel with a 3 s timeout each, after apply and again after a
release (so processes that outlive the session see Noctalia's paint again).

Kinds: none · signal:<comm>:<SIG> (only processes of this Hyprland session) · exec:<command>
(only when the command exists) · builtin:<name> (kde, tmux, nvim, hyprland) · bake:<process>:<cmd>
(only while <process> is not running; otherwise queued for the guard)."""
from __future__ import annotations

import json
import logging
import os
import shlex
import signal as signals
import stat
from collections.abc import Mapping
from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import TimeoutError as FutureTimeout
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .. import atomic, hypr
from ..lease import invariants, system
from ..paths import Paths


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
NVIM_KEYS = "<Cmd>colorscheme noctalia<CR>"
NEEDS_SIGNATURE = ("signal", "hyprland")   # without one (recover at login) these wait

_log = logging.getLogger("aptus.theme.hooks")


def parse(reload: str) -> Hook:
    """A manifest `reload` string → Hook; ValueError for an unknown kind or builtin."""
    kind, _, rest = reload.partition(":")
    if kind == "none" and not rest:
        return Hook("none")
    if kind == "signal":
        comm, _, sig = rest.partition(":")
        if not comm or sig not in signals.Signals.__members__:
            raise ValueError(f"reload {reload!r}: signal:<process>:<SIGNAL>")
        return Hook("signal", comm=comm, signal=sig)
    if kind == "exec" and rest.strip():
        return Hook("exec", command=rest)
    if kind == "builtin" and rest in BUILTINS:
        return Hook("builtin", name=rest)
    if kind == "bake":
        comm, _, command = rest.partition(":")
        if comm and command.strip():
            return Hook("bake", comm=comm, command=command)
    raise ValueError(f"unknown reload {reload!r}")


def run_reloads(paths: Paths, reloads: Mapping[str, str], signature: str) -> list[HookResult]:
    """Run each hook (target id → reload string, e.g. ReleaseReport.reloads from the journal) in
    a thread, each with TIMEOUT; a timeout is "next-start". Without a signature (recover at login)
    the hooks that need one (signals, Hyprland) are "next-start". Queued bakes are written to the
    bake queue here, in the calling thread."""
    todo = {tid: r for tid, r in reloads.items() if r != "none"}
    if not todo:
        return []
    results: list[HookResult] = []
    pool = ThreadPoolExecutor(max_workers=min(8, len(todo)), thread_name_prefix="aptus-hook")
    try:
        futures = {tid: pool.submit(run_one, paths, tid, r, signature) for tid, r in todo.items()}
        for tid, fut in futures.items():
            try:
                results.append(fut.result(timeout=TIMEOUT + 1))
            except FutureTimeout:
                results.append(HookResult(tid, "next-start", "timed out"))
            except Exception as e:  # noqa: BLE001 - one hook never stops the others
                results.append(HookResult(tid, "failed", f"{type(e).__name__}: {e}"))
    finally:
        pool.shutdown(wait=False, cancel_futures=True)
    queued = {r.target: todo[r.target] for r in results if r.state == "queued"}
    if queued:
        update_queue(paths, add=queued)
    for r in results:
        (_log.warning if r.state == "failed" else _log.info)("reload %s: %s %s", r.target,
                                                              r.state, r.detail)
    return results


def run_one(paths: Paths, target_id: str, reload: str, signature: str) -> HookResult:
    """One hook. An unreachable app or a missing tool is "next-start", never an error."""
    hook = parse(reload)
    if hook.kind == "none":
        return HookResult(target_id, "next-start")
    if not signature and (hook.kind == "signal" or hook.name == "hyprland"):
        return HookResult(target_id, "next-start", "no Hyprland session")
    if hook.kind == "signal":
        pids = system.signal_session(paths, [hook.comm], hook.signal, signature)
        return HookResult(target_id, "applied" if pids else "next-start",
                          f"{hook.signal} to {len(pids)} {hook.comm}")
    if hook.kind == "exec":
        return _tool(target_id, system.run(paths, shlex.split(hook.command)))
    if hook.kind == "bake":
        return bake(paths, target_id, hook)
    builtin = {"kde": builtin_kde, "tmux": builtin_tmux, "nvim": builtin_nvim,
               "hyprland": builtin_hyprland}[hook.name]
    return builtin(paths, target_id, signature)


def _tool(target_id: str, r: system.ToolResult) -> HookResult:
    if r.skipped or r.timed_out:
        return HookResult(target_id, "next-start", "not installed" if r.skipped else "timed out")
    if r.code != 0:
        return HookResult(target_id, "failed", f"{r.argv[0]} exited {r.code}: {r.stderr.strip()[:200]}")
    return HookResult(target_id, "applied")


def _many(target_id: str, results: list[system.ToolResult], what: str) -> HookResult:
    """Several tool calls (one per server): applied when one reached a server."""
    if not results:
        return HookResult(target_id, "next-start", f"no {what} running")
    ok = [r for r in results if not r.skipped and not r.timed_out and r.code == 0]
    if ok:
        return HookResult(target_id, "applied", f"{len(ok)} {what}")
    return _tool(target_id, results[0])


def builtin_kde(paths: Paths, target_id: str, signature: str) -> HookResult:
    return _tool(target_id, system.run(paths, KDE_SIGNAL))


def _tmux_conf(paths: Paths) -> Path | None:
    for p in (paths.config_home / "tmux/tmux.conf", paths.home / ".tmux.conf"):
        if p.is_file():
            return p
    return None


def tmux_sockets(paths: Paths) -> list[Path] | None:
    """The tmux server sockets in paths.tmux_sockets that are this user's: the directory must be
    a real directory (not a symlink) owned by this uid that nobody else may enter (mode & 0o077
    == 0, tmux's own rule, which `-S` skips), each entry a socket owned by this uid and not a
    symlink. [] when the directory does not exist; None when it fails that check (another uid
    may have made it: no client is pointed at it)."""
    d = paths.tmux_sockets
    try:
        st = os.lstat(d)
    except FileNotFoundError:
        return []
    except OSError:
        return None
    uid = os.getuid()
    if not stat.S_ISDIR(st.st_mode) or st.st_uid != uid or st.st_mode & 0o077:
        return None
    found = []
    for p in sorted(d.iterdir()):
        try:
            e = os.lstat(p)
        except OSError:
            continue
        if stat.S_ISSOCK(e.st_mode) and e.st_uid == uid:
            found.append(p)
    return found


def builtin_tmux(paths: Paths, target_id: str, signature: str) -> HookResult:
    """`tmux -S <socket> source-file <tmux.conf>` for every server socket of tmux_sockets (a tmux
    server outlives the session, so this also runs after release); "next-start" when the socket
    directory is not this user's private one."""
    conf = _tmux_conf(paths)
    if conf is None:
        return HookResult(target_id, "next-start", "no tmux.conf")
    sockets = tmux_sockets(paths)
    if sockets is None:
        _log.warning("%s is not a private directory of this user: tmux not reloaded",
                     paths.tmux_sockets)
        return HookResult(target_id, "next-start", f"{paths.tmux_sockets} is not private")
    return _many(target_id, [system.run(paths, ["tmux", "-S", str(s), "source-file", str(conf)])
                             for s in sockets], "tmux server")


def builtin_nvim(paths: Paths, target_id: str, signature: str) -> HookResult:
    """`nvim --server <s> --remote-send '<Cmd>colorscheme noctalia<CR>'` for each socket
    nvim.* in the runtime dir (under test: below HOME only)."""
    sockets = sorted(p for p in paths.nvim_sockets.glob("nvim.*") if p.is_socket()) \
        if paths.nvim_sockets.is_dir() else []
    return _many(target_id, [system.run(paths, ["nvim", "--server", str(s), "--remote-send", NVIM_KEYS])
                             for s in sockets], "nvim server")


def hyprland_lua(paths: Paths) -> str:
    """The Lua that re-reads generated.lua and sets what look.lua took from it."""
    path = json.dumps(str(paths.generated_lua))
    return (f"local g = dofile({path}); local side = g.frame_edge + g.window_gap; "
            "hl.config({ general = { col = { active_border = g.accent, inactive_border = g.line }, "
            "gaps_out = { top = g.window_gap, right = side, bottom = side, left = side } }, "
            "decoration = { shadow = { color = g.shadow } }, "
            "misc = { background_color = g.ground } })")


def builtin_hyprland(paths: Paths, target_id: str, signature: str) -> HookResult:
    """`hyprctl eval` of the border, background, shadow and gap values from generated.lua (with
    this signature; refused for the real one under test)."""
    if not paths.generated_lua.is_file():
        return HookResult(target_id, "next-start", "no generated.lua")
    try:
        hypr.eval_lua(hyprland_lua(paths), sig=signature)
    except hypr.RefusedInstance:
        raise
    except hypr.HyprError as e:
        return HookResult(target_id, "next-start", str(e))
    return HookResult(target_id, "applied")


def bake(paths: Paths, target_id: str, hook: Hook) -> HookResult:
    """Run the bake command when `hook.comm` is not running, else "queued" (run_reloads writes
    the queue; the guard retries it)."""
    if system.processes(paths, [hook.comm]):
        return HookResult(target_id, "queued", f"{hook.comm} is running")
    return _tool(target_id, system.run(paths, shlex.split(hook.command), timeout=TIMEOUT))


def load_queue(paths: Paths) -> dict[str, str]:
    """target id → reload string of the queued bakes ({} when none or unreadable)."""
    try:
        raw: Any = json.loads(paths.bake_queue.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    if not isinstance(raw, dict):
        return {}
    return {k: v for k, v in raw.items() if isinstance(v, str) and v.startswith("bake:")}


def update_queue(paths: Paths, add: Mapping[str, str] | None = None,
                 remove: set[str] | None = None) -> dict[str, str]:
    """Add and remove queue entries under the theme lock; the file goes when it is empty."""
    from . import render
    with render.lock(paths):
        q = load_queue(paths)
        q.update(add or {})
        for tid in remove or ():
            q.pop(tid, None)
        invariants.writable(paths, paths.bake_queue, kind="state")
        if q:
            paths.make_runtime()
            atomic.write_json(paths.bake_queue, q, 0o600)
        else:
            paths.bake_queue.unlink(missing_ok=True)
    return q


def retry_queued(paths: Paths) -> list[HookResult]:
    """The guard's tick: run each queued bake whose app has closed meanwhile; what ran (applied
    or failed) leaves the queue. Under the theme lock, taken without waiting: while an apply
    holds it the tick is skipped, so the guard never stops watching Hyprland for it."""
    from . import render
    if not load_queue(paths):
        return []
    results = []
    try:
        with render.lock(paths, timeout=0):
            for tid, reload in load_queue(paths).items():
                r = bake(paths, tid, parse(reload))
                if r.state != "queued":
                    results.append(r)
            if results:
                update_queue(paths, remove={r.target for r in results})
    except render.LockBusy:
        _log.debug("bake retry skipped: the theme lock is busy")
        return []
    return results
