"""aptus-theme apply (08 §6) = render, then under the lease flock: lease targets (aptus-lease
update; skipped in scope-only mode), scope mirrors, Own files, reload hooks; a JSON summary on
stdout. The shell shows a toast only for failures."""
from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class Report:
    generation: int = 0
    mode: str = "scope-only"                                  # "lease" when this session holds the lease
    unchanged: bool = False                                   # same input hash, nothing applied
    applied: list[str] = field(default_factory=list)          # target ids live now
    next_start: list[str] = field(default_factory=list)       # written, the app shows it at its next start
    queued: list[str] = field(default_factory=list)           # bakes waiting for their app to close
    failed: dict[str, str] = field(default_factory=dict)      # target id → why
    not_installed: list[str] = field(default_factory=list)    # `when` false
    stays_noctalia: list[str] = field(default_factory=list)   # lease targets in scope-only mode, bake off, never
