"""aptus-theme apply (08 §6) = render, then under the theme lock (render.lock): lease targets
(ops.update, which takes the lease lock itself; skipped in scope-only mode), scope mirrors, Own
files, reload hooks; a JSON summary on stdout. The shell shows a toast only for failures."""
from __future__ import annotations

import dataclasses
import json
import logging
from collections.abc import Sequence
from dataclasses import dataclass, field

from ..lease import ops
from ..lease.journal import SlotKind
from ..lease.kinds.dconf import KEY_DIR
from ..lease.slots import SlotSpec
from ..paths import Paths
from . import hooks, own, render, scope, targets
from .inputs import Inputs
from .render import Generation
from .targets import Manifest, Mechanism, Target


@dataclass
class Report:
    generation: int = 0
    mode: str = "scope-only"                                  # "lease" when this session holds the lease
    unchanged: bool = False                                   # same input hash, nothing applied
    applied: list[str] = field(default_factory=list)          # target ids live now (or already carrying it)
    next_start: list[str] = field(default_factory=list)       # written, the app shows it at its next start
    queued: list[str] = field(default_factory=list)           # bakes waiting for their app to close
    failed: dict[str, str] = field(default_factory=dict)      # target id → why
    not_installed: list[str] = field(default_factory=list)    # `when` false (or no slot present)
    stays_noctalia: list[str] = field(default_factory=list)   # lease targets in scope-only mode, bake off, never


_log = logging.getLogger("aptus.theme.apply")


def _bake_on(gen: Generation, t: Target) -> bool:
    return gen.inputs is not None and t.id in gen.inputs.bake_targets


def _in_place(paths: Paths, t: Target) -> bool:
    """A target a dconf key `requires` is applied: its `when` holds and, for an Own target, its
    output exists (own.in_place), so `icon-theme` never names an icon theme that is not there."""
    return targets.active(paths, t) and (t.mechanism != Mechanism.OWN or own.in_place(paths, t))


def _dconf_specs(paths: Paths, manifest: Manifest, gen: Generation, t: Target) -> list[SlotSpec]:
    values = json.loads((gen.path / t.id / render.DCONF_JSON).read_text(encoding="utf-8"))
    by_id = {x.id: x for x in manifest.targets}
    requires = dict(t.requires)
    specs = []
    for key, _ in t.dconf:
        value = values.get(key)
        need = requires.get(key)
        if need is not None and not _in_place(paths, by_id[need]):
            value = None
        specs.append(SlotSpec(id=f"{t.id}.{key}", kind=SlotKind.DCONF, target=t.id,
                              reload=t.reload, key=KEY_DIR + key, value=value))
    return specs


def _rendered(gen: Generation, t: Target) -> bool:
    """Every output of the target exists in the generation (a target that failed in a generation
    with no earlier output has none)."""
    return all((gen.path / out).is_file() for out in render.outputs(t))


def _file_specs(paths: Paths, gen: Generation, t: Target) -> list[SlotSpec]:
    return [SlotSpec(id=targets.slot_id(t, f, slot), kind=t.kind, target=t.id, reload=t.reload,
                     create=not t.present, path=slot,
                     content=render.output(gen, f).read_bytes(), sections=t.sections)
            for f, slot in targets.slots(paths, t)]


def slot_specs(paths: Paths, manifest: Manifest, gen: Generation,
               ids: Sequence[str] = ()) -> list[SlotSpec]:
    """The SlotSpecs of every active lease target, and of the bake targets named in
    gen.inputs.bake_targets (or only `ids`): file and ini-sections slots with their rendered bytes,
    dconf keys with the values rendered into <gen>/<id>/dconf.json (record-only keys, and keys
    whose `requires` target is not in place, with None). A target that failed to render is left
    out."""
    specs: list[SlotSpec] = []
    for t in manifest.targets:
        wanted = t.mechanism == Mechanism.LEASE or (t.mechanism == Mechanism.BAKE and _bake_on(gen, t))
        if not wanted or (ids and t.id not in ids) or t.id in gen.failed \
                or not targets.active(paths, t) or not _rendered(gen, t):
            continue
        specs += _dconf_specs(paths, manifest, gen, t) if t.kind == SlotKind.DCONF \
            else _file_specs(paths, gen, t)
    return specs


def _classify(report: Report, gen: Generation, lease: bool, paths: Paths,
              t: Target) -> str:
    """What apply_generation does with a target: skip (already reported), lease, scope or own."""
    if t.mechanism == Mechanism.NEVER or (t.mechanism == Mechanism.BAKE and not _bake_on(gen, t)):
        report.stays_noctalia.append(t.id)
        return "skip"
    if not targets.active(paths, t):
        report.not_installed.append(t.id)
        return "skip"
    if t.id in gen.failed:
        report.failed[t.id] = gen.failed[t.id]
        return "skip"
    if t.mechanism in (Mechanism.LEASE, Mechanism.BAKE):
        if not lease:
            report.stays_noctalia.append(t.id)
            return "skip"
        return "lease"
    return t.mechanism.value


