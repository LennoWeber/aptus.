"""`aptus-session start | stop` (02-isolation §7, 07-architecture §3)."""
from __future__ import annotations

import logging
import os
import sys
import time
from collections.abc import Mapping, Sequence
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from enum import Enum

from . import atomic, hypr
from .lease import guard, invariants, journal, ops, preflight, system
from .lease.invariants import InvariantError
from .lease.journal import JournalError
from .log import setup_tool
from .paths import Paths, UnsafeHome, require_safe_home
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
        if rel.acted and guard.after_release(paths, rel, "") == guard.GuardState.FAILED:
            report.warnings.append(f"recover: not restored: {', '.join(sorted(rel.failed))}")
    except Exception as e:  # noqa: BLE001 - the session starts whatever recover does
        report.warnings.append(f"recover: {type(e).__name__}: {e}")


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
    """Step 3, before any slot is written: `systemd-run --user --unit=aptus-guard --collect
    --property=Type=notify … aptus-guard <hyprland-pid> <signature>` (an old guard.state is
    removed first). systemd-run returns once the guard watches (its READY=1, sent after
    guard.state `ok`), or fails when the guard exited first or sent nothing within READY_TIMEOUT
    (TimeoutStartSec: systemd stops it). True when it watches. No guard, no lease."""
    log = logging.getLogger("aptus.session")
    try:
        who = ops.owner(paths, env)
    except ops.LeaseError as e:
        log.warning("no guard: %s", e)
        return False
    invariants.writable(paths, paths.guard_state, kind="state")
    paths.guard_state.unlink(missing_ok=True)
    r = system.run(paths, ["systemd-run", "--user", f"--unit={guard.UNIT}", "--collect", "--quiet",
                           "--property=Type=notify",
                           f"--property=TimeoutStartSec={round(guard.READY_TIMEOUT * 1000)}ms",
                           str(paths.bin / "aptus-guard"), str(who.hyprland_pid),
                           who.hyprland_signature], timeout=guard.READY_TIMEOUT + 2)
    if not r.ok:
        log.warning("aptus-guard did not start: %s", r.stderr.strip() or (
            "not available" if r.skipped else f"no READY=1 (systemd-run exit {r.code})"))
        return False
    return True


def lease_step(paths: Paths, env: Mapping[str, str], manifest: Manifest, gen: Generation,
               report: StartReport) -> apply.Taken | None:
    """Step 4: the Own targets a leased key requires (apply.apply_required), then ops.take with
    the generation's slot specs (preflight inside); sets report.mode, reasons and notice and
    returns the specs and the slot ids taken (None when not held). Any failure leaves the
    session scope-only with NOTICE_FAILED."""
    try:
        apply.apply_required(paths, manifest, gen)
        specs = apply.slot_specs(paths, manifest, gen)
        taken = ops.take(paths, env, specs, ops.owner(paths, env), gen.n)
    except (ops.LeaseError, InvariantError, JournalError, OSError, ValueError) as e:
        report.reasons.append("the lease failed")
        report.warnings.append(f"take: {e}")
        report.notice = preflight.NOTICE_FAILED
        return None
    if taken.held:
        report.mode = Mode.LEASE
        return apply.Taken(specs, taken.slots)
    if taken.preflight is not None and not taken.preflight.ok:
        report.reasons += taken.preflight.reasons
        report.notice = taken.preflight.notice
        return None
    report.reasons.append("the lease failed")
    report.warnings.append(f"take: {taken.error}")
    report.notice = preflight.NOTICE_FAILED
    return None


def import_environment(paths: Paths) -> bool:
    """Step 5: `systemctl --user import-environment IMPORT_VARS` (only while the lease is held:
    a scope-only session must not reach an open Umbriel's user manager)."""
    r = system.run(paths, ["systemctl", "--user", "import-environment", *IMPORT_VARS])
    if not r.ok:
        logging.getLogger("aptus.session").warning("import-environment failed: %s",
                                                   r.stderr.strip() or "not available")
        return False
    return True


