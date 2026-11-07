"""Helpers for install.sh (11-roadmap §4, 09-hyprland §1).

install.sh only plans and asks: every change outside the repo is listed first, the
hyprland.lua edit is shown as a diff, and nothing happens without a "y". Leftovers of v1 are
moved to ~/.local/state/aptus-v1-backup/<date>/, never deleted.
"""
from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path

from ..paths import Paths


@dataclass(frozen=True)
class Action:
    kind: str                  # "mkdir" | "link" | "move" | "edit-hyprland"
    path: Path                 # what is created, re-pointed, moved or edited
    target: Path | None = None  # link target, or where a moved file goes
    detail: str = ""           # one line for the listing
    approval: str = ""         # the question group it belongs to ("" = part of the base install)


def v1_leftovers(paths: Paths) -> list[Path]:
    """The v1 files of 11 §4.3 that exist (symlinks into the old repo count even if dangling)."""
    raise NotImplementedError


def plan(paths: Paths) -> list[Action]:
    """Directories (state, scope mirrors, ~/.local/bin), links (~/.config/hypr/aptus → hypr/,
    ~/.local/bin/aptus* → bin/), v1 leftovers to move, the hyprland.lua edit."""
    raise NotImplementedError


def plan_uninstall(paths: Paths) -> list[Action]:
    raise NotImplementedError


def describe(actions: Sequence[Action]) -> str:
    raise NotImplementedError


def apply(paths: Paths, actions: Sequence[Action]) -> None:
    """Carry out approved actions (backups first: hyprland.lua.<date> in install_state)."""
    raise NotImplementedError


def main(argv: Sequence[str]) -> int:
    """install.sh [--uninstall] [--yes-to-base]: list, ask per group, apply."""
    raise NotImplementedError
