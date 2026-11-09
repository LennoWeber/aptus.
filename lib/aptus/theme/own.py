"""Own targets (02 §3 Own, 08 §8): files only aptus reads, or that are inert outside Hyprland.
own.json records every file and directory aptus created, so uninstall removes only those."""
from __future__ import annotations

from collections.abc import Sequence
from pathlib import Path

from ..paths import Paths
from .render import Generation
from .targets import Target

ICON_SIZES = ("16x16", "22x22", "24x24", "32x32", "48x48", "64x64")
ICON_THEMES = ("aptus-icons-dark", "aptus-icons-light")


def write_files(paths: Paths, target: Target, gen: Generation) -> list[Path]:
    """Copy the target's rendered files to their `dest` (atomic); returns the destinations."""
    raise NotImplementedError


def icons(paths: Paths, folder: str) -> list[Path]:
    """aptus-icons-{dark,light}: index.theme inheriting Papirus-Dark/-Light and hicolor, and per
    size a places/ directory of `folder*.svg` symlinks to Papirus's `folder-<folder>*.svg`.
    Rebuilt only when the folder colour changed; Papirus is never modified."""
    raise NotImplementedError


def bat(paths: Paths) -> bool:
    """`bat cache --build --source <bat_source> --target <cache_bat>` (BAT_CACHE_PATH in Hyprland)."""
    raise NotImplementedError


def record(paths: Paths, created: Sequence[Path]) -> None:
    """Add paths to own.json (only those aptus created, never a file that existed before)."""
    raise NotImplementedError


def recorded(paths: Paths) -> list[Path]:
    raise NotImplementedError


def apply(paths: Paths, target: Target, gen: Generation) -> None:
    """Write one Own target (files, then its builtin step)."""
    raise NotImplementedError
