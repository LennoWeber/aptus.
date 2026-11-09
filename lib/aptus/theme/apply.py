"""aptus-theme apply (08 §6) = render, then under the theme lock (render.lock): lease targets
(ops.update, which takes the lease lock itself; skipped in scope-only mode), scope mirrors, Own
files, reload hooks; a JSON summary on stdout. The shell shows a toast only for failures."""
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
    """The SlotSpecs of every active lease target, and of the bake targets named in
    gen.inputs.bake_targets (or only `ids`): file and ini-sections slots with their rendered bytes,
    dconf keys with the values rendered into <gen>/<id>/dconf.json (record-only keys, and keys
    whose `requires` target is not active, with None)."""
    # TODO(S2): targets.active and targets.slots per target; id "<target>.<name>" (+ ".<sha8>" for
    #   a glob); SlotSpec(kind, target, reload, create = not present, content = output bytes,
    #   sections); dconf: read dconf.json, key = KEY_DIR + name.
    raise NotImplementedError


def apply_generation(paths: Paths, manifest: Manifest, gen: Generation, signature: str) -> Report:
    """08 §6 steps 1–5 for a rendered generation: the lease targets through ops.update when this
    session holds the lease (ops.held_by), else they stay Noctalia's; under the theme lock the
    scope targets and the Own targets; then the reload hooks of what changed; the report.
    aptus-session uses it at start (after take), apply after each render."""
    # TODO(S2): mode = "lease" if ops.held_by(paths, signature) else "scope-only"; lease: ops.update
    #   (LeaseError → failed); with render.lock: scope.apply / own.apply per active target
    #   (exceptions → failed[target]); hooks.run_all on applied targets; not_installed from
    #   targets.active; stays_noctalia: lease targets in scope-only, bake not opted in, never.
    raise NotImplementedError


def apply(paths: Paths, inputs: Inputs, signature: str) -> Report:
    """08 §6: render (unchanged input hash: report unchanged, nothing else), then
    apply_generation."""
    # TODO(S2): targets.load(paths.targets); render.render; reused → Report(unchanged=True, …).
    raise NotImplementedError


def report_json(r: Report) -> str:
    """The JSON summary on stdout (keys as the dataclass, "next-start" for next_start)."""
    # TODO(S2): json.dumps(dataclasses.asdict(r)) with next_start renamed.
    raise NotImplementedError
