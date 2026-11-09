"""aptus-lease take | update [ids…] | release | recover | status [--json] (02 §5).

The command line of the lease package, the only code that writes a leased slot (aptus-session,
aptus-theme and aptus-guard call it in-process). `take` and `update` read the slot content from
the current theme generation (theme/current) and theme/targets.toml. Under APTUS_TEST=1 it refuses
a HOME that is not a temporary directory (paths.require_safe_home).
"""
from __future__ import annotations

import argparse
from collections.abc import Sequence

from ..paths import Paths


def parser() -> argparse.ArgumentParser:
    # TODO(S2): subcommands take, update [ids…], release, recover, status [--json].
    raise NotImplementedError


def cmd_take(paths: Paths) -> int:
    """Take for this Hyprland session (HYPRLAND_INSTANCE_SIGNATURE) with the current generation;
    exit 0 when held, 1 otherwise (the reason on stderr)."""
    # TODO(S2): ops.owner(env); render.current(paths) (none → exit 1); apply.slot_specs;
    #   ops.take(env…); print the preflight reason or the error on stderr.
    raise NotImplementedError


def cmd_update(paths: Paths, ids: Sequence[str]) -> int:
    """Update the slots of the given target ids (all when none) from the current generation."""
    # TODO(S2): current generation; slot_specs(ids); ops.update; failed → exit 1.
    raise NotImplementedError


def cmd_release(paths: Paths) -> int:
    # TODO(S2): ops.release; hooks.run_reloads(report.reloads, env signature or ''); failed → exit
    #   1.
    raise NotImplementedError


def cmd_recover(paths: Paths) -> int:
    """Exit 0 also when there was nothing to do (aptus-recover.service must not fail for that)."""
    # TODO(S2): ops.recover; JournalError → message, exit 1; reloads as in release; else 0 (also
    #   when nothing was to do).
    raise NotImplementedError


def cmd_status(paths: Paths, as_json: bool) -> int:
    # TODO(S2): ops.status as one line per field, or JSON.
    raise NotImplementedError


def main(argv: Sequence[str]) -> int:
    # TODO(S2): log.setup('lease'); paths.get(); require_safe_home (UnsafeHome → exit 3 with the
    #   message); dispatch; LeaseError → exit 1.
    raise NotImplementedError
