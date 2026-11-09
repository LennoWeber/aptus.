"""Kind `dconf` (02 §5.5): `dconf read KEY` (empty = not set), `dconf write KEY VALUE`, restore with
`dconf write KEY BEFORE` or `dconf reset KEY`. Only the fixed key set of 02 §5.5 is ever touched;
`gtk-theme` is recorded and never written. dconf runs through lease.system (a fake under test)."""
from __future__ import annotations

from ...paths import Paths
from ..journal import SlotRecord
from ..slots import SlotSpec
from . import Snapshot

KEY_DIR = "/org/gnome/desktop/interface/"
# The fixed key set of 02 §5.5; nothing else is ever read or written.
KEYS = ("color-scheme", "gtk-theme", "icon-theme", "cursor-theme", "cursor-size", "font-name",
        "document-font-name", "monospace-font-name", "accent-color")
RECORD_ONLY = ("gtk-theme",)


class DconfError(RuntimeError):
    """dconf failed, is missing (a skipped call under test), or a key outside KEYS was asked for."""


def check_key(key: str, *, writing: bool) -> None:
    """DconfError unless `key` is KEY_DIR + one of KEYS (and, when writing, not RECORD_ONLY)."""
    raise NotImplementedError


def read_key(paths: Paths, key: str) -> str | None:
    """`dconf read KEY`: the GVariant text, None when the key is not set."""
    raise NotImplementedError


def write_key(paths: Paths, key: str, value: str) -> None:
    raise NotImplementedError


def reset_key(paths: Paths, key: str) -> None:
    raise NotImplementedError


def read(paths: Paths, rec: SlotRecord) -> Snapshot:
    """{set, value}."""
    raise NotImplementedError


def digest(paths: Paths, rec: SlotRecord) -> dict:
    """{"value": text | None}."""
    raise NotImplementedError


def before_digest(before: dict) -> dict:
    raise NotImplementedError


def planned(spec: SlotSpec) -> dict:
    raise NotImplementedError


def write(paths: Paths, rec: SlotRecord, spec: SlotSpec) -> dict:
    """`dconf write`; a record-only slot is left alone and keeps its digest."""
    raise NotImplementedError


def restore(paths: Paths, rec: SlotRecord, data: bytes | None) -> None:
    """`dconf write KEY BEFORE`, or `dconf reset KEY` when it was not set."""
    raise NotImplementedError


def current(paths: Paths, rec: SlotRecord) -> bytes:
    raise NotImplementedError
