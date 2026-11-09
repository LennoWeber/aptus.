"""Slot specifications (02 §5.3 step 4, 08 §6): what aptus wants each leased item to hold, built
from the rendered generation and theme/targets.toml. The kinds (kinds/) read, write and restore them.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class SlotSpec:
    id: str                          # "<target>.<name>", stable across sessions
    kind: str                        # "file" | "ini-sections" | "dconf"
    target: str                      # targets.toml id (reload hook, settings page)
    path: Path | None = None         # file / ini-sections: the slot (expanded, not resolved)
    content: bytes | None = None     # file: the rendered bytes; ini-sections: the rendered INI text
    sections: tuple[str, ...] = ()   # ini-sections: header globs ("Colors:*", "WM")
    key: str = ""                    # dconf: full key path (/org/gnome/desktop/interface/…)
    value: str | None = None         # dconf: GVariant text to write; None = record only
