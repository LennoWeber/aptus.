"""Preflight before a take (02 §5.3 step 3, §8): another graphical session of this user open (an
Umbriel session left on another VT is logind state `online`), or a `noctalia` process running →
no lease, scope-only mode, and the notch says once why."""
from __future__ import annotations

import os
from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field

from ..paths import Paths
from . import system


@dataclass(frozen=True)
class LoginSession:
    id: str
    cls: str                   # logind Class: user | greeter | manager | …
    type: str                  # wayland | x11 | mir | tty | unspecified
    state: str                 # active | online | closing
    desktop: str = ""
    service: str = ""


@dataclass
class Preflight:
    ok: bool = True                                          # the lease may be taken
    reasons: list[str] = field(default_factory=list)         # "another session is open", "noctalia is running"
    notice: str = ""                                         # the notch's one-time message ("" when ok)
    others: list[LoginSession] = field(default_factory=list)
    noctalia: list[int] = field(default_factory=list)        # pids


GRAPHICAL = ("wayland", "x11", "mir")
OPEN = ("active", "online")
NOCTALIA_NAMES = ("noctalia", "noctalia-shell")   # comm; plus `qs`/`quickshell` running its config
QUICKSHELL_NAMES = ("qs", "quickshell")
PROPS = ("Id", "Class", "Type", "State", "Desktop", "Service")   # asked of `loginctl show-session`
NOTICE_OTHER_SESSION = "Another session is open — some apps keep Noctalia's colours."
NOTICE_NOCTALIA = "Noctalia is running — some apps keep Noctalia's colours."
NOTICE_FAILED = "Some apps could not be themed — they keep Noctalia's colours."
REASON_OTHER_SESSION = "another session is open"
REASON_NOCTALIA = "noctalia is running"
REASON_UNKNOWN = "cannot list login sessions"


def sessions(paths: Paths) -> list[LoginSession] | None:
    """This user's logind sessions (`loginctl list-sessions`, then one `show-session` for all of
    them), None when loginctl is missing or fails, or a listed session is not shown (the caller
    fails closed: no lease)."""
    r = system.run(paths, ["loginctl", "list-sessions", "--no-legend", "--no-pager"])
    if not r.ok:
        return None
    uid = str(os.getuid())
    ids = [cols[0] for cols in map(str.split, r.stdout.splitlines())
           if len(cols) >= 2 and cols[1] == uid]
    shown = show_sessions(paths, ids) if ids else {}
    if shown is None or set(shown) != set(ids):
        return None
    out = []
    for sid in ids:
        props = shown[sid]
        out.append(LoginSession(id=sid, cls=props.get("Class", ""), type=props.get("Type", ""),
                                state=props.get("State", ""), desktop=props.get("Desktop", ""),
                                service=props.get("Service", "")))
    return out


def show_sessions(paths: Paths, ids: Sequence[str]) -> dict[str, dict[str, str]] | None:
    """`loginctl show-session ID… -p …` (one block of `Name=value` lines per session, blank lines
    between them) as session id → properties; None when it fails (also when one id is gone)."""
    argv = ["loginctl", "show-session", *ids, "--no-pager"]
    for prop in PROPS:
        argv += ["-p", prop]
    r = system.run(paths, argv)
    if not r.ok:
        return None
    out = {}
    for block in r.stdout.split("\n\n"):
        props = dict(line.split("=", 1) for line in block.splitlines() if "=" in line)
        if "Id" in props:
            out[props["Id"]] = props
    return out


def others(all_sessions: Sequence[LoginSession], own_id: str) -> list[LoginSession]:
    """Open graphical user sessions other than `own_id` (an Umbriel session on another VT is
    `online`)."""
    return [x for x in all_sessions
            if x.cls == "user" and x.type in GRAPHICAL and x.state in OPEN and x.id != own_id]


def noctalia(paths: Paths) -> list[int]:
    """Pids of running Noctalia shells of this user (under test: of this HOME only): one walk of
    /proc for both names and the Quickshells whose command line names noctalia."""
    pids = []
    for proc in system.processes(paths, NOCTALIA_NAMES + QUICKSHELL_NAMES):
        if proc.comm in NOCTALIA_NAMES:
            pids.append(proc.pid)
            continue
        try:
            with open(f"/proc/{proc.pid}/cmdline", "rb") as f:
                if b"noctalia" in f.read().lower():
                    pids.append(proc.pid)
        except OSError:
            continue
    return sorted(pids)


def check(paths: Paths, env: Mapping[str, str]) -> Preflight:
    """Step 3 of 02 §5.3 and §8: ok only when no other session is open, no Noctalia runs and the
    sessions could be listed; else reasons and the notch's notice. Runs inside ops.take under
    the lease flock; the guard reuses `sessions`/`others` while the lease is held."""
    result = Preflight()
    listed = sessions(paths)
    if listed is None:
        result.reasons.append(REASON_UNKNOWN)
        result.notice = NOTICE_OTHER_SESSION
    else:
        result.others = others(listed, env.get("XDG_SESSION_ID", ""))
        if result.others:
            result.reasons.append(REASON_OTHER_SESSION)
            result.notice = NOTICE_OTHER_SESSION
    result.noctalia = noctalia(paths)
    if result.noctalia:
        result.reasons.append(REASON_NOCTALIA)
        result.notice = result.notice or NOTICE_NOCTALIA
    result.ok = not result.reasons
    return result
