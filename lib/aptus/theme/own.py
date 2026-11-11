"""Own targets (02 §3 Own, 08 §8): files only aptus reads, or that are inert outside Hyprland.
own.json records every file and directory aptus created (before creating it), so uninstall
removes only those."""
from __future__ import annotations

import json
import os
import shutil
from collections.abc import Sequence
from pathlib import Path

from .. import atomic
from ..lease import invariants, system
from ..paths import Paths
from . import render, targets
from .render import Generation
from .targets import Target

ICON_SIZES = ("16x16", "22x22", "24x24", "32x32", "48x48", "64x64")
ICON_THEMES = ("aptus-icons-dark", "aptus-icons-light")
FOLDER_KEY = "X-Aptus-Folder"
BAT_TIMEOUT = 60.0


class OwnError(RuntimeError):
    """An Own file could not be written (it exists and is not aptus's, or a tool failed)."""


def _aptus_dir(paths: Paths, dest: Path) -> bool:
    """A dest inside aptus's state or cache dir is aptus's by definition (generated.lua)."""
    return any(_inside(dest, root) for root in (paths.state, paths.cache))


def _inside(path: Path, root: Path) -> bool:
    p, r = os.path.normpath(path), os.path.normpath(root)
    return p == r or p.startswith(r + os.sep)


def _holds(dest: Path, data: bytes) -> bool:
    """dest is a regular file (not a symlink) with exactly these bytes."""
    try:
        return not dest.is_symlink() and dest.is_file() and dest.read_bytes() == data
    except OSError:
        return False


def write_files(paths: Paths, target: Target, gen: Generation) -> list[Path]:
    """Copy the target's rendered files to their `dest` (atomic); returns the destinations
    written (a dest that holds the rendered bytes already is left alone). A dest outside aptus's
    own dirs that exists but is not in own.json (a qt6ct.conf of Lenno's) is never overwritten:
    OwnError "exists and is not aptus's" (the other files are written)."""
    mine = set(recorded(paths))
    written, refused = [], []
    for f in target.files:
        dest = targets.expand(paths, f.dest)
        invariants.writable(paths, dest, kind="own")
        if os.path.lexists(dest) and dest not in mine and not _aptus_dir(paths, dest):
            refused.append(str(dest))
            continue
        data = render.output(gen, f).read_bytes()
        if _holds(dest, data):
            continue
        if not os.path.lexists(dest):
            record(paths, [dest])
        dest.parent.mkdir(parents=True, exist_ok=True)
        atomic.write_bytes(dest, data, 0o644)
        written.append(dest)
    if refused:
        raise OwnError(f"{', '.join(refused)} exists and is not aptus's")
    return written


def _index(theme: str, mode: str, folder: str) -> str:
    dirs = [f"{size}/places" for size in ICON_SIZES]
    out = ["[Icon Theme]", f"Name={theme}",
           "Comment=Papirus with the aptus accent's folder colour (written by aptus-theme)",
           f"Inherits=Papirus-{mode.capitalize()},hicolor", f"{FOLDER_KEY}={folder}",
           f"Directories={','.join(dirs)}", ""]
    for size in ICON_SIZES:
        out += [f"[{size}/places]", "Context=Places", f"Size={size.split('x')[0]}", "Type=Fixed", ""]
    return "\n".join(out)


def _current_folder(theme_dir: Path) -> str:
    try:
        for line in (theme_dir / "index.theme").read_text(encoding="utf-8").splitlines():
            if line.startswith(FOLDER_KEY + "="):
                return line.split("=", 1)[1]
    except OSError:
        pass
    return ""


def _build_icons(paths: Paths, build: Path, theme: str, mode: str, folder: str) -> None:
    build.mkdir(mode=0o755)
    (build / "index.theme").write_text(_index(theme, mode, folder), encoding="utf-8")
    prefix = f"folder-{folder}"
    for size in ICON_SIZES:
        src = paths.papirus / size / "places"
        dst = build / size / "places"
        dst.mkdir(parents=True)
        for icon in sorted(src.glob(f"{prefix}*.svg")) if src.is_dir() else []:
            rest = icon.name[len(prefix):]
            if rest == ".svg" or rest.startswith("-"):
                os.symlink(icon, dst / ("folder" + rest))


