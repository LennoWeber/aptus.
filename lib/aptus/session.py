"""`aptus-session start | stop` (02-isolation §7, 07-architecture §3)."""
from __future__ import annotations

import logging
import os
import sys
import time
from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field
from enum import Enum

from . import atomic, hypr
from .log import setup
from .paths import Paths, get
from .theme.render import Generation


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
    # The notch's one-time message for this session ("" when there is nothing to say; Lease.notice).
    notice: str = ""
    # The theme generation rendered at start (0: none, the apps keep Noctalia's paint).
    generation: int = 0
    # The guard unit was started (else release happens at the next login through recover).
    guard: bool = False


def check_environment(env: Mapping[str, str]) -> str | None:
    """None when this is a Hyprland session (XDG_CURRENT_DESKTOP=Hyprland and a signature),
    else the reason to exit 0 without doing anything."""
    desktops = env.get("XDG_CURRENT_DESKTOP", "").split(":")
    if "Hyprland" not in desktops:
        return f"not a Hyprland session (XDG_CURRENT_DESKTOP={env.get('XDG_CURRENT_DESKTOP', '')!r})"
    if not env.get(hypr.ENV_SIG):
        return f"{hypr.ENV_SIG} is not set"
    return None


# Imported into the systemd user environment while the lease is held (02 §6 "yes" rows); the
# guard unsets them again (lease.guard.UNSET).
IMPORT_VARS = ("APTUS_SESSION", "QT_QPA_PLATFORMTHEME", "XCURSOR_THEME", "XCURSOR_SIZE",
               "HYPRCURSOR_SIZE")


def recover_step(paths: Paths, report: StartReport) -> None:
    """Step 1: recover (a leftover lease of a dead owner is released first); a failure is a
    warning, and take refuses afterwards if a journal is still there."""
    # TODO(S2): ops.recover; hooks.run_reloads of its reloads (no signature yet needed: this
    #   session's); JournalError/LeaseError → report.warnings.
    raise NotImplementedError


def render_step(paths: Paths, report: StartReport) -> Generation | None:
    """Step 2: render a generation from settings.json; when the renderer fails, the last good
    generation (render.current), else None: no lease then (08 §9)."""
    # TODO(S2): inputs.from_settings; targets.load; render.render; exceptions → warning and
    #   render.current(paths).
    raise NotImplementedError


def start_guard(paths: Paths, env: Mapping[str, str]) -> bool:
    """Step 3, before any slot is written: `systemd-run --user --unit=aptus-guard --collect …
    aptus-guard <hyprland-pid> <signature>`; True when the unit is active. No guard, no lease."""
    # TODO(S2): ops.owner(env).hyprland_pid; system.run systemd-run (skipped under test without a
    #   fake → False); then `systemctl --user is-active aptus-guard.service`.
    raise NotImplementedError


def lease_step(paths: Paths, env: Mapping[str, str], gen: Generation, report: StartReport) -> None:
    """Step 4: ops.take with the generation's slot specs (preflight inside); sets report.mode,
    reasons and notice. Any failure leaves the session scope-only with NOTICE_FAILED."""
    # TODO(S2): apply.slot_specs; ops.take(paths, env, specs, ops.owner(env), gen.n);
    #   preflight not ok → reasons/notice; error or LeaseError → scope-only, NOTICE_FAILED.
    raise NotImplementedError


def import_environment(paths: Paths, env: Mapping[str, str]) -> bool:
    """Step 5: `systemctl --user import-environment IMPORT_VARS` (only while the lease is held:
    a scope-only session must not reach an open Umbriel's user manager)."""
    # TODO(S2): system.run with the names; skipped/failed → False and a warning.
    raise NotImplementedError


def stop_guard(paths: Paths) -> bool:
    """`systemctl --user stop aptus-guard.service`: the guard releases on SIGTERM."""
    # TODO(S2): system.run; True when it succeeded.
    raise NotImplementedError


def start(paths: Paths, env: Mapping[str, str]) -> StartReport:
    """Steps 1–6 of 07 §3 / 02 §7 up to the exec: recover, render, the guard, take (with
    preflight), the environment import (lease only), then the scope and Own targets and hooks of
    the generation (apply.apply_generation, also scope-only). Never raises: each failure becomes a
    warning and, where it matters, scope-only mode."""
    # TODO(S2): require_safe_home (UnsafeHome → scope-only, nothing written); recover_step;
    #   gen = render_step; no gen → scope-only "render failed"; guard = start_guard; no guard →
    #   scope-only "guard did not start"; else lease_step; held → import_environment;
    #   apply.apply_generation(paths, manifest, gen, signature); report.generation, report.guard.
    #   The S1 body below stays until then.
    log = logging.getLogger("aptus.session")
    report = StartReport()
    paths.make_runtime()
    paths.state.mkdir(parents=True, exist_ok=True)
    test = paths.test
    # Steps 1–5 of 02 §7. In S1 none of them runs: the lease, the renderer and the guard arrive
    # with S2, and importing the environment without the guard would leak into Umbriel's manager.
    for step in ("aptus-lease recover", "aptus-theme render", "aptus-lease take",
                 "systemctl --user import-environment", "systemd-run aptus-guard and bound units"):
        log.info("skipped: %s (%s)", step, "S2; test mode" if test else "S2")
    report.mode = Mode.SCOPE_ONLY
    report.reasons.append("S2")
    if test:
        report.reasons.append("test mode")
    return report


def write_status(paths: Paths, report: StartReport) -> None:
    """<runtime>/session.json for `aptus msg shell state`, the Lease service and the doctor."""
    # TODO(S2): add "notice", "generation", "guard" (the Lease service reads them).
    paths.make_runtime()
    atomic.write_json(paths.session_status, {
        "mode": report.mode.value,
        "reasons": report.reasons,
        "warnings": report.warnings,
        "pid": os.getpid(),
        "signature": os.environ.get(hypr.ENV_SIG, ""),
        "started": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "test": paths.test,
    })


def exec_supervisor(paths: Paths) -> None:
    """Replace this process with aptus-supervise (never returns)."""
    launcher = str(paths.bin / "aptus-supervise")
    os.execv(sys.executable, [sys.executable, "-I", launcher])


def stop(paths: Paths) -> int:
    """The logout path's last step: nothing to release before S2; returns 0."""
    # TODO(S2): stop_guard (the guard releases); not running → ops.release directly when this
    #   session (HYPRLAND_INSTANCE_SIGNATURE) holds the lease; 0 unless that release failed.
    logging.getLogger("aptus.session").info("stop: nothing to release before S2")
    return 0


def main(argv: Sequence[str]) -> int:
    log = setup("session")
    p = get()
    if list(argv) == ["stop"]:
        return stop(p)
    if list(argv) != ["start"]:
        print("usage: aptus-session start | stop", file=sys.stderr)
        return 2
    reason = check_environment(os.environ)
    if reason:
        log.info("not starting: %s", reason)
        return 0
    report = start(p, os.environ)
    write_status(p, report)
    log.info("mode %s (%s); starting the supervisor", report.mode.value, ", ".join(report.reasons))
    try:
        exec_supervisor(p)
    except OSError as e:
        log.error("cannot exec aptus-supervise: %s", e)
    return 1
