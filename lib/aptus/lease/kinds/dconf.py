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
    # TODO(S2): key.startswith(KEY_DIR) and the rest in KEYS; writing and in RECORD_ONLY → error.
    raise NotImplementedError


def read_key(paths: Paths, key: str) -> str | None:
    """`dconf read KEY`: the GVariant text, None when the key is not set."""
    # TODO(S2): check_key; system.run ['dconf', 'read', key]; skipped or code != 0 → DconfError;
    #   empty stdout → None.
    raise NotImplementedError


def write_key(paths: Paths, key: str, value: str) -> None:
    # TODO(S2): check_key(writing=True); ['dconf', 'write', key, value]; failure → DconfError.
    raise NotImplementedError


def reset_key(paths: Paths, key: str) -> None:
    # TODO(S2): check_key(writing=True); ['dconf', 'reset', key].
    raise NotImplementedError


def read(paths: Paths, rec: SlotRecord) -> Snapshot:
    """{set, value}."""
    # TODO(S2): {'set': value is not None, 'value': value}.
    raise NotImplementedError


def digest(paths: Paths, rec: SlotRecord) -> dict:
    """{"value": text | None}."""
    # TODO(S2): {'value': read_key}.
    raise NotImplementedError


def before_digest(before: dict) -> dict:
    # TODO(S2): {'value': before['value'] if before['set'] else None}.
    raise NotImplementedError


def planned(spec: SlotSpec) -> dict:
    # TODO(S2): {'value': spec.value}; record-only: the before value (filled by take).
    raise NotImplementedError


def write(paths: Paths, rec: SlotRecord, spec: SlotSpec) -> dict:
    """`dconf write`; a record-only slot is left alone and keeps its digest."""
    # TODO(S2): rec.write false → return digest unchanged; else write_key and return {'value':
    #   value}.
    raise NotImplementedError


def restore(paths: Paths, rec: SlotRecord, data: bytes | None) -> None:
    """`dconf write KEY BEFORE`, or `dconf reset KEY` when it was not set."""
    # TODO(S2): record-only → nothing; set → write_key(before value); else reset_key.
    raise NotImplementedError


def current(paths: Paths, rec: SlotRecord) -> bytes:
    # TODO(S2): (read_key or '').encode().
    raise NotImplementedError
