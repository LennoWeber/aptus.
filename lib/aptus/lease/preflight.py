"""Preflight before a take (02 §5.3 step 3, §8): another graphical session of this user open (an
Umbriel session left on another VT is logind state `online`), or a `noctalia` process running →
no lease, scope-only mode, and the notch says once why."""
from __future__ import annotations

from dataclasses import dataclass, field


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
