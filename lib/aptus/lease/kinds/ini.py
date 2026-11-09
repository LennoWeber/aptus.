"""Kind `ini-sections` (02 §5.5): kdeglobals' [Colors:*], [ColorEffects:*] and [WM] sections.

The file is split into blocks: the preamble (before the first header) and one block per `[header]`
line with every line up to the next header, all verbatim. A section matches when its header name
matches a glob (`Colors:Header][Inactive` matches `Colors:*`). `before` keeps each matching section
with its anchor, the name of the non-matching block right before it. Writing and restoring remove
the matching sections and put the new ones after their anchors (unknown anchor: the end), so every
other byte stays as it is, including a missing final newline.
"""
from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass

from ...paths import Paths
from ..journal import SlotRecord
from ..slots import SlotSpec
from . import Snapshot


@dataclass
class Block:
    name: str | None           # the header name without brackets; None for the preamble
    text: str                  # verbatim, including the header line and the final newline (if any)


@dataclass
class Section:
    name: str                  # header name
    anchor: str | None         # name of the non-matching block before it (None: the preamble/start)
    text: str                  # verbatim block text


def split(text: str) -> list[Block]:
    """The blocks of an INI text in order; "".join(b.text for b in split(t)) == t."""
    raise NotImplementedError


def matches(name: str | None, globs: Sequence[str]) -> bool:
    """Whether a block's header name matches one of the globs (fnmatch, case-sensitive)."""
    raise NotImplementedError


def extract(text: str, globs: Sequence[str]) -> list[Section]:
    """The matching sections of `text`, in order, each with its anchor."""
    raise NotImplementedError


def splice(text: str, globs: Sequence[str], sections: Sequence[Section]) -> str:
    """`text` without its matching sections, with `sections` put after their anchors (in order;
    an anchor that no longer exists: at the end). A newline is added only where an anchor block
    lacks one, so a restore of an untouched file gives the original bytes."""
    raise NotImplementedError


def sections_sha256(sections: Sequence[Section]) -> str:
    """SHA-256 of the sections' verbatim text joined in order (names and anchors excluded)."""
    raise NotImplementedError


def read(paths: Paths, rec: SlotRecord) -> Snapshot:
    """{exists, sections_sha256, sections: [{name, anchor, text}]}."""
    raise NotImplementedError


def digest(paths: Paths, rec: SlotRecord) -> dict:
    """{"sections_sha256": hex | None} (None: the file is missing)."""
    raise NotImplementedError


def before_digest(before: dict) -> dict:
    raise NotImplementedError


def planned(spec: SlotSpec) -> dict:
    """The digest of the rendered sections (spec.content is an INI text of only those)."""
    raise NotImplementedError


def write(paths: Paths, rec: SlotRecord, spec: SlotSpec) -> dict:
    """Splice the rendered sections into the current file (anchors from `before`), atomically."""
    raise NotImplementedError


def restore(paths: Paths, rec: SlotRecord, data: bytes | None) -> None:
    """Splice the `before` sections back into the current file; other sections stay as they are
    now (KDE apps may have written them). A file that did not exist before is removed again when
    nothing but the leased sections is left in it."""
    raise NotImplementedError


def current(paths: Paths, rec: SlotRecord) -> bytes:
    """The matching sections as they are now (for conflicts/)."""
    raise NotImplementedError
