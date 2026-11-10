"""Kind `ini-sections` (02 §5.5): kdeglobals' [Colors:*], [ColorEffects:*] and [WM] sections.

The file is split into blocks: the preamble (before the first header) and one block per `[header]`
line with every line up to the next header, all verbatim. A section matches when its header name
matches a glob (`Colors:Header][Inactive` matches `Colors:*`). `before` keeps each matching section
with its anchor, the name of the non-matching block right before it. Writing and restoring remove
the matching sections and put the new ones after their anchors (unknown anchor: the end), so every
other byte stays as it is, including a missing final newline (`before.eof_newline`).

Digests hash the sections sorted by name, each ending in one newline: splice may place them in
another order than the rendered file and must end a section that lacked a newline (phase-5 probe).
"""
from __future__ import annotations

import fnmatch
import os
import stat
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path

from ... import atomic
from ...paths import Paths
from .. import invariants
from ..journal import SlotRecord
from ..slots import SlotSpec
from . import Snapshot, sha256
from .file import link_of

END = "\0end"                  # an anchor no block has: the section goes to the end


@dataclass
class Block:
    name: str | None           # the header name without brackets; None for the preamble
    text: str                  # verbatim, including the header line and the final newline (if any)


@dataclass
class Section:
    name: str                  # header name
    anchor: str | None         # name of the non-matching block before it ("" the preamble, None: the start)
    text: str                  # verbatim block text


def _header(line: str) -> str | None:
    s = line.strip()
    return s[1:-1] if len(s) >= 2 and s.startswith("[") and s.endswith("]") else None


def split(text: str) -> list[Block]:
    """The blocks of an INI text in order; "".join(b.text for b in split(t)) == t."""
    blocks: list[Block] = []
    name: str | None = None
    buf: list[str] = []
    started = False
    for line in text.splitlines(keepends=True):
        header = _header(line)
        if header is not None:
            if buf or started:
                blocks.append(Block(name, "".join(buf)))
            name, buf, started = header, [line], True
        else:
            buf.append(line)
    if buf or started:
        blocks.append(Block(name, "".join(buf)))
    return blocks


def matches(name: str | None, globs: Sequence[str]) -> bool:
    """Whether a block's header name matches one of the globs (fnmatch, case-sensitive)."""
    return name is not None and any(fnmatch.fnmatchcase(name, g) for g in globs)


def _anchor(name: str | None, seen: dict[str, int]) -> str:
    """The anchor of a block that is not leased: its header name ("" for the preamble), and for a
    name seen before also "\n<k>" (k-th repeat; a header name never holds a newline), so a file
    with a repeated header gets its sections back in the same place."""
    key = "" if name is None else name
    k = seen.get(key, 0)
    seen[key] = k + 1
    return key if k == 0 else f"{key}\n{k}"


def extract(text: str, globs: Sequence[str]) -> list[Section]:
    """The matching sections of `text`, in order, each with its anchor."""
    out: list[Section] = []
    anchor: str | None = None
    seen: dict[str, int] = {}
    for b in split(text):
        if matches(b.name, globs):
            out.append(Section(b.name or "", anchor, b.text))
        else:
            anchor = _anchor(b.name, seen)
    return out


def splice(text: str, globs: Sequence[str], sections: Sequence[Section]) -> str:
    """`text` without its matching sections, with `sections` put after their anchors (in order;
    an anchor that no longer exists: at the end). A newline is added only where an anchor block
    lacks one, so a restore of an untouched file gives the original bytes."""
    groups: dict[str | None, list[Section]] = {}
    for sec in sections:
        groups.setdefault(sec.anchor, []).append(sec)
    out: list[str] = []

    def emit(piece: str) -> None:
        if out and not out[-1].endswith("\n"):
            out[-1] += "\n"
        out.append(piece)

    for sec in groups.pop(None, []):
        emit(sec.text)
    seen: dict[str, int] = {}
    for b in split(text):
        if matches(b.name, globs):
            continue
        emit(b.text)
        for sec in groups.pop(_anchor(b.name, seen), []):
            emit(sec.text)
    for rest in groups.values():
        for sec in rest:
            emit(sec.text)
    return "".join(out)


