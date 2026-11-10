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
from .lease import guard, journal, ops, preflight, system
from .lease.invariants import InvariantError
from .lease.journal import JournalError
from .log import setup
from .paths import Paths, UnsafeHome, get, require_safe_home
from .theme import apply, inputs, render, targets
from .theme.render import Generation
from .theme.targets import Manifest


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
    """Step 1: recover (a leftover lease of a dead owner is released first, with its hooks and
    the environment it imported); a failure is a warning, and take refuses afterwards if a
    journal is still there."""
    try:
        rel = ops.recover(paths)
    except (JournalError, ops.LeaseError, InvariantError) as e:
        report.warnings.append(f"recover: {e}")
        return
    if rel.acted and guard.after_release(paths, rel, "") == guard.GuardState.FAILED:
        report.warnings.append(f"recover: not restored: {', '.join(sorted(rel.failed))}")


def load_manifest(paths: Paths, report: StartReport) -> Manifest | None:
    try:
        return targets.load(paths.targets, paths.templates)
    except (targets.ManifestError, OSError) as e:
        report.warnings.append(f"targets.toml: {e}")
        return None


def render_step(paths: Paths, manifest: Manifest, report: StartReport) -> Generation | None:
    """Step 2: render a generation from settings.json; when the renderer fails, the last good
    generation (render.current), else None: no lease then (08 §9)."""
    try:
        gen = render.render(paths, inputs.from_settings(paths), manifest)
    except Exception as e:  # noqa: BLE001 - the session starts whatever the renderer does
        report.warnings.append(f"render: {type(e).__name__}: {e}")
        return render.current(paths)
    for tid, why in sorted(gen.failed.items()):
        report.warnings.append(f"render {tid}: {why}")
    return gen


def start_guard(paths: Paths, env: Mapping[str, str]) -> bool:
    """Step 3, before any slot is written: `systemd-run --user --unit=aptus-guard --collect …
    aptus-guard <hyprland-pid> <signature>`; True when the unit is active. No guard, no lease."""
    log = logging.getLogger("aptus.session")
    try:
        who = ops.owner(paths, env)
    except ops.LeaseError as e:
        log.warning("no guard: %s", e)
        return False
    r = system.run(paths, ["systemd-run", "--user", f"--unit={guard.UNIT}", "--collect", "--quiet",
                           "--property=Type=exec", str(paths.bin / "aptus-guard"),
                           str(who.hyprland_pid), who.hyprland_signature])
    if r.skipped or r.code != 0:
        log.warning("systemd-run aptus-guard failed: %s", r.stderr.strip() or "not available")
        return False
    r = system.run(paths, ["systemctl", "--user", "is-active", "--quiet", f"{guard.UNIT}.service"])
    return not r.skipped and r.code == 0


def lease_step(paths: Paths, env: Mapping[str, str], manifest: Manifest, gen: Generation,
               report: StartReport) -> None:
    """Step 4: ops.take with the generation's slot specs (preflight inside); sets report.mode,
    reasons and notice. Any failure leaves the session scope-only with NOTICE_FAILED."""
    try:
        taken = ops.take(paths, env, apply.slot_specs(paths, manifest, gen), ops.owner(paths, env),
                         gen.n)
    except (ops.LeaseError, InvariantError, JournalError, OSError, ValueError) as e:
        report.reasons.append("the lease failed")
        report.warnings.append(f"take: {e}")
        report.notice = preflight.NOTICE_FAILED
        return
    if taken.held:
        report.mode = Mode.LEASE
        return
    if taken.preflight is not None and not taken.preflight.ok:
        report.reasons += taken.preflight.reasons
        report.notice = taken.preflight.notice
        return
    report.reasons.append("the lease failed")
    report.warnings.append(f"take: {taken.error}")
    report.notice = preflight.NOTICE_FAILED


