"""Slot specifications (02 §5.3 step 4, 08 §6): what aptus wants each leased item to hold, built
from the rendered generation and theme/targets.toml. The kinds (kinds/) read, write and restore them.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from .journal import SlotKind


@dataclass(frozen=True)
class SlotSpec:
    id: str                          # "<target>.<name>", stable across sessions
    kind: SlotKind
    target: str                      # targets.toml id (settings page)
    reload: str = "none"             # the target's reload hook (recorded in the journal)
    create: bool = True              # a missing artifact is created (its parent must exist);
                                     # False ("only if present"): a missing one is skipped
    path: Path | None = None         # file / ini-sections: the slot (expanded, not resolved)
    content: bytes | None = None     # file: the rendered bytes; ini-sections: the rendered INI text
    sections: tuple[str, ...] = ()   # ini-sections: header globs ("Colors:*", "WM")
    key: str = ""                    # dconf: full key path (/org/gnome/desktop/interface/…)
    value: str | None = None         # dconf: GVariant text to write; None = record only
