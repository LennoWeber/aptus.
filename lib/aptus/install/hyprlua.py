"""The hyprland.lua edit of 09-hyprland §1: drop the Noctalia lines, append the aptus block.

Never writes by itself: install.sh shows the diff and applies the plan only after a yes.
"""
from __future__ import annotations

import difflib
import json
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
    # One pass over the text: `code` keeps strings and drops comments, `bare` also blanks the
    # strings' contents (for counting brackets and block keywords). Newlines survive in both.
    code: list[str] = []
    bare: list[str] = []
    i, n = 0, len(text)
    long_open = re.compile(r"\[(=*)\[")
    while i < n:
        c = text[i]
        if text.startswith("--", i):
            m = long_open.match(text, i + 2)
            if m:
                end = text.find("]" + m.group(1) + "]", m.end())
                end = n if end < 0 else end + len(m.group(1)) + 2
            else:
                end = text.find("\n", i)
                end = n if end < 0 else end
            newlines = "\n" * text.count("\n", i, end)
            code.append(newlines)
            bare.append(newlines)
            i = end
        elif c in "\"'":
            j = i + 1
            while j < n and text[j] != c and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            j = min(j + 1, n) if j < n and text[j] == c else j
            code.append(text[i:j])
            bare.append(c + c)
            i = j
        elif c == "[" and (m := long_open.match(text, i)):
            end = text.find("]" + m.group(1) + "]", m.end())
            end = n if end < 0 else end + len(m.group(1)) + 2
            code.append(text[i:end])
            bare.append('""' + "\n" * text.count("\n", i, end))
            i = end
        else:
            code.append(c)
            bare.append(c)
            i += 1
    code_lines = "".join(code).split("\n")
    bare_lines = "".join(bare).split("\n")
    if text.endswith("\n"):
        code_lines, bare_lines = code_lines[:-1], bare_lines[:-1]

    keyword = re.compile(r"\b(function|do|if|repeat|end|until)\b")
    continues_after = re.compile(r"(\.\.|,|=|\band|\bor|\bnot)\s*$")
    continues_before = re.compile(r"^\s*(\.\.|and\b|or\b|==|~=|[-+*/^%<>])")
    result: list[tuple[int, int, str]] = []
    start, brackets, blocks = 0, 0, 0
    for idx, line in enumerate(bare_lines):
        if not start:
            if not line.strip():
                continue                      # a blank or comment-only line
            start = idx + 1
        brackets += sum(line.count(o) for o in "([{") - sum(line.count(o) for o in ")]}")
        for m in keyword.finditer(line):
            blocks += 1 if m.group(1) in ("function", "do", "if", "repeat") else -1
        if brackets > 0 or blocks > 0 or continues_after.search(line):
            continue
        following = next((b for b in bare_lines[idx + 1:] if b.strip()), "")
        if continues_before.match(following):
            continue
        result.append((start, idx + 1, "\n".join(code_lines[start - 1:idx + 1])))
        start, brackets, blocks = 0, 0, 0
    if start:                                 # an unterminated statement runs to the end
        result.append((start, len(bare_lines), "\n".join(code_lines[start - 1:])))
    return result


def plan_install(text: str) -> Plan:
    """Remove the 09 §1 lines and append the block (idempotent: an existing block is kept)."""
    lines = [line + "\n" for line in text.split("\n")]
    if text.endswith("\n") or not text:
        lines.pop()
    else:
        lines[-1] = lines[-1][:-1]
    bare = [line.rstrip("\n") for line in lines]
    block_present = BLOCK_BEGIN in bare
    in_block = set()
    if block_present:
        begin = bare.index(BLOCK_BEGIN)
        end = bare.index(BLOCK_END, begin) if BLOCK_END in bare[begin:] else len(bare) - 1
        in_block = set(range(begin + 1, end + 2))
    rules = ((LOCAL_RE, "a local only Noctalia binds use"),
             (START_RE, "the Noctalia autostart (02 §8)"),
             (EXIT_BIND_RE, "Super+M exit, replaced by the graceful logout"),
             (BIND_CALL_RE, "a bind that calls Noctalia, replaced by an aptus bind (09 §7)"))
    removed: dict[int, str] = {}
    for first, last, code in statements(text):
        if first in in_block:
            continue
        for pattern, reason in rules:
            if pattern.search(code):
                for no in range(first, last + 1):
                    removed[no] = reason
                break
    removals = []
    anchor = ""
    for no, line in enumerate(bare, start=1):
        if no in removed:
            removals.append(Removal(no, line, removed[no], anchor))
        else:
            anchor = line
    new_text = "".join(line for no, line in enumerate(lines, start=1) if no not in removed)
    if not block_present:
        if new_text and not new_text.endswith("\n"):
            new_text += "\n"
        new_text += ("\n" if new_text else "") + BLOCK
    return Plan(original=text, new_text=new_text, removals=removals, block_present=block_present)


