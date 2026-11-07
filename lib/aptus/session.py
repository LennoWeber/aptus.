"""`aptus-session start | stop` (02-isolation §7, 07-architecture §3)."""
from __future__ import annotations

import os
from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field
from enum import Enum

from .paths import Paths


class Mode(Enum):
    LEASE = "lease"            # the lease is held: leased targets carry aptus paint
    SCOPE_ONLY = "scope-only"  # only Own and Scope targets are themed (02 §5.3 preflight)


@dataclass
class StartReport:
    mode: Mode = Mode.SCOPE_ONLY
    # Why the session runs scope-only ("another session is open", "noctalia is running", "S2").
    reasons: list[str] = field(default_factory=list)
    # Steps that failed but did not stop the start (07 §3 "On failure").
    warnings: list[str] = field(default_factory=list)


def check_environment(env: Mapping[str, str]) -> str | None:
    """None when this is a Hyprland session (XDG_CURRENT_DESKTOP=Hyprland and a signature),
    else the reason to exit 0 without doing anything."""
    raise NotImplementedError


def start(paths: Paths, env: Mapping[str, str]) -> StartReport:
    """Steps 1–6 of 07 §3 / 02 §7 up to the exec. S1: scope-only; recover, render, lease, env
    import and units arrive with S2 and are skipped (always skipped under APTUS_TEST=1)."""
    raise NotImplementedError


def write_status(paths: Paths, report: StartReport) -> None:
    """<runtime>/session.json for `aptus msg shell state` and the doctor."""
    raise NotImplementedError


def exec_supervisor(paths: Paths) -> None:
    """Replace this process with aptus-supervise (never returns)."""
    raise NotImplementedError


def stop(paths: Paths) -> int:
    """The logout path's last step: nothing to release before S2; returns 0."""
    raise NotImplementedError


def main(argv: Sequence[str]) -> int:
    raise NotImplementedError