def sections_sha256(sections: Sequence[Section]) -> str:
    """SHA-256 of the sections sorted by name, each ending in one newline (names and anchors
    excluded)."""
    norm = (s.text if s.text.endswith("\n") else s.text + "\n"
            for s in sorted(sections, key=lambda s: s.name))
    return sha256("".join(norm).encode("utf-8"))


def _text(path: str) -> str | None:
    try:
        with open(path, encoding="utf-8", newline="") as f:
            return f.read()
    except FileNotFoundError:
        return None


def read(paths: Paths, rec: SlotRecord) -> Snapshot:
    """{exists, mode, link, eof_newline, sections_sha256, sections: [{name, anchor, text}]}."""
    link = link_of(Path(rec.path))
    text = _text(rec.write_path)
    if text is None:
        return Snapshot({"exists": False, "link": link, "sections": []})
    secs = extract(text, rec.sections)
    mode = stat.S_IMODE(os.stat(rec.write_path).st_mode)
    return Snapshot({"exists": True, "mode": f"{mode:04o}", "link": link,
                     "eof_newline": text == "" or text.endswith("\n"),
                     "sections_sha256": sections_sha256(secs),
                     "sections": [{"name": x.name, "anchor": x.anchor, "text": x.text} for x in secs]})


def digest(paths: Paths, rec: SlotRecord) -> dict:
    """{"sections_sha256": hex}; a missing file counts as one without leased sections, so a file
    aptus created and KDE has written to since still verifies after the restore."""
    return {"sections_sha256": sections_sha256(extract(_text(rec.write_path) or "", rec.sections))}


def before_digest(before: dict) -> dict:
    return {"sections_sha256": before["sections_sha256"] if before.get("exists")
            else sections_sha256([])}


def planned(spec: SlotSpec) -> dict:
    """The digest of the rendered sections (spec.content is an INI text of only those); equal to
    `digest` right after `write` (sorted and newline-normalised, so order and a final newline do
    not count)."""
    text = (spec.content or b"").decode("utf-8")
    return {"sections_sha256": sections_sha256(extract(text, spec.sections))}


def _before_sections(before: dict) -> list[Section]:
    return [Section(x["name"], x["anchor"], x["text"]) for x in before.get("sections", [])]


def write(paths: Paths, rec: SlotRecord, spec: SlotSpec) -> dict:
    """Splice the rendered sections into the current file (anchors from `before`; a new section
    follows the previous new one, the first at the end), atomically, keeping the file's mode."""
    target = Path(rec.write_path)
    invariants.writable(paths, target, kind="lease", no_link=True)
    now = _text(rec.write_path)
    if now is None and not target.parent.is_dir():
        raise FileNotFoundError(f"{target.parent} does not exist (aptus never creates it)")
    anchors = {x.name: x.anchor for x in _before_sections(rec.before)}
    new: list[Section] = []
    for sec in extract((spec.content or b"").decode("utf-8"), spec.sections):
        anchor = anchors.get(sec.name, new[-1].anchor if new else END)
        text = sec.text if sec.text.endswith("\n") else sec.text + "\n"
        new.append(Section(sec.name, anchor, text))
    out = splice(now or "", rec.sections, new)
    atomic.write_bytes(target, out.encode("utf-8"), None if now is not None else 0o644)
    return digest(paths, rec)


def restore(paths: Paths, rec: SlotRecord, data: bytes | None) -> None:
    """Splice the `before` sections back into the current file; other sections stay as they are
    now (KDE apps may have written them). A file that did not exist before is removed again when
    nothing but the leased sections is left in it. A final newline that write had to add is
    taken off again when the file again ends in a non-leased block."""
    target = Path(rec.write_path)
    invariants.writable(paths, target, kind="lease", no_link=True)
    out = splice(_text(rec.write_path) or "", rec.sections, _before_sections(rec.before))
    if not rec.before.get("exists"):
        if not out.strip():
            target.unlink(missing_ok=True)
            return
    elif not rec.before.get("eof_newline", True) and out.endswith("\n"):
        blocks = split(out)
        if blocks and not matches(blocks[-1].name, rec.sections):
            out = out[:-1]
    atomic.write_bytes(target, out.encode("utf-8"))


def current(paths: Paths, rec: SlotRecord) -> bytes:
    """The matching sections as they are now (for conflicts/)."""
    return "".join(x.text for x in extract(_text(rec.write_path) or "", rec.sections)).encode("utf-8")
