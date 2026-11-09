"""Kind `dconf` (02 §5.5): `dconf read KEY` (empty = not set), `dconf write KEY VALUE`, restore with
`dconf write KEY BEFORE` or `dconf reset KEY`. Only the fixed key set of 02 §5.5 is ever touched;
`gtk-theme` is recorded and never written. dconf runs through lease.system (a fake under test)."""
from __future__ import annotations

from ...paths import Paths
from .. import system
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
    name = key[len(KEY_DIR):] if key.startswith(KEY_DIR) else None
    if name not in KEYS:
        raise DconfError(f"dconf key {key!r} is outside the fixed key set")
    if writing and name in RECORD_ONLY:
        raise DconfError(f"dconf key {key!r} is recorded only, never written")


def read_key(paths: Paths, key: str) -> str | None:
    """`dconf read KEY`: the GVariant text, None when the key is not set."""
    check_key(key, writing=False)
    r = system.run(paths, ["dconf", "read", key])
    if r.skipped or r.code != 0:
        raise DconfError(f"dconf read {key}: {'not available' if r.skipped else r.stderr.strip()}")
    return r.stdout.strip() or None


def _change(paths: Paths, argv: list[str]) -> None:
    r = system.run(paths, argv)
    if r.skipped or r.code != 0:
        raise DconfError(f"{' '.join(argv[:3])}: {'not available' if r.skipped else r.stderr.strip()}")


def write_key(paths: Paths, key: str, value: str) -> None:
    check_key(key, writing=True)
    _change(paths, ["dconf", "write", key, value])


def reset_key(paths: Paths, key: str) -> None:
    check_key(key, writing=True)
    _change(paths, ["dconf", "reset", key])


def read(paths: Paths, rec: SlotRecord) -> Snapshot:
    """{set, value}."""
    value = read_key(paths, rec.key)
    return Snapshot({"set": value is not None, "value": value})


def digest(paths: Paths, rec: SlotRecord) -> dict:
    """{"value": text | None}."""
    return {"value": read_key(paths, rec.key)}


def before_digest(before: dict) -> dict:
    return {"value": before.get("value") if before.get("set") else None}


def planned(spec: SlotSpec) -> dict:
    """{"value": spec.value}; a record-only spec (value None) plans no change: take records the
    `before` digest as its `after`."""
    return {"value": spec.value}


def write(paths: Paths, rec: SlotRecord, spec: SlotSpec) -> dict:
    """`dconf write`; a record-only slot is left alone and keeps its digest. Returns the value
    read back (dconf may normalise the GVariant text)."""
    if not rec.write or spec.value is None:
        return digest(paths, rec)
    write_key(paths, rec.key, spec.value)
    return digest(paths, rec)


def restore(paths: Paths, rec: SlotRecord, data: bytes | None) -> None:
    """`dconf write KEY BEFORE`, or `dconf reset KEY` when it was not set."""
    if not rec.write:
        return
    if rec.before.get("set"):
        write_key(paths, rec.key, rec.before["value"])
    else:
        reset_key(paths, rec.key)


def current(paths: Paths, rec: SlotRecord) -> bytes:
    return (read_key(paths, rec.key) or "").encode("utf-8")
