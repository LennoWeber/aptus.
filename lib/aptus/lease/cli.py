"""aptus-lease take | update [ids…] | release | recover | status [--json] (02 §5).

The command line of the lease package, the only code that writes a leased slot (aptus-session,
aptus-theme and aptus-guard call it in-process). `take` and `update` read the slot content from
the current theme generation (theme/current) and theme/targets.toml. Under APTUS_TEST=1 it refuses
a HOME that is not a temporary directory (paths.require_safe_home).
"""
from __future__ import annotations

import argparse
import dataclasses
import json
import os
import sys
from collections.abc import Sequence
from typing import Any

from .. import log
from ..paths import Paths
from ..theme import apply, render, targets
from . import guard, ops
from .journal import JournalError


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="aptus-lease", description="The lease on Noctalia's shared "
                                "artifacts (02-isolation §5).")
    sub = p.add_subparsers(dest="command", required=True)
    sub.add_parser("take", help="take the lease for this Hyprland session")
    u = sub.add_parser("update", help="write the current theme generation into the held slots")
    u.add_argument("ids", nargs="*", help="target ids (all when none)")
    sub.add_parser("release", help="give Noctalia's paint back")
    sub.add_parser("recover", help="release a lease whose Hyprland is gone (login)")
    s = sub.add_parser("status", help="the journal's state")
    s.add_argument("--json", action="store_true")
    return p


def _generation(paths: Paths) -> render.Generation:
    gen = render.current(paths)
    if gen is None:
        raise ops.LeaseError("no theme generation yet (aptus-theme render)")
    return gen


def cmd_take(paths: Paths) -> int:
    """Take for this Hyprland session (HYPRLAND_INSTANCE_SIGNATURE) with the current generation;
    exit 0 when held, 1 otherwise (the reason on stderr). Refused without a running guard: no
    lease without someone to give it back."""
    if not guard.active(paths):
        print("aptus-lease take: aptus-guard is not running; no lease without a guard",
              file=sys.stderr)
        return 1
    gen = _generation(paths)
    manifest = targets.load(paths.targets, paths.templates)
    specs = apply.slot_specs(paths, manifest, gen)
    report = ops.take(paths, os.environ, specs, ops.owner(paths, os.environ), gen.n)
    if report.held:
        print(f"held: {len(report.slots)} slots")
        return 0
    why = report.error or ", ".join(report.preflight.reasons if report.preflight else [])
    print(f"aptus-lease take: not taken: {why}", file=sys.stderr)
    return 1


def cmd_update(paths: Paths, ids: Sequence[str]) -> int:
    """Update the slots of the given target ids (all when none) from the current generation;
    only from the Hyprland session that holds the lease (HYPRLAND_INSTANCE_SIGNATURE)."""
    if not ops.holds(paths, ops.signature()):
        print("aptus-lease update: this session does not hold the lease", file=sys.stderr)
        return 1
    gen = _generation(paths)
    manifest = targets.load(paths.targets, paths.templates)
    report = ops.update(paths, apply.slot_specs(paths, manifest, gen, ids), gen.n)
    for sid, why in sorted(report.failed.items()):
        print(f"failed: {sid}: {why}", file=sys.stderr)
    print(f"written: {len(report.written)}")
    return 1 if report.failed else 0


def finish_release(paths: Paths, report: ops.ReleaseReport, signature: str) -> int:
    """After a release that acted: the release hooks and the imported environment (as the
    guard does); exit 1 when a slot failed."""
    guard.after_release(paths, report, signature)
    for sid, why in sorted(report.failed.items()):
        print(f"failed: {sid}: {why}", file=sys.stderr)
    return 1 if report.failed else 0


def cmd_release(paths: Paths) -> int:
    """The manual escape hatch (and uninstall's release-lease): releases whatever lease is held,
    also a live session's, which then goes on scope-only (02 §5.6)."""
    return finish_release(paths, ops.release(paths), ops.signature())


def cmd_recover(paths: Paths) -> int:
    """Exit 0 also when there was nothing to do (aptus-recover.service must not fail for that)."""
    try:
        report = ops.recover(paths)
    except JournalError as e:
        print(f"aptus-lease recover: {e}; see `aptus doctor isolation`", file=sys.stderr)
        return 1
    return finish_release(paths, report, "")


def status_dict(s: ops.Status) -> dict[str, Any]:
    return {"state": s.state.value if s.state else "none", "ownerAlive": s.owner_alive,
            "owner": dataclasses.asdict(s.owner) if s.owner else None, "slots": s.slots,
            "failed": s.failed, "generation": s.generation, "conflicts": s.conflicts}


def cmd_status(paths: Paths, as_json: bool) -> int:
    d = status_dict(ops.status(paths))
    if as_json:
        print(json.dumps(d, sort_keys=True))
        return 0
    owner = d["owner"]
    print(f"state: {d['state']}")
    if owner:
        print(f"owner: Hyprland {owner['hyprland_pid']} ({'alive' if d['ownerAlive'] else 'gone'}), "
              f"taken {owner['taken_at']}")
    print(f"slots: {d['slots']}" + (f", failed: {', '.join(d['failed'])}" if d["failed"] else ""))
    print(f"generation: {d['generation']}\nconflicts: {d['conflicts']}")
    return 0


def main(argv: Sequence[str]) -> int:
    args = parser().parse_args(list(argv))
    started = log.setup_tool("lease", "theme")
    if started is None:
        return 3
    paths, logger = started
    try:
        if args.command == "take":
            return cmd_take(paths)
        if args.command == "update":
            return cmd_update(paths, args.ids)
        if args.command == "release":
            return cmd_release(paths)
        if args.command == "recover":
            return cmd_recover(paths)
        return cmd_status(paths, args.json)
    except (ops.LeaseError, JournalError, ValueError, OSError) as e:
        logger.error("%s: %s", args.command, e)
        print(f"aptus-lease {args.command}: {e}", file=sys.stderr)
        return 1