def import_environment(paths: Paths, env: Mapping[str, str]) -> bool:
    """Step 5: `systemctl --user import-environment IMPORT_VARS` (only while the lease is held:
    a scope-only session must not reach an open Umbriel's user manager)."""
    r = system.run(paths, ["systemctl", "--user", "import-environment", *IMPORT_VARS])
    if r.skipped or r.code != 0:
        logging.getLogger("aptus.session").warning("import-environment failed: %s",
                                                   r.stderr.strip() or "not available")
        return False
    return True


def stop_guard(paths: Paths) -> bool:
    """`systemctl --user stop aptus-guard.service`: the guard releases on SIGTERM."""
    r = system.run(paths, ["systemctl", "--user", "stop", f"{guard.UNIT}.service"], timeout=30)
    return not r.skipped and r.code == 0


def _signature(env: Mapping[str, str]) -> str:
    try:
        return hypr.signature(env)
    except hypr.HyprError:
        return ""


def start(paths: Paths, env: Mapping[str, str]) -> StartReport:
    """Steps 1–6 of 07 §3 / 02 §7 up to the exec: recover, render, the guard, take (with
    preflight), the environment import (lease only), then the scope and Own targets and hooks of
    the generation (apply.apply_generation, also scope-only). Never raises: each failure becomes a
    warning and, where it matters, scope-only mode."""
    report = StartReport()
    try:
        require_safe_home(paths)
    except UnsafeHome as e:
        report.reasons.append("unsafe HOME")
        report.warnings.append(str(e))
        return report
    paths.make_runtime()
    paths.state.mkdir(parents=True, exist_ok=True)
    recover_step(paths, report)
    manifest = load_manifest(paths, report)
    gen = render_step(paths, manifest, report) if manifest is not None else None
    report.guard = start_guard(paths, env)
    if gen is None or manifest is None:
        report.reasons.append("no theme generation")
        return report
    report.generation = gen.n
    if not report.guard:
        report.reasons.append("the guard did not start")
        report.notice = preflight.NOTICE_FAILED
    else:
        lease_step(paths, env, manifest, gen, report)
    if report.mode is Mode.LEASE and not import_environment(paths, env):
        report.warnings.append("systemctl --user import-environment failed")
    try:
        applied = apply.apply_generation(paths, manifest, gen, _signature(env))
        report.warnings += [f"apply {tid}: {why}" for tid, why in sorted(applied.failed.items())]
    except Exception as e:  # noqa: BLE001
        report.warnings.append(f"apply: {type(e).__name__}: {e}")
    return report


def write_status(paths: Paths, report: StartReport) -> None:
    """<runtime>/session.json for `aptus msg shell state`, the Lease service and the doctor."""
    paths.make_runtime()
    atomic.write_json(paths.session_status, {
        "mode": report.mode.value,
        "reasons": report.reasons,
        "warnings": report.warnings,
        "notice": report.notice,
        "generation": report.generation,
        "guard": report.guard,
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
    """The logout path's last step: stop the guard (it releases on SIGTERM); without a running
    guard release directly when this session (HYPRLAND_INSTANCE_SIGNATURE) holds the lease, with
    the hooks and the environment as the guard would. 0 unless that release failed."""
    if stop_guard(paths):
        return 0
    sig = _signature(os.environ)
    try:
        j = journal.load(paths)
    except JournalError as e:
        logging.getLogger("aptus.session").error("stop: %s", e)
        return 1
    if not sig or j is None or j.owner is None or not ops.held_by(paths, sig):
        return 0
    rel = ops.release(paths, expect=(sig, j.owner.hyprland_pid))
    return 1 if guard.after_release(paths, rel, sig) == guard.GuardState.FAILED else 0


def main(argv: Sequence[str]) -> int:
    p = get()
    try:                                  # before the logs: under test they go to $HOME
        require_safe_home(p)
    except UnsafeHome as e:
        print(f"aptus-session: {e}", file=sys.stderr)
        return 3
    log = setup("session")
    setup("lease", "aptus-session")
    setup("theme", "aptus-session")
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