def icons(paths: Paths, folder: str) -> list[Path]:
    """aptus-icons-{dark,light}: index.theme inheriting Papirus-Dark/-Light and hicolor, and per
    size a places/ directory of `folder*.svg` symlinks to Papirus's `folder-<folder>*.svg`.
    Rebuilt only when the folder colour changed (built aside, then renamed over); Papirus is
    never modified. Returns the theme directories rebuilt."""
    if not paths.papirus.is_dir():
        raise OwnError(f"{paths.papirus} is missing")
    rebuilt = []
    for theme in ICON_THEMES:
        mode = theme.rsplit("-", 1)[1]
        theme_dir = paths.icons / theme
        invariants.writable(paths, theme_dir, kind="own")
        if _current_folder(theme_dir) == folder:
            continue
        record(paths, [theme_dir])
        build, old = theme_dir.with_name(f"{theme}.new"), theme_dir.with_name(f"{theme}.old")
        for p in (build, old):
            invariants.writable(paths, p, kind="own")
        paths.icons.mkdir(parents=True, exist_ok=True)
        shutil.rmtree(build, ignore_errors=True)
        shutil.rmtree(old, ignore_errors=True)
        _build_icons(paths, build, theme, mode, folder)
        if theme_dir.exists():
            os.rename(theme_dir, old)
        os.rename(build, theme_dir)
        shutil.rmtree(old, ignore_errors=True)
        atomic.fsync_dir(paths.icons)
        rebuilt.append(theme_dir)
    return rebuilt


def bat_stale(paths: Paths) -> bool:
    """The bat cache needs a build: its themes.bin is missing or older than a file of the source
    (make's rule: an unchanged theme is not rebuilt, a build that failed is tried again)."""
    try:
        built = (paths.cache_bat / "themes.bin").stat().st_mtime_ns
    except OSError:
        return True
    return any(f.stat().st_mtime_ns > built for f in paths.bat_source.rglob("*") if f.is_file())


def in_place(paths: Paths, target: Target) -> bool:
    """The Own target's output exists: every `dest`, and for `own = "icons"` both aptus-icons
    themes with their index.theme (what a leased key that `requires` it may select)."""
    if not all(os.path.lexists(targets.expand(paths, f.dest)) for f in target.files if f.dest):
        return False
    if target.own == "icons":
        return all((paths.icons / theme / "index.theme").is_file() for theme in ICON_THEMES)
    return True


def bat(paths: Paths) -> None:
    """`bat cache --build --source <bat_source> --target <cache_bat>` (BAT_CACHE_PATH in
    Hyprland), never into bat's shared default cache. OwnError when bat failed."""
    invariants.writable(paths, paths.cache_bat, kind="own")
    if not os.path.lexists(paths.cache_bat):
        record(paths, [paths.cache_bat])
    paths.cache_bat.mkdir(parents=True, exist_ok=True)
    r = system.run(paths, ["bat", "cache", "--build", "--source", str(paths.bat_source),
                           "--target", str(paths.cache_bat)], timeout=BAT_TIMEOUT)
    if r.skipped:
        raise OwnError("bat is not installed")
    if r.code != 0:
        raise OwnError(f"bat cache --build exited {r.code}: {r.stderr.strip()[:200]}")


def record(paths: Paths, created: Sequence[Path]) -> None:
    """Add paths to own.json (only those aptus creates, never a file that existed before; called
    before creating them, so a crash in between still leaves them recorded)."""
    have = [str(p) for p in recorded(paths)]
    new = [str(p) for p in created if str(p) not in have]
    if not new:
        return
    invariants.writable(paths, paths.theme_own, kind="state")
    paths.theme.mkdir(parents=True, exist_ok=True, mode=0o700)
    atomic.write_json(paths.theme_own, {"v": 1, "created": sorted(have + new)}, 0o600)


def recorded(paths: Paths) -> list[Path]:
    """own.json's paths ([] when missing or unreadable)."""
    try:
        raw = json.loads(paths.theme_own.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return []
    items = raw.get("created", []) if isinstance(raw, dict) else []
    return [Path(p) for p in items if isinstance(p, str) and os.path.isabs(p)]


def apply(paths: Paths, target: Target, gen: Generation) -> None:
    """Write one Own target (files, then its builtin step) under the theme lock. The builtin
    steps run only when needed: the icon themes when the folder colour changed, `bat cache
    --build` when its source changed (bat_stale)."""
    with render.lock(paths):
        write_files(paths, target, gen)
        if target.own == "icons":
            icons(paths, gen.resolved["papirus"])
        elif target.own == "bat" and bat_stale(paths):
            bat(paths)
