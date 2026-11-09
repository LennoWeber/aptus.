"""Preflight before a take (02 §5.3 step 3, §8): another graphical session of this user open (an
Umbriel session left on another VT is logind state `online`), or a `noctalia` process running →
no lease, scope-only mode, and the notch says once why."""
from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field

from ..paths import Paths


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
NOTICE_OTHER_SESSION = "Another session is open — some apps keep Noctalia's colours."
NOTICE_NOCTALIA = "Noctalia is running — some apps keep Noctalia's colours."
NOTICE_FAILED = "Some apps could not be themed — they keep Noctalia's colours."
REASON_OTHER_SESSION = "another session is open"
REASON_NOCTALIA = "noctalia is running"
REASON_UNKNOWN = "cannot list login sessions"


def sessions(paths: Paths) -> list[LoginSession] | None:
    """This user's logind sessions (`loginctl list-sessions` + `show-session`), None when loginctl
    is missing or fails (the caller fails closed: no lease)."""
    raise NotImplementedError


def others(all_sessions: Sequence[LoginSession], own_id: str) -> list[LoginSession]:
    """Open graphical user sessions other than `own_id` (an Umbriel session on another VT is
    `online`)."""
    raise NotImplementedError


def noctalia(paths: Paths) -> list[int]:
    """Pids of running Noctalia shells of this user (under test: of this HOME only)."""
    raise NotImplementedError


def check(paths: Paths, env: Mapping[str, str]) -> Preflight:
    """Step 3 of 02 §5.3 and §8: ok only when no other session is open, no Noctalia runs and the
    sessions could be listed; else reasons and the notch's notice."""
    raise NotImplementedError
