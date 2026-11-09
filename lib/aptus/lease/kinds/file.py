"""Kind `file` (02 §5.5): bytes + mode; write = temp + rename in the slot's own (resolved)
directory with the mode of `before`; restore = the bytes of slots/<id>.before, or unlink when the
artifact did not exist. A symlinked slot is written through to its target, never replaced."""
from __future__ import annotations

from pathlib import Path

from .. import invariants
from ...paths import Paths
from ..journal import SlotRecord
from ..slots import SlotSpec
from . import Snapshot


def write_path(path: Path) -> Path:
    """The file aptus writes for slot `path`: its resolved target when `path` is a symlink (the
    link stays), else `path` itself."""
    # TODO(S2): path itself unless it is a symlink: then os.path.realpath (the link stays).
    raise NotImplementedError


def read(paths: Paths, rec: SlotRecord) -> Snapshot:
    """{exists, sha256, mode ("0644"), size, link} and the bytes; {exists: false, link} for a
    missing file. `link` is readlink(path), "" when path is not a symlink."""
    # TODO(S2): lstat for link; open rb; mode via stat; size; sha256.
    raise NotImplementedError


def digest(paths: Paths, rec: SlotRecord) -> dict:
    """{"sha256": hex | None} of rec.write_path (None: missing)."""
    # TODO(S2): sha256 of write_path bytes, None when missing.
    raise NotImplementedError


def before_digest(before: dict) -> dict:
    # TODO(S2): {'sha256': before['sha256'] if exists else None}.
    raise NotImplementedError


def planned(spec: SlotSpec) -> dict:
    # TODO(S2): {'sha256': sha256(spec.content)}.
    raise NotImplementedError


def write(paths: Paths, rec: SlotRecord, spec: SlotSpec) -> dict:
    """Atomic write of spec.content into rec.write_path with the mode of `before` (0644 for a file
    that did not exist). Never creates a directory (take skips a slot whose directory is missing)
    and refuses a write_path outside HOME (invariants.writable)."""
    # TODO(S2): invariants.writable(write_path); parent must exist (OSError otherwise);
    #   atomic.write_bytes(write_path, content, mode of before or 0o644); return digest.
    invariants.writable(paths, Path(rec.write_path), kind="lease")
    raise NotImplementedError


def restore(paths: Paths, rec: SlotRecord, data: bytes | None) -> None:
    """Atomic write of `data` with the recorded mode, or unlink when `before.exists` is false."""
    # TODO(S2): before.exists false → unlink (missing ok); else atomic.write_bytes(write_path,
    #   data, int(before.mode, 8)); invariants.writable first.
    raise NotImplementedError


def current(paths: Paths, rec: SlotRecord) -> bytes:
    # TODO(S2): bytes of write_path, b'' when missing.
    raise NotImplementedError