def plan_uninstall(text: str, removed: Sequence[Removal], restore: bool) -> Plan:
    """Remove the block; with `restore`, put the removed lines back after their anchors."""
    lines = [line + "\n" for line in text.split("\n")]
    if text.endswith("\n") or not text:
        lines.pop()
    else:
        lines[-1] = lines[-1][:-1]
    bare = [line.rstrip("\n") for line in lines]
    block_present = BLOCK_BEGIN in bare
    if block_present:
        begin = bare.index(BLOCK_BEGIN)
        end = bare.index(BLOCK_END, begin) if BLOCK_END in bare[begin:] else begin
        if begin > 0 and not bare[begin - 1].strip():
            begin -= 1                        # the blank line plan_install put before the block
        del lines[begin:end + 1]
    restored: list[Removal] = []
    if restore and removed:
        # Runs of consecutive lines go back where they were (the original line number, which is
        # exact while the rest of the file is unchanged), else after the nearest matching anchor.
        runs: list[list[Removal]] = []
        for r in sorted(removed, key=lambda r: r.line_no):
            if runs and r.line_no == runs[-1][-1].line_no + 1:
                runs[-1].append(r)
            else:
                runs.append([r])
        for run in runs:
            pos = run[0].line_no - 1
            current = [line.rstrip("\n") for line in lines]
            if not (0 <= pos <= len(lines) and
                    (current[pos - 1] if pos > 0 else "") == run[0].anchor_before):
                candidates = [i + 1 for i, line in enumerate(current) if line == run[0].anchor_before]
                pos = min(candidates, key=lambda i: abs(i - pos)) if candidates \
                    else min(max(pos, 0), len(lines))
            if pos == len(lines) and lines and not lines[-1].endswith("\n"):
                lines[-1] += "\n"
            lines[pos:pos] = [r.text + "\n" for r in run]
            restored += run
    return Plan(original=text, new_text="".join(lines), removals=restored,
                block_present=block_present)


def diff(plan: Plan, name: str = "hyprland.lua") -> str:
    """Unified diff of the plan (what install.sh shows before asking)."""
    return "".join(difflib.unified_diff(plan.original.splitlines(keepends=True),
                                        plan.new_text.splitlines(keepends=True),
                                        fromfile=f"{name} (now)", tofile=f"{name} (after)"))


def removed_lua(removals: Sequence[Removal]) -> str:
    """~/.local/state/aptus/install/removed.lua: the lines with their anchors, as Lua comments
    plus a JSON header that plan_uninstall reads back."""
    data = {"version": 1, "removals": [
        {"line_no": r.line_no, "text": r.text, "reason": r.reason, "anchor_before": r.anchor_before}
        for r in removals]}
    out = ["-- aptus: the lines install.sh removed from hyprland.lua (09-hyprland §1).",
           "-- `install.sh --uninstall` offers to put them back. Keep the next line as it is.",
           "-- aptus-removed: " + json.dumps(data, ensure_ascii=False), "--"]
    for r in removals:
        out.append(f"-- line {r.line_no} ({r.reason}), after: {r.anchor_before}")
        out.append(f"--   {r.text}")
    return "\n".join(out) + "\n"


def parse_removed(text: str) -> list[Removal]:
    for line in text.splitlines():
        if line.startswith("-- aptus-removed: "):
            data = json.loads(line[len("-- aptus-removed: "):])
            return [Removal(int(r["line_no"]), r["text"], r["reason"], r["anchor_before"])
                    for r in data["removals"]]
    return []
