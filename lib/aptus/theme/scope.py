"""Scope targets (02 §3 Scope, 08 §6 step 2): files only Hyprland's process tree reads, through an
environment variable set in hyprland.lua (KITTY_CONFIG_DIRECTORY, YAZI_CONFIG_HOME,
STARSHIP_CONFIG). Each lives in ~/.local/state/aptus/scope/ and is swapped atomically:
`scope/<into>` is a symlink to `scope/.<into>.<generation>`, a directory (mirror) or a file
(starship.toml); the previous build is removed after the swap. install.sh creates only `scope/`.
Everything runs under the theme lock."""
from __future__ import annotations

from collections.abc import Sequence
from pathlib import Path

from ..lease import invariants
from ..paths import Paths
from .render import Generation
from .targets import FileOut, Target


def mirror(source: Path, build: Path, files: Sequence[tuple[FileOut, Path]]) -> None:
    """Fill the empty dir `build` with symlinks to every entry of `source`, except along each
    file's `at` (e.g. themes/noctalia.conf): its parent directories become real directories (again
    of links) and `at` itself is a copy of the rendered file. A `missing_only` file is used only
    when `source` has no `at`. `source` itself is only read."""
    # TODO(S2): for each entry of source: symlink, except the first component of an `at` path: a
    #   real dir recursing with the rest; at itself: copy of the rendered file
    #   (missing_only and the source has it → link instead).
    raise NotImplementedError


def marked(source: Path, begin: str, end: str, block: str) -> str:
    """The text of `source` with everything between the `begin` and `end` marker lines replaced by
    `block` (markers kept); without markers, `block` is appended between new markers."""
    # TODO(S2): lines; find begin and end; replace between; absent → append begin, block, end.
    raise NotImplementedError


def swap(paths: Paths, into: str, build: Path) -> None:
    """Point scope/<into> at `build` (a sibling dir or file) atomically and remove the previous
    build. A real file or directory at scope/<into> (from an older install) is moved aside to
    scope/.<into>.old-<time> first."""
    # TODO(S2): atomic.symlink(build.name, scope/<into>); remove the old target if it was a build.
    invariants.check_scope_name(into)
    invariants.writable(paths, paths.scope / into, kind="scope")
    raise NotImplementedError


def apply(paths: Paths, target: Target, gen: Generation) -> None:
    """Rebuild one scope target from the generation."""
    # TODO(S2): build in scope/.<into>.<gen.n>: mirror or marked (atomic write); swap.
    raise NotImplementedError
