"""Kind `file` (02 §5.5): bytes + mode; write = temp + rename in the slot's own (resolved)
directory with the mode of `before`; restore = the bytes of slots/<id>.before, or unlink when the
artifact did not exist. A symlinked slot is written through to its target, never replaced."""
from __future__ import annotations

from pathlib import Path

from ...paths import Paths
from ..journal import SlotRecord
from ..slots import SlotSpec
from . import Snapshot


def write_path(path: Path) -> Path:
    """The file aptus writes for slot `path`: its resolved target when `path` is a symlink (the
    link stays), else `path` itself."""
    raise NotImplementedError


def read(paths: Paths, rec: SlotRecord) -> Snapshot:
    """{exists, sha256, mode ("0644"), size} and the bytes; {exists: false} for a missing file."""
    raise NotImplementedError


def digest(paths: Paths, rec: SlotRecord) -> dict:
    """{"sha256": hex | None} of rec.write_path (None: missing)."""
    raise NotImplementedError


def before_digest(before: dict) -> dict:
    raise NotImplementedError


def planned(spec: SlotSpec) -> dict:
    raise NotImplementedError


def write(paths: Paths, rec: SlotRecord, spec: SlotSpec) -> dict:
    """Atomic write of spec.content into rec.write_path with the mode of `before` (0644 for a file
    that did not exist); creates missing parent directories only below HOME."""
    raise NotImplementedError


def restore(paths: Paths, rec: SlotRecord, data: bytes | None) -> None:
    """Atomic write of `data` with the recorded mode, or unlink when `before.exists` is false."""
    raise NotImplementedError


def current(paths: Paths, rec: SlotRecord) -> bytes:
    raise NotImplementedError
