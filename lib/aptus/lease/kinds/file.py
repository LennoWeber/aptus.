"""Kind `file` (02 §5.5): bytes + mode; write = temp + rename in the slot's own (resolved)
directory with the mode of `before`; restore = the bytes of slots/<id>.before, or unlink when the
artifact did not exist. A symlinked slot is written through to its target, never replaced."""
from __future__ import annotations

import os
import stat
from pathlib import Path

from ... import atomic
from ...paths import Paths
from .. import invariants
from ..journal import SlotRecord
from ..slots import SlotSpec
from . import Snapshot, sha256


def write_path(path: Path) -> Path:
    """The file aptus writes for slot `path`: its realpath, so a symlinked slot (or a slot below a
    linked directory, stow-style) is written through and the link stays."""
    return Path(os.path.realpath(path))


def link_of(path: Path) -> str:
    """readlink(path), "" when path is not a symlink."""
    return os.readlink(path) if os.path.islink(path) else ""


def read(paths: Paths, rec: SlotRecord) -> Snapshot:
    """{exists, sha256, mode ("0644"), size, link} and the bytes; {exists: false, link} for a
    missing file. `link` is readlink(path), "" when path is not a symlink."""
    link = link_of(Path(rec.path))
    try:
        with open(rec.write_path, "rb") as f:
            data = f.read()
            mode = stat.S_IMODE(os.fstat(f.fileno()).st_mode)
    except FileNotFoundError:
        return Snapshot({"exists": False, "link": link})
    return Snapshot({"exists": True, "sha256": sha256(data), "mode": f"{mode:04o}",
                     "size": len(data), "link": link}, data)


def digest(paths: Paths, rec: SlotRecord) -> dict:
    """{"sha256": hex | None} of rec.write_path (None: missing)."""
    try:
        return {"sha256": sha256(Path(rec.write_path).read_bytes())}
    except FileNotFoundError:
        return {"sha256": None}


def before_digest(before: dict) -> dict:
    return {"sha256": before.get("sha256") if before.get("exists") else None}


def planned(spec: SlotSpec) -> dict:
    return {"sha256": sha256(spec.content or b"")}


def write(paths: Paths, rec: SlotRecord, spec: SlotSpec) -> dict:
    """Atomic write of spec.content into rec.write_path with the mode of `before` (0644 for a file
    that did not exist). Never creates a directory (take skips a slot whose directory is missing)
    and refuses a write_path outside HOME (invariants.writable)."""
    target = Path(rec.write_path)
    invariants.writable(paths, target, kind="lease", no_link=True)
    if not target.parent.is_dir():
        raise FileNotFoundError(f"{target.parent} does not exist (aptus never creates it)")
    mode = int(rec.before["mode"], 8) if rec.before.get("exists") else 0o644
    atomic.write_bytes(target, spec.content or b"", mode)
    return digest(paths, rec)


def restore(paths: Paths, rec: SlotRecord, data: bytes | None) -> None:
    """Atomic write of `data` with the recorded mode, or unlink when `before.exists` is false."""
    target = Path(rec.write_path)
    invariants.writable(paths, target, kind="lease", no_link=True)
    if not rec.before.get("exists"):
        target.unlink(missing_ok=True)
        return
    if data is None:
        raise FileNotFoundError(f"no copy of {rec.id}'s before in slots/")
    atomic.write_bytes(target, data, int(rec.before["mode"], 8))


def current(paths: Paths, rec: SlotRecord) -> bytes:
    try:
        return Path(rec.write_path).read_bytes()
    except FileNotFoundError:
        return b""
