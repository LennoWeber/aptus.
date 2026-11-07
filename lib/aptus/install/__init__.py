"""Helpers for install.sh (11-roadmap §4, 09-hyprland §1).

install.sh only plans and asks: every change outside the repo is listed first, the
hyprland.lua edit is shown as a diff, and nothing happens without a "y". Leftovers of v1 are
moved to ~/.local/state/aptus-v1-backup/<date>/, never deleted.
"""
from __future__ import annotations

import os
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


KINDS = ("mkdir", "link", "move", "edit-hyprland")


def check_action(paths: Paths, action: Action) -> None:
    """Invariant: no action leaves HOME, changes anything inside the repo (also not through a
    link), or touches Umbriel's or Noctalia's files; moves go only to the v1 backup or the install
    state (uninstall keeps the scope mirrors there), a link points into the repo (target None removes
    it), and the only edited file is ~/.config/hypr/hyprland.lua (02 §2, CLAUDE.md).
    Raises RuntimeError("install invariant: …")."""
    def real(p: Path) -> str:      # the parent resolved, the last component itself (a link stays a link)
        return os.path.join(os.path.realpath(p.parent), p.name)

    def under(p: str, root: Path) -> bool:
        r = os.path.realpath(root)
        return p == r or p.startswith(r + os.sep)

    def refuse(why: str) -> None:
        raise RuntimeError(f"install invariant: {action.kind} {action.path}: {why}")

    if action.kind not in KINDS:
        refuse("unknown kind")
    where = real(action.path)
    if not under(where, paths.home):
        refuse("outside HOME")
    if under(where, paths.repo):
        refuse("inside the repository")
    for protected in (paths.config_home / "umbriel", paths.state_home / "noctalia"):
        if under(where, protected):
            refuse("Umbriel or Noctalia files")
    if action.kind == "edit-hyprland" and action.path != paths.hyprland_lua:
        refuse("not hyprland.lua")
    if action.kind == "move" and (action.target is None or not (under(real(action.target), paths.v1_backup)
                                                              or under(real(action.target), paths.install_state))):
        refuse("a move outside the v1 backup and the install state")
    if action.kind == "link" and action.target is not None and not under(os.path.realpath(action.target), paths.repo):
        refuse("a link that does not point into the repository")


def v1_leftovers(paths: Paths) -> list[Path]:
    """The v1 files of 11 §4.3 that exist (symlinks into the old repo count even if dangling)."""
    raise NotImplementedError


# TODO(phase): ~/.config/hypr is a stow link into ~/dotfiles: plan() shows the resolved path of the
#   aptus link (an untracked file in the dotfiles repo) and asks for it as its own group.
def plan(paths: Paths) -> list[Action]:
    """Directories (state, scope mirrors, ~/.local/bin), links (~/.config/hypr/aptus → hypr/,
    ~/.local/bin/aptus* → bin/), v1 leftovers to move, the hyprland.lua edit."""
    raise NotImplementedError


def plan_uninstall(paths: Paths) -> list[Action]:
    raise NotImplementedError


def describe(actions: Sequence[Action]) -> str:
    raise NotImplementedError


# TODO(phase): apply refuses to write through a symlink (a test once overwrote <repo>/bin/aptus
#   through ~/.local/bin/aptus); links are replaced, never written into.
def apply(paths: Paths, actions: Sequence[Action]) -> None:
    """Carry out approved actions (backups first: hyprland.lua.<date> in install_state)."""
    for action in actions:
        check_action(paths, action)
    raise NotImplementedError


def main(argv: Sequence[str]) -> int:
    """install.sh [--uninstall]: list, ask per group, apply. Every group needs its own "y"."""
    raise NotImplementedError
