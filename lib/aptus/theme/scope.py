"""Scope targets (02 §3 Scope, 08 §6 step 2): files only Hyprland's process tree reads, through an
environment variable set in hyprland.lua (KITTY_CONFIG_DIRECTORY, YAZI_CONFIG_HOME,
STARSHIP_CONFIG). Each lives in ~/.local/state/aptus/scope/ and is swapped atomically:
`scope/<into>` is a symlink to `scope/.<into>.<generation>.<pid>`, a directory (mirror) or a file
(starship.toml); the other builds of `<into>` are removed after the swap. install.sh creates only
`scope/`. Everything runs under the theme lock."""
from __future__ import annotations

import os
import re
import shutil
import time
from collections.abc import Mapping, Sequence
from pathlib import Path

from .. import atomic
from ..lease import invariants
from ..paths import Paths
from . import render, targets
from .render import Generation
from .targets import FileOut, Target


def mirror(source: Path, build: Path, files: Sequence[tuple[FileOut, Path]]) -> None:
    """Fill the empty dir `build` with symlinks to every entry of `source`, except along each
    file's `at` (e.g. themes/noctalia.conf): its parent directories become real directories (again
    of links) and `at` itself is a copy of the rendered file. A `missing_only` file is used only
    when `source` has no `at`. `source` itself is only read."""
    overlay = {Path(f.at): rendered for f, rendered in files
               if not (f.missing_only and os.path.lexists(source / f.at))}
    _fill(source, build, overlay)


def _fill(src: Path, dst: Path, overlay: Mapping[Path, Path]) -> None:
    firsts = sorted({p.parts[0] for p in overlay})
    for name in sorted(os.listdir(src)) if src.is_dir() else []:
        if name not in firsts:
            os.symlink(src / name, dst / name)
    for first in firsts:
        leaf = [r for p, r in overlay.items() if p.parts == (first,)]
        if leaf:
            shutil.copyfile(leaf[0], dst / first)
            os.chmod(dst / first, 0o644)
            continue
        (dst / first).mkdir(mode=0o755)
        _fill(src / first, dst / first,
              {Path(*p.parts[1:]): r for p, r in overlay.items() if p.parts[0] == first})


def marked(source: Path, begin: str, end: str, block: str) -> str:
    """The text of `source` with everything between the `begin` and `end` marker lines replaced by
    `block` (markers kept); without markers, `block` is appended between new markers. A missing
    source gives just the marked block."""
    try:
        text = source.read_text(encoding="utf-8")
    except FileNotFoundError:
        text = ""
    lines = text.splitlines(keepends=True)
    body = block if block.endswith("\n") or not block else block + "\n"
    stripped = [ln.strip() for ln in lines]
    if begin in stripped and end in stripped[stripped.index(begin) + 1:]:
        b = stripped.index(begin)
        e = stripped.index(end, b + 1)
        return "".join(lines[:b + 1]) + body + "".join(lines[e:])
    sep = "" if not text or text.endswith("\n") else "\n"
    return text + sep + ("\n" if text else "") + begin + "\n" + body + end + "\n"


def _builds(paths: Paths, into: str) -> list[Path]:
    pattern = re.compile(rf"\.{re.escape(into)}\.\d+\.\d+")
    return [p for p in paths.scope.iterdir() if pattern.fullmatch(p.name)] \
        if paths.scope.is_dir() else []


def _remove(p: Path) -> None:
    if p.is_dir() and not p.is_symlink():
        shutil.rmtree(p)
    else:
        p.unlink(missing_ok=True)


def swap(paths: Paths, into: str, build: Path) -> None:
    """Point scope/<into> at `build` (a sibling dir or file) atomically and remove every other
    build of `into`. A real file or directory at scope/<into> (from an older install) is moved
    aside to scope/.<into>.old-<time> first."""
    entry = invariants.scope_entry(paths, into)
    invariants.writable(paths, build, kind="scope")
    if os.path.lexists(entry) and not entry.is_symlink():
        aside = entry.with_name(f".{into}.old-{time.time_ns()}")
        invariants.writable(paths, aside, kind="scope")
        os.rename(entry, aside)
    atomic.symlink(Path(build.name), entry)
    for old in _builds(paths, into):
        if old.name != build.name:
            invariants.writable(paths, old, kind="scope")
            _remove(old)


def apply(paths: Paths, target: Target, gen: Generation) -> None:
    """Rebuild one scope target from the generation (under the theme lock)."""
    sc = target.scope
    if sc is None:
        raise ValueError(f"{target.id} is not a scope target")
    with render.lock(paths):
        invariants.check_scope_name(sc.into)
        paths.scope.mkdir(parents=True, exist_ok=True, mode=0o755)
        build = invariants.scope_entry(paths, sc.into).with_name(
            f".{sc.into}.{gen.n}.{os.getpid()}")
        invariants.writable(paths, build, kind="scope")
        if os.path.lexists(build):
            _remove(build)
        try:
            if sc.mirror:
                build.mkdir(mode=0o755)
                mirror(targets.expand(paths, sc.mirror), build,
                       [(f, render.output(gen, f)) for f in target.files])
            else:
                block = render.output(gen, target.files[0]).read_text(encoding="utf-8")
                text = marked(targets.expand(paths, sc.source), sc.begin, sc.end, block)
                atomic.write_text(build, text, 0o644)
            swap(paths, sc.into, build)
        except BaseException:
            if os.path.lexists(build) and os.path.realpath(invariants.scope_entry(paths, sc.into)) \
                    != os.path.realpath(build):
                _remove(build)
            raise
