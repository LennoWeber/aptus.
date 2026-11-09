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
    """Copy the target's rendered files to their `dest` (atomic); returns the destinations. A dest
    that exists but is not in own.json (a qt6ct.conf of Lenno's) is never overwritten: that file
    fails with "exists and is not aptus's"."""
    # TODO(S2): per FileOut: dest = targets.expand; invariants.writable(dest, own); exists and not
    #   recorded → failed; mkdir parents (below HOME); atomic.write_bytes; record new ones.
    raise NotImplementedError


def icons(paths: Paths, folder: str) -> list[Path]:
    """aptus-icons-{dark,light}: index.theme inheriting Papirus-Dark/-Light and hicolor, and per
    size a places/ directory of `folder*.svg` symlinks to Papirus's `folder-<folder>*.svg`.
    Rebuilt only when the folder colour changed; Papirus is never modified."""
    # TODO(S2): per theme: build .<theme>.new: index.theme (Inherits Papirus-Dark|Light,hicolor;
    #   Directories for ICON_SIZES places); symlinks folder*.svg →
    #   papirus/<size>/places/folder-<folder>*.svg; rename over; skip when index.theme
    #   names the same folder.
    raise NotImplementedError


def bat(paths: Paths) -> bool:
    """`bat cache --build --source <bat_source> --target <cache_bat>` (BAT_CACHE_PATH in Hyprland)."""
    # TODO(S2): system.run bat cache --build --source bat_source --target cache_bat.
    raise NotImplementedError


def record(paths: Paths, created: Sequence[Path]) -> None:
    """Add paths to own.json (only those aptus created, never a file that existed before)."""
    # TODO(S2): own.json list, add new paths, atomic.write_json.
    raise NotImplementedError


def recorded(paths: Paths) -> list[Path]:
    # TODO(S2): own.json list as Paths ([] when missing).
    raise NotImplementedError


def apply(paths: Paths, target: Target, gen: Generation) -> None:
    """Write one Own target (files, then its builtin step)."""
    # TODO(S2): write_files; own == 'icons' → icons(resolved papirus); 'bat' → bat().
    raise NotImplementedError