def environment_step(paths: Paths, env: Mapping[str, str], report: StartReport) -> None:
    """Step 5 with its race closed: when the guard released between the take and the import
    (Hyprland gone, another session opened), the variables just imported are unset again and
    the session goes on scope-only."""
    if not import_environment(paths):
        report.warnings.append("systemctl --user import-environment failed")
    if not ops.holds(paths, ops.signature(env)):
        guard.unset_environment(paths)
        report.mode = Mode.SCOPE_ONLY
        report.reasons.append("the guard released the lease")
        report.notice = report.notice or preflight.NOTICE_OTHER_SESSION


def stop_guard(paths: Paths) -> bool:
    """`systemctl --user stop aptus-guard.service`: the guard releases on SIGTERM."""
    r = system.run(paths, ["systemctl", "--user", "stop", f"{guard.UNIT}.service"], timeout=30)
    return r.ok


def start(paths: Paths, env: Mapping[str, str]) -> StartReport:
    """Steps 1–6 of 07 §3 / 02 §7 up to the exec: recover, render, the guard (started first, in
    a thread, and waited for before take), take (with preflight), the environment import (lease
    only), then the scope and Own targets and hooks of the generation (apply.apply_generation,
    also scope-only; the slots just taken are not written again). Never raises: each failure
    becomes a warning and, where it matters, scope-only mode."""
    report = StartReport()
    try:
        require_safe_home(paths)
    except UnsafeHome as e:
        report.reasons.append("unsafe HOME")
        report.warnings.append(str(e))
        return report
    paths.make_runtime()
    paths.state.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=1) as pool:
        guard_started = pool.submit(start_guard, paths, env)    # alongside steps 1 and 2
        recover_step(paths, report)
        manifest = load_manifest(paths, report)
        gen = render_step(paths, manifest, report) if manifest is not None else None
        report.guard = guard_started.result()
    if gen is None or manifest is None:
        report.reasons.append("no theme generation")
        return report
    report.generation = gen.n
    taken = None
    if not report.guard:
        report.reasons.append("the guard did not start")
        report.notice = preflight.NOTICE_FAILED
    else:
        taken = lease_step(paths, env, manifest, gen, report)
    if report.mode is Mode.LEASE:
        environment_step(paths, env, report)
    try:
        applied = apply.apply_generation(paths, manifest, gen, ops.signature(env), taken=taken)
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
    sig = ops.signature()
    try:
        j = journal.load(paths)
    except JournalError as e:
        logging.getLogger("aptus.session").error("stop: %s", e)
        return 1
    if not sig or not ops.owned_by(j, sig):
        return 0
    rel = ops.release(paths, expect=(sig, j.owner.hyprland_pid))
    return 1 if guard.after_release(paths, rel, sig) == guard.GuardState.FAILED else 0


def main(argv: Sequence[str]) -> int:
    started = setup_tool("session", "lease", "theme")
    if started is None:
        return 3
    p, log = started
    if list(argv) == ["stop"]:
        return stop(p)
    if list(argv) != ["start"]:
        print("usage: aptus-session start | stop", file=sys.stderr)
        return 2
    reason = check_environment(os.environ)
    if reason:
        log.info("not starting: %s", reason)
        return 0
    try:
        report = start(p, os.environ)
    except Exception as e:  # noqa: BLE001 - Hyprland must get its shell whatever start did
        log.exception("start failed")
        report = StartReport(reasons=["start failed"], warnings=[f"{type(e).__name__}: {e}"])
    try:
        write_status(p, report)
    except OSError as e:
        log.error("cannot write session.json: %s", e)
    log.info("mode %s (%s); starting the supervisor", report.mode.value, ", ".join(report.reasons))
    try:
        exec_supervisor(p)
    except OSError as e:
        log.error("cannot exec aptus-supervise: %s", e)
    return 1
