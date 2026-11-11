"""aptus-theme render | apply | targets (08 §4–§6); also `aptus theme …`.

    render [--inputs JSON]   write a generation (inputs from settings.json when omitted)
    apply  [--inputs JSON]   render, then lease update / scope / own / hooks; JSON report on stdout
    targets [--json]         every target with its mechanism, state and the coverage report
"""
from __future__ import annotations

import argparse
import json
import sys
from collections.abc import Sequence

from .. import log
from .. import paths as paths_mod
from ..lease import ops
from ..paths import Paths, UnsafeHome
from . import inputs as inputs_mod
from . import noctalia, render, targets
from .targets import Mechanism


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="aptus-theme", description="Render and apply aptus's theme "
                                "to the apps (08-theming).")
    sub = p.add_subparsers(dest="command", required=True)
    for name, text in (("render", "write a theme generation"),
                       ("apply", "render, then paint the apps; a JSON report on stdout")):
        c = sub.add_parser(name, help=text)
        c.add_argument("--inputs", metavar="JSON", help="the resolve inputs (default: settings.json)")
    t = sub.add_parser("targets", help="every target, its state and the Noctalia coverage")
    t.add_argument("--json", action="store_true")
    return p


def _inputs(paths: Paths, inputs_json: str | None) -> inputs_mod.Inputs:
    return inputs_mod.from_json(inputs_json) if inputs_json else inputs_mod.from_settings(paths)


def cmd_render(paths: Paths, inputs_json: str | None) -> int:
    gen = render.render(paths, _inputs(paths, inputs_json), targets.load(paths.targets, paths.templates))
    print(f"gen-{gen.n}" + (" (unchanged)" if gen.reused else ""))
    for tid, why in sorted(gen.failed.items()):
        print(f"failed: {tid}: {why}", file=sys.stderr)
    return 0


def cmd_apply(paths: Paths, inputs_json: str | None) -> int:
    """Exit 1 only when the render itself failed (bad inputs, tokens or manifest)."""
    from . import apply
    report = apply.apply(paths, _inputs(paths, inputs_json), ops.signature())
    print(apply.report_json(report))
    return 0


def _state(paths: Paths, t: targets.Target) -> str:
    if t.mechanism == Mechanism.NEVER:
        return "stays Noctalia's"
    if not targets.active(paths, t):
        return "not installed"
    return "installed"


def targets_report(paths: Paths) -> dict:
    """Targets with mechanism and state, and the coverage of Noctalia's enabled templates."""
    manifest = targets.load(paths.targets, paths.templates)
    rows = [{"id": t.id, "row": t.row, "mechanism": t.mechanism.value, "state": _state(paths, t),
             "note": t.note} for t in manifest.targets]
    slot_paths = {s: t.id for t in manifest.targets for _, s in targets.slots(paths, t)}
    enabled = noctalia.enabled(paths)
    cov = targets.coverage(manifest, enabled, slot_paths)
    return {"targets": rows, "covered": cov.covered, "kept": cov.kept, "inert": cov.inert,
            "uncovered": cov.uncovered, "noctaliaError": enabled.error}


def cmd_targets(paths: Paths, as_json: bool) -> int:
    """One line per target: id, mechanism, installed or not, and the coverage of Noctalia's
    enabled templates ("uncovered: <id>" lines)."""
    rep = targets_report(paths)
    if as_json:
        print(json.dumps(rep, indent=2, sort_keys=True))
        return 0
    for r in rep["targets"]:
        print(f"{r['id']:<14} {r['mechanism']:<6} {r['state']}")
    for nid in rep["uncovered"]:
        print(f"uncovered: {nid}")
    if rep["noctaliaError"]:
        print(f"noctalia config: {rep['noctaliaError']}", file=sys.stderr)
    return 0


def main(argv: Sequence[str]) -> int:
    args = parser().parse_args(list(argv))
    paths = paths_mod.get()
    try:                                  # before the logs: under test they go to $HOME
        paths_mod.require_safe_home(paths)
    except UnsafeHome as e:
        print(f"aptus-theme: {e}", file=sys.stderr)
        return 3
    logger = log.setup("theme")
    log.setup("lease", "aptus-theme")
    try:
        if args.command == "targets":
            return cmd_targets(paths, args.json)
        if args.command == "render":
            return cmd_render(paths, args.inputs)
        return cmd_apply(paths, args.inputs)
    except (ValueError, OSError, RuntimeError) as e:
        logger.error("%s failed: %s", args.command, e)
        print(f"aptus-theme {args.command}: {e}", file=sys.stderr)
        return 1
