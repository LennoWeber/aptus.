"""aptus-theme apply (08 §6) = render, then under the lease flock: lease targets (aptus-lease
update; skipped in scope-only mode), scope mirrors, Own files, reload hooks; a JSON summary on
stdout. The shell shows a toast only for failures."""
from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass, field

from ..lease.slots import SlotSpec
from ..paths import Paths
from .inputs import Inputs
from .render import Generation
from .targets import Manifest


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


def slot_specs(paths: Paths, manifest: Manifest, gen: Generation,
               ids: Sequence[str] = ()) -> list[SlotSpec]:
    """The SlotSpecs of every active lease target (or only `ids`): file and ini-sections slots with
    their rendered bytes, dconf keys with their rendered values (record-only keys with None)."""
    raise NotImplementedError


def lease_mode(paths: Paths, signature: str) -> str:
    """"lease" when the journal is held by this session, else "scope-only"."""
    raise NotImplementedError


def apply(paths: Paths, inputs: Inputs, signature: str) -> Report:
    """08 §6: render; under the lease flock update the lease targets (lease mode only), rebuild
    scope targets, write Own targets; then the reload hooks; the report."""
    raise NotImplementedError


def report_json(r: Report) -> str:
    raise NotImplementedError
