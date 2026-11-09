"""aptus-lease take | update [ids…] | release | recover | status [--json] (02 §5).

The only command that writes a leased slot. `take` and `update` read the slot content from the
current theme generation (theme/current) and theme/targets.toml. Under APTUS_TEST=1 it refuses a
HOME that is not a temporary directory (paths.require_safe_home).
"""
from __future__ import annotations

import argparse
from collections.abc import Sequence

from ..paths import Paths


def parser() -> argparse.ArgumentParser:
    raise NotImplementedError


def cmd_take(paths: Paths) -> int:
    """Take for this Hyprland session (HYPRLAND_INSTANCE_SIGNATURE) with the current generation;
    exit 0 when held, 1 otherwise (the reason on stderr)."""
    raise NotImplementedError


def cmd_update(paths: Paths, ids: Sequence[str]) -> int:
    """Update the slots of the given target ids (all when none) from the current generation."""
    raise NotImplementedError


def cmd_release(paths: Paths) -> int:
    raise NotImplementedError


def cmd_recover(paths: Paths) -> int:
    """Exit 0 also when there was nothing to do (aptus-recover.service must not fail for that)."""
    raise NotImplementedError


def cmd_status(paths: Paths, as_json: bool) -> int:
    raise NotImplementedError


def main(argv: Sequence[str]) -> int:
    raise NotImplementedError
