"""Atomic writes (07-architecture §9): temp file in the same directory, fsync, rename, fsync dir."""
from __future__ import annotations

import os
from pathlib import Path
from typing import Any


def write_bytes(path: Path, data: bytes, mode: int | None = None) -> None:
    """Write `data` atomically. `mode` defaults to the existing file's mode, else 0o644."""
    raise NotImplementedError


def write_text(path: Path, text: str, mode: int | None = None) -> None:
    raise NotImplementedError


def write_json(path: Path, obj: Any, mode: int | None = None) -> None:
    """JSON with 2-space indent, sorted keys, trailing newline."""
    raise NotImplementedError


def fsync_dir(path: Path) -> None:
    raise NotImplementedError


def symlink(target: Path, link: Path) -> None:
    """Point `link` at `target` atomically (temp link + rename)."""
    raise NotImplementedError
