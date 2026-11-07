"""The hyprland.lua edit of 09-hyprland §1: drop the Noctalia lines, append the aptus block.

Never writes by itself: install.sh shows the diff and applies the plan only after a yes.
"""
from __future__ import annotations

import re
from collections.abc import Sequence

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


# 09 §1: the Noctalia-specific statements. The patterns apply to whole top-level statements
# (`statements` joins a call spread over several lines; comments are skipped and never removed),
# hence re.S: in Lenno's file the autostart spans three lines with `noctalia` on the middle one.
LOCAL_RE = re.compile(r"^\s*local\s+(noctalia|menu|lock)\s*=", re.S)
START_RE = re.compile(r"hl\.on\(\s*\"hyprland\.start\".*noctalia", re.S)
BIND_CALL_RE = re.compile(r"^\s*hl\.bind\(.*\b(noctalia|menu|lock)\b", re.S)
EXIT_BIND_RE = re.compile(r"^\s*hl\.bind\(.*\+\s*M\".*hl\.dsp\.exit\(\)", re.S)

BLOCK = (BLOCK_BEGIN + "\n"
         "-- aptus v2 (~/Code/Projekte/aptus). Managed by install.sh; `install.sh --uninstall` removes it.\n"
         'require("aptus.init")\n'
         + BLOCK_END + "\n")


def statements(text: str) -> list[tuple[int, int, str]]:
    """Split Lua source into top-level statements: (first line, last line, text), 1-based, so a
    bind spread over several lines is removed as a whole. Comment lines and comment blocks
    (`--`, `--[[ … ]]`) are not statements (a commented-out autostart stays as it is); strings
    are respected when counting brackets."""
    raise NotImplementedError


def plan_install(text: str) -> Plan:
    """Remove the 09 §1 lines and append the block (idempotent: an existing block is kept)."""
    raise NotImplementedError


def plan_uninstall(text: str, removed: Sequence[Removal], restore: bool) -> Plan:
    """Remove the block; with `restore`, put the removed lines back after their anchors."""
    raise NotImplementedError


def diff(plan: Plan, name: str = "hyprland.lua") -> str:
    """Unified diff of the plan (what install.sh shows before asking)."""
    raise NotImplementedError


def removed_lua(removals: Sequence[Removal]) -> str:
    """~/.local/state/aptus/install/removed.lua: the lines with their anchors, as Lua comments
    plus a JSON header that plan_uninstall reads back."""
    raise NotImplementedError


def parse_removed(text: str) -> list[Removal]:
    raise NotImplementedError
