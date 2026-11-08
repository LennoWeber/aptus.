"""Atomic writes (07-architecture §9): temp file in the same directory, fsync, rename, fsync dir."""
from __future__ import annotations

import contextlib
import json
import os
import secrets
import stat
import tempfile
from pathlib import Path
from typing import Any


def write_bytes(path: Path, data: bytes, mode: int | None = None) -> None:
    """Write `data` atomically. `mode` defaults to the existing file's mode, else 0o644."""
    path = Path(path)
    if mode is None:
        try:
            mode = stat.S_IMODE(os.stat(path).st_mode)
        except FileNotFoundError:
            mode = 0o644
    fd, tmp = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
            f.flush()
            os.fchmod(f.fileno(), mode)
            os.fsync(f.fileno())
        os.replace(tmp, path)
    except BaseException:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(tmp)
        raise
    fsync_dir(path.parent)


def write_text(path: Path, text: str, mode: int | None = None) -> None:
    write_bytes(path, text.encode("utf-8"), mode)


def write_json(path: Path, obj: Any, mode: int | None = None) -> None:
    """JSON with 2-space indent, sorted keys, trailing newline."""
    write_text(path, json.dumps(obj, indent=2, sort_keys=True, ensure_ascii=False) + "\n", mode)


def fsync_dir(path: Path) -> None:
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def symlink(target: Path, link: Path) -> None:
    """Point `link` at `target` atomically (temp link + rename)."""
    link = Path(link)
    tmp = link.with_name(f".{link.name}.{os.getpid()}.{secrets.token_hex(4)}.tmp")
    os.symlink(target, tmp)
    try:
        os.replace(tmp, link)
    except BaseException:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(tmp)
        raise
    fsync_dir(link.parent)
