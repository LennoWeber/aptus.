"""The hyprland.lua edit of 09-hyprland §1: drop the Noctalia lines, append the aptus block.

Never writes by itself: install.sh shows the diff and applies the plan only after a yes.
"""
from __future__ import annotations

from dataclasses import dataclass, field

BLOCK_BEGIN = "-- >>> aptus >>>"
BLOCK_END = "-- <<< aptus <<<"


@dataclass(frozen=True)
class Removal:
    line_no: int               # 1-based, in the original file
    text: str                  # the line, without its newline
    reason: str                # which rule of 09 §1 removed it
    anchor_before: str         # the nearest kept line above (to put it back on uninstall)


@dataclass
class Plan:
    original: str
    new_text: str
    removals: list[Removal] = field(default_factory=list)
    block_present: bool = False   # the aptus block was already there (nothing appended)
