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
from pathlib import Path

from .. import invariants
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
    # TODO(S2): line-wise (keepends); a line '[name]' (stripped) starts a block; text before the
    #   first header is the preamble block (name None).
    raise NotImplementedError


def matches(name: str | None, globs: Sequence[str]) -> bool:
    """Whether a block's header name matches one of the globs (fnmatch, case-sensitive)."""
    # TODO(S2): name is not None and fnmatch.fnmatchcase against any glob.
    raise NotImplementedError


def extract(text: str, globs: Sequence[str]) -> list[Section]:
    """The matching sections of `text`, in order, each with its anchor."""
    # TODO(S2): walk the blocks; anchor = the last non-matching block's name ('' for the preamble,
    #   None at the start).
    raise NotImplementedError


def splice(text: str, globs: Sequence[str], sections: Sequence[Section]) -> str:
    """`text` without its matching sections, with `sections` put after their anchors (in order;
    an anchor that no longer exists: at the end). A newline is added only where an anchor block
    lacks one, so a restore of an untouched file gives the original bytes."""
    # TODO(S2): keep the non-matching blocks in order; insert the sections after the first block
    #   named by their anchor (None: at the start; unknown: at the end); add a newline only
    #   where the previous block lacks one.
    raise NotImplementedError


def sections_sha256(sections: Sequence[Section]) -> str:
    """SHA-256 of the sections' verbatim text joined in order (names and anchors excluded)."""
    # TODO(S2): sha256 of ''.join(section texts) as UTF-8.
    raise NotImplementedError


def read(paths: Paths, rec: SlotRecord) -> Snapshot:
    """{exists, mode, link, sections_sha256, sections: [{name, anchor, text}]}."""
    # TODO(S2): text of write_path (missing → exists false, sections []); extract; mode, link as in
    #   file.
    raise NotImplementedError


def digest(paths: Paths, rec: SlotRecord) -> dict:
    """{"sections_sha256": hex | None} (None: the file is missing)."""
    # TODO(S2): None when missing, else sections_sha256(extract(current text)).
    raise NotImplementedError


def before_digest(before: dict) -> dict:
    # TODO(S2): {'sections_sha256': before['sections_sha256'] if exists else None}.
    raise NotImplementedError


def planned(spec: SlotSpec) -> dict:
    """The digest of the rendered sections (spec.content is an INI text of only those); equal to
    `digest` right after `write`, since the sections are inserted verbatim."""
    # TODO(S2): sections_sha256(extract(spec.content, spec.sections)).
    raise NotImplementedError


def write(paths: Paths, rec: SlotRecord, spec: SlotSpec) -> dict:
    """Splice the rendered sections into the current file (anchors from `before`), atomically."""
    # TODO(S2): new sections = extract(spec.content) with anchors from before's sections of the
    #   same name (else the previous new section's, else the end); splice into the current
    #   text; atomic write with the file's mode; invariants.writable.
    invariants.writable(paths, Path(rec.write_path), kind="lease")
    raise NotImplementedError


def restore(paths: Paths, rec: SlotRecord, data: bytes | None) -> None:
    """Splice the `before` sections back into the current file; other sections stay as they are
    now (KDE apps may have written them). A file that did not exist before is removed again when
    nothing but the leased sections is left in it."""
    # TODO(S2): splice before's sections into the current text; before.exists false and nothing but
    #   whitespace left → unlink.
    raise NotImplementedError


def current(paths: Paths, rec: SlotRecord) -> bytes:
    """The matching sections as they are now (for conflicts/)."""
    # TODO(S2): the matching sections' text now, UTF-8.
    raise NotImplementedError