def _update_lease(paths: Paths, manifest: Manifest, gen: Generation, leased: list[Target],
                  report: Report, taken: Sequence[str] | None) -> dict[str, str]:
    """ops.update for the leased targets; returns target id → reload of those written. With
    `taken` (the slots the take just wrote with this generation) nothing is updated: those slots
    count as written, so their hooks run (02 §5.3 step 8)."""
    specs = slot_specs(paths, manifest, gen, [t.id for t in leased])
    by_target: dict[str, list[str]] = {t.id: [] for t in leased}
    for s in specs:
        by_target[s.target].append(s.id)
    if taken is not None:
        up = ops.UpdateReport(generation=gen.n, written=[s.id for s in specs if s.id in taken])
    else:
        try:
            up = ops.update(paths, specs, gen.n)
        except ops.LeaseError as e:
            report.failed.update({t.id: f"lease: {e}" for t in leased})
            return {}
    changed = {}
    for t in leased:
        ids = by_target[t.id]
        bad = {i: up.failed[i] for i in ids if i in up.failed}
        if not ids:
            report.not_installed.append(t.id)
        elif bad:
            report.failed[t.id] = "; ".join(f"{i}: {why}" for i, why in sorted(bad.items()))
        elif any(i in up.written for i in ids):
            changed[t.id] = t.reload
        elif all(i in up.unchanged for i in ids):
            report.applied.append(t.id)             # carries this paint already: no write, no hook
        else:
            report.next_start.append(t.id)          # taken at the next session start
    return changed


def _record_hooks(report: Report, manifest: Manifest, changed: dict[str, str],
                  results: list[hooks.HookResult]) -> None:
    by_id = {t.id: t for t in manifest.targets}
    seen = set()
    for r in results:
        seen.add(r.target)
        if r.state == "failed":
            report.failed[r.target] = r.detail
        else:
            {"applied": report.applied, "queued": report.queued}.get(
                r.state, report.next_start).append(r.target)
    for tid, reload in changed.items():
        if tid not in seen:            # reload "none": dconf is live, files show at next start
            live = by_id[tid].kind == SlotKind.DCONF and by_id[tid].mechanism == Mechanism.LEASE
            (report.applied if live else report.next_start).append(tid)


def apply_generation(paths: Paths, manifest: Manifest, gen: Generation, signature: str,
                     taken: Sequence[str] | None = None) -> Report:
    """08 §6 steps 1–5 for a rendered generation: the lease targets through ops.update when this
    session holds the lease (ops.holds), else they stay Noctalia's; under the theme lock the
    scope targets and the Own targets; then the reload hooks of what changed; the report.
    aptus-session uses it at start, right after the take of this generation (`taken`: the slot
    ids it wrote, which are not written again), apply after each render."""
    lease = bool(signature) and ops.holds(paths, signature)
    report = Report(generation=gen.n, mode="lease" if lease else "scope-only")
    changed: dict[str, str] = {}
    leased: list[Target] = []
    with render.lock(paths):
        for t in manifest.targets:
            what = _classify(report, gen, lease, paths, t)
            if what == "lease":
                leased.append(t)
            elif what in ("scope", "own"):
                try:
                    (scope if what == "scope" else own).apply(paths, t, gen)
                    changed[t.id] = t.reload
                except Exception as e:  # noqa: BLE001 - one target never stops the others
                    report.failed[t.id] = f"{type(e).__name__}: {e}"
                    _log.warning("%s %s failed: %s", what, t.id, report.failed[t.id])
        if leased:
            changed.update(_update_lease(paths, manifest, gen, leased, report, taken))
        results = hooks.run_reloads(paths, changed, signature)
    _record_hooks(report, manifest, changed, results)
    return report


def apply_required(paths: Paths, manifest: Manifest, gen: Generation) -> None:
    """Before a take: the Own targets a leased dconf key `requires` (the icon themes), so the take
    can select them at once instead of only recording the key; apply_generation applies them again
    afterwards (a no-op then) and reports a failure."""
    by_id = {t.id: t for t in manifest.targets}
    for need in sorted({tid for t in manifest.targets for _, tid in t.requires}):
        t = by_id[need]
        if t.mechanism != Mechanism.OWN or t.id in gen.failed or not targets.active(paths, t):
            continue
        try:
            own.apply(paths, t, gen)
        except Exception as e:  # noqa: BLE001 - the key is then only recorded
            _log.warning("own %s failed before the take: %s: %s", t.id, type(e).__name__, e)


def apply(paths: Paths, inputs: Inputs, signature: str, manifest: Manifest | None = None) -> Report:
    """08 §6: render, then apply_generation, all under the theme lock so an older request
    never lands after a newer one. An unchanged input hash reports `unchanged` and does nothing
    else, unless this session's lease does not carry that generation yet (an earlier apply of
    it failed or was cut off): then it is applied again."""
    manifest = manifest or targets.load(paths.targets, paths.templates)
    with render.lock(paths):
        gen = render.render(paths, inputs, manifest)
        lease = bool(signature) and ops.holds(paths, signature)
        if gen.reused and not (lease and ops.status(paths).generation != gen.n):
            return Report(generation=gen.n, mode="lease" if lease else "scope-only", unchanged=True)
        return apply_generation(paths, manifest, gen, signature)


def report_json(r: Report) -> str:
    """The JSON summary on stdout (keys as the dataclass, "next-start" for next_start)."""
    d = dataclasses.asdict(r)
    d["next-start"] = d.pop("next_start")
    return json.dumps(d, sort_keys=True)
