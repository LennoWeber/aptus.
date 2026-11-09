"""Scope targets (02 §3 Scope, 08 §6 step 2): files only Hyprland's process tree reads, through an
environment variable set in hyprland.lua (KITTY_CONFIG_DIRECTORY, YAZI_CONFIG_HOME,
STARSHIP_CONFIG). Each lives in ~/.local/state/aptus/scope/ and is swapped atomically: `scope/<into>`
is a symlink to `scope/.<into>.<generation>/`."""
from __future__ import annotations

from collections.abc import Sequence
from pathlib import Path

from ..paths import Paths
from .render import Generation
from .targets import FileOut, Target


def mirror(source: Path, build: Path, files: Sequence[tuple[FileOut, Path]]) -> None:
    """Fill the empty dir `build` with symlinks to every entry of `source`, except along each
    file's `at` (e.g. themes/noctalia.conf): its parent directories become real directories (again
    of links) and `at` itself is a copy of the rendered file. A `missing_only` file is used only
    when `source` has no `at`. `source` itself is only read."""
    raise NotImplementedError


def marked(source: Path, begin: str, end: str, block: str) -> str:
    """The text of `source` with everything between the `begin` and `end` marker lines replaced by
    `block` (markers kept); without markers, `block` is appended between new markers."""
    raise NotImplementedError


def swap(paths: Paths, into: str, build: Path) -> None:
    """Point scope/<into> at `build` atomically and remove the previous build."""
    raise NotImplementedError


def apply(paths: Paths, target: Target, gen: Generation) -> None:
    """Rebuild one scope target from the generation."""
    raise NotImplementedError
