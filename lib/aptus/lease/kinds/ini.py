"""Kind `ini-sections` (02 §5.5): kdeglobals' [Colors:*], [ColorEffects:*] and [WM] sections.

The file is split into blocks: the preamble (before the first header) and one block per `[header]`
line with every line up to the next header, all verbatim. A section matches when its header name
matches a glob (`Colors:Header][Inactive` matches `Colors:*`). `before` keeps each matching section
with its anchor, the name of the non-matching block right before it. Writing and restoring remove
the matching sections and put the new ones after their anchors (unknown anchor: the end), so every
other byte stays as it is, including a missing final newline.
"""
from __future__ import annotations

from dataclasses import dataclass


@dataclass
class Block:
    name: str | None           # the header name without brackets; None for the preamble
    text: str                  # verbatim, including the header line and the final newline (if any)


@dataclass
class Section:
    name: str                  # header name
    anchor: str | None         # name of the non-matching block before it (None: the preamble/start)
    text: str                  # verbatim block text
