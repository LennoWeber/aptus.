"""`aptus doctor isolation` (02-isolation §10): one line per check, non-zero exit on any failure.

1. The journal is `released` (or `held` by a live owner).
2. Outside Hyprland: every slot equals the last journal's `before` (unless the file changed after
   the release, i.e. Noctalia wrote it since); nothing in conflicts/ is newer than the last check.
3. No aptus variable in `systemctl --user show-environment` unless a live Hyprland owns a lease.
4. No `aptus-*` unit running unless Hyprland is running.
5. Umbriel's environment (a running Umbriel process, else its config) has no QT_QPA_PLATFORMTHEME.
6. Every enabled Noctalia template is covered (02 §4 coverage rule).
7. No `adw-gtk3*` theme exists; no font files were added by aptus.
8. ~/.config/umbriel, ~/.local/state/noctalia/settings.toml and /etc/greetd/config.toml have their
   install-time hashes, unless they changed outside every recorded lease period (Lenno, in Umbriel).
Everything here only reads, except <state>/doctor-check (the time of this check, for check 2).
"""
from __future__ import annotations

import dataclasses
import hashlib
import json
import os
import time
from collections.abc import Sequence
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any

from .. import atomic
from ..lease import guard, invariants, journal, kinds, ops, system
from ..lease.journal import JournalError, SlotKind, SlotRecord, State
from ..paths import Paths
from ..theme import noctalia, targets
from . import Check


@dataclass
class Baseline:
    """install/baseline.json, written by install.sh (check 8) and read by the doctor."""
    recorded_at: str = ""                                     # ISO 8601
    files: dict[str, dict[str, Any]] = field(default_factory=dict)   # path → {sha256, mtime, size} | {missing: true}
    fonts: list[str] = field(default_factory=list)            # names in ~/.local/share/fonts at install


ENV_VARS = ("APTUS_SESSION", "QT_QPA_PLATFORMTHEME", "KITTY_CONFIG_DIRECTORY", "STARSHIP_CONFIG",
            "YAZI_CONFIG_HOME", "BAT_THEME", "BAT_CACHE_PATH")   # check 3 (+ XCURSOR_THEME = aptus's)
UMBRIEL_NAMES = ("umbriel",)                                      # check 5: process comm


def check(paths: Paths) -> list[Check]:
    """The eight checks in order, then the doctor stamp is updated."""
    baseline = load_baseline(paths)
    checks = []
    for name, fn in (("journal", lambda: check_journal(paths)),
                     ("slots", lambda: check_slots(paths)),
                     ("environment", lambda: check_environment(paths)),
                     ("units", lambda: check_units(paths)),
                     ("umbriel", lambda: check_umbriel(paths)),
                     ("coverage", lambda: check_coverage(paths)),
                     ("traps", lambda: check_traps(paths, baseline)),
                     ("untouched", lambda: check_untouched(paths, baseline))):
        try:
            checks.append(fn())
        except Exception as e:  # noqa: BLE001 - a broken check is a failure, not a crash
            checks.append(Check(f"isolation.{name}", False, f"{type(e).__name__}: {e}"))
    write_stamp(paths)
    return checks


def write_stamp(paths: Paths) -> None:
    """<state>/doctor-check: the time of this check (check 2's conflicts are "new" after it)."""
    try:
        invariants.writable(paths, paths.doctor_stamp, kind="state")
        paths.state.mkdir(parents=True, exist_ok=True)
        atomic.write_text(paths.doctor_stamp, f"{time.time():.0f}\n", 0o600)
    except (OSError, invariants.InvariantError):
        pass


def _live_owner(paths: Paths) -> bool:
    try:
        s = ops.status(paths)
    except JournalError:
        return False
    return s.state not in (None, State.RELEASED) and s.owner_alive


def check_journal(paths: Paths) -> Check:
    """1: no journal, `released`, or `held` by a live owner; `taking`/`releasing` or a dead
    owner fails (recover has not run), an unreadable journal fails."""
    name = "isolation.journal"
    try:
        s = ops.status(paths)
    except JournalError as e:
        return Check(name, False, f"{e}; a human must look at {paths.lease_journal}")
    if s.state in (None, State.RELEASED):
        return Check(name, True, "no lease")
    if s.state == State.HELD and s.owner_alive:
        return Check(name, True, f"held by Hyprland {s.owner.hyprland_pid if s.owner else '?'}")
    if s.owner_alive:
        return Check(name, False, f"lease {s.state.value} while its Hyprland runs: the guard "
                     "retries at Hyprland's exit; `aptus-lease release` gives it back now")
    return Check(name, False, f"lease {s.state.value}, its Hyprland is gone: run aptus-lease recover")


def _epoch(iso: str) -> float:
    try:
        return datetime.fromisoformat(iso).timestamp()
    except ValueError:
        return 0.0


def _slot_problem(paths: Paths, rec: SlotRecord, released: float) -> tuple[str, bool]:
    """("", _) when the slot equals its before; else (why, warn_only)."""
    mod = kinds.module(rec.kind)
    if mod.digest(paths, rec) == mod.before_digest(rec.before):
        return "", False
    if rec.kind == SlotKind.DCONF:
        return f"{rec.key} differs from before (changed in Umbriel?)", True
    try:
        changed = os.stat(rec.write_path).st_mtime > released
    except FileNotFoundError:
        changed = False
    if changed:
        return "", False                         # written after the release (Noctalia)
    return f"{rec.path} differs from Noctalia's before", False


def _new_conflicts(paths: Paths) -> list[str]:
    try:
        stamp = float(paths.doctor_stamp.read_text().strip())
    except (OSError, ValueError):
        stamp = 0.0
    if not paths.lease_conflicts.is_dir():
        return []
    return sorted(d.name for d in paths.lease_conflicts.iterdir() if d.stat().st_mtime > stamp)


def check_slots(paths: Paths) -> Check:
    """2: with no live owner, every slot of the last released journal equals its `before`, unless
    it changed after the release (mtime newer: Noctalia wrote it); a dconf value that differs is a
    warning (Lenno may have changed it in Umbriel); conflicts newer than the last check warn."""
    name = "isolation.slots"
    if _live_owner(paths):
        return Check(name, True, "inside Hyprland: the lease is held")
    last = journal.last_released(paths)
    fails, warns = [], []
    if last is not None:
        released = _epoch(last.released_at)
        for rec in last.slots:
            if not rec.write:
                continue
            try:
                why, warn = _slot_problem(paths, rec, released)
            except Exception as e:  # noqa: BLE001 - unreadable slot
                why, warn = f"{rec.id}: {type(e).__name__}: {e}", False
            if why:
                (warns if warn else fails).append(why)
    new = _new_conflicts(paths)
    if new:
        warns.append(f"new conflicts in {paths.lease_conflicts}: {', '.join(new)}")
    if fails:
        return Check(name, False, "; ".join(fails + warns))
    return Check(name, True, "; ".join(warns) or "Noctalia's paint", warn=bool(warns))


def aptus_env_values(paths: Paths) -> dict[str, str]:
    """Variables aptus may have imported and, where the name alone says nothing, aptus's value."""
    return {"XCURSOR_THEME": guard.aptus_values(paths)["XCURSOR_THEME"]}


def check_environment(paths: Paths) -> Check:
    """3: none of ENV_VARS (nor XCURSOR_THEME with aptus's cursor theme) in `systemctl --user
    show-environment` unless a live owner holds the lease."""
    name = "isolation.environment"
    r = system.run(paths, ["systemctl", "--user", "show-environment"])
    if r.skipped or r.code != 0:
        return Check(name, True, "systemctl --user show-environment did not run", warn=True)
    env = dict(line.split("=", 1) for line in r.stdout.splitlines() if "=" in line)
    found = [n for n in ENV_VARS if n in env]
    found += [n for n, v in aptus_env_values(paths).items() if env.get(n) == v and n not in found]
    if not found:
        return Check(name, True, "clean")
    if _live_owner(paths):
        return Check(name, True, f"{', '.join(found)} (the lease is held)")
    return Check(name, False, f"{', '.join(found)} in the user manager without a lease")


def check_units(paths: Paths) -> Check:
    """4: no active `aptus-*` unit (aptus-recover.service aside) unless Hyprland runs."""
    name = "isolation.units"
    r = system.run(paths, ["systemctl", "--user", "list-units", "aptus-*", "--state=active",
                           "--plain", "--no-legend", "--no-pager"])
    if r.skipped or r.code != 0:
        return Check(name, True, "systemctl --user list-units did not run", warn=True)
    units = [ln.split()[0] for ln in r.stdout.splitlines() if ln.split()]
    units = [u for u in units if u != "aptus-recover.service"]
    if units and not hyprland_running(paths):
        return Check(name, False, f"{', '.join(units)} active without Hyprland")
    return Check(name, True, ", ".join(units) or "none active")


def check_umbriel(paths: Paths) -> Check:
    """5: a running Umbriel's environment, else any file of its config, has no
    QT_QPA_PLATFORMTHEME."""
    name = "isolation.umbriel"
    procs = system.processes(paths, UMBRIEL_NAMES)
    if procs:
        bad = [str(p.pid) for p in procs if "QT_QPA_PLATFORMTHEME" in p.env]
        if bad:
            return Check(name, False, f"QT_QPA_PLATFORMTHEME in Umbriel's environment (pid {', '.join(bad)})")
        return Check(name, True, "Umbriel's environment is clean")
    for f in sorted(p for p in paths.umbriel_config.rglob("*") if p.is_file()) \
            if paths.umbriel_config.is_dir() else []:
        try:
            if b"QT_QPA_PLATFORMTHEME" in f.read_bytes():
                return Check(name, False, f"QT_QPA_PLATFORMTHEME in {f}")
        except OSError:
            continue
    return Check(name, True, "Umbriel's config is clean")


def check_coverage(paths: Paths) -> Check:
    """6: every enabled Noctalia template is covered or inert (02 §4); uncovered ids fail."""
    name = "isolation.coverage"
    manifest = targets.load(paths.targets, paths.templates)
    enabled = noctalia.enabled(paths)
    slot_paths = {s: t.id for t in manifest.targets for _, s in targets.slots(paths, t)}
    cov = targets.coverage(manifest, enabled, slot_paths)
    if cov.uncovered:
        return Check(name, False, "uncovered: " + ", ".join(cov.uncovered))
    detail = f"{len(cov.covered)} covered, {len(cov.inert)} inert"
    if cov.kept:
        detail += ", Noctalia's: " + ", ".join(sorted(cov.kept))
    if enabled.error:
        return Check(name, True, f"{detail}; {enabled.error}", warn=True)
    return Check(name, True, detail)


def _adw(dirs: Sequence[Path]) -> list[str]:
    return sorted(str(p) for d in dirs if d.is_dir() for p in d.glob("adw-gtk3*"))


def check_traps(paths: Paths, baseline: Baseline | None) -> Check:
    """7: no adw-gtk3* theme in ~/.local/share/themes or /usr/share/themes; no font file in
    ~/.local/share/fonts that is one of aptus's own; fonts added since the install baseline
    warn (aptus never adds any, but Lenno may)."""
    name = "isolation.traps"
    adw = _adw([paths.user_themes, paths.system_themes])
    fonts = sorted(p.name for p in paths.fonts.rglob("*") if p.is_file()) \
        if paths.fonts.is_dir() else []
    ours = {p.name for p in (paths.shell / "assets/fonts").glob("*") if p.is_file()} \
        if (paths.shell / "assets/fonts").is_dir() else set()
    bad = adw + [f for f in fonts if f in ours]
    if bad:
        return Check(name, False, ", ".join(bad))
    added = [f for f in fonts if baseline is not None and f not in baseline.fonts]
    if added:
        return Check(name, True, f"fonts added since install: {', '.join(added)}", warn=True)
    return Check(name, True, "no adw-gtk3, no aptus fonts")


def check_untouched(paths: Paths, baseline: Baseline | None) -> Check:
    """8: ~/.config/umbriel (every file), Noctalia's settings.toml and greetd's config.toml have
    their baseline hashes, unless they changed outside every recorded lease period (Lenno, in
    Umbriel); a change during a lease period fails. Without a baseline: a warning."""
    name = "isolation.untouched"
    if baseline is None:
        return Check(name, True, f"no baseline ({paths.baseline}); install.sh records it", warn=True)
    periods = lease_periods(paths)
    files = sorted({*baseline.files, *(str(p) for p in watched_files(paths))})
    during, outside = [], []
    for f in files:
        now = fingerprint(Path(f))
        was = baseline.files.get(f, {"missing": True})
        if {k: now.get(k) for k in ("sha256", "missing")} == {k: was.get(k) for k in ("sha256", "missing")}:
            continue
        mtime = now.get("mtime", 0.0)
        (during if any(a <= mtime <= b for a, b in periods) else outside).append(f)
    if during:
        return Check(name, False, "changed while aptus held the lease: " + ", ".join(during))
    if outside:
        return Check(name, True, "changed outside aptus: " + ", ".join(outside))
    return Check(name, True, "unchanged since install")


def lease_periods(paths: Paths) -> list[tuple[float, float]]:
    """(taken_at, released_at) epoch pairs from history/ and a held journal (released: now)."""
    out = []
    files = sorted(paths.lease_history.glob("*.json")) if paths.lease_history.is_dir() else []
    for f in files:
        try:
            j = journal.from_dict(json.loads(f.read_text(encoding="utf-8")))
        except (OSError, ValueError, JournalError):
            continue
        if j.owner is not None:
            out.append((_epoch(j.owner.taken_at), _epoch(j.released_at) or time.time()))
    try:
        cur = journal.load(paths)
    except JournalError:
        cur = None
    if cur is not None and cur.owner is not None:
        out.append((_epoch(cur.owner.taken_at), time.time()))
    return out


def hyprland_running(paths: Paths) -> bool:
    return bool(system.processes(paths, ["Hyprland"]))


def fingerprint(path: Path) -> dict[str, Any]:
    """{sha256, mtime, size} of a file, {missing: true} when absent."""
    try:
        data = path.read_bytes()
        st = os.stat(path)
    except FileNotFoundError:
        return {"missing": True}
    return {"sha256": hashlib.sha256(data).hexdigest(), "mtime": st.st_mtime, "size": st.st_size}


def watched_files(paths: Paths) -> list[Path]:
    """The files check 8 covers: every regular file below ~/.config/umbriel, Noctalia's
    settings.toml, greetd's config.toml."""
    found = sorted(p for p in paths.umbriel_config.rglob("*") if p.is_file()) \
        if paths.umbriel_config.is_dir() else []
    return found + [paths.noctalia_settings, paths.greetd_config]


def record_baseline(paths: Paths) -> Baseline:
    """Fingerprint the watched files and list ~/.local/share/fonts (install.sh, read-only)."""
    fonts = sorted(p.name for p in paths.fonts.rglob("*") if p.is_file()) \
        if paths.fonts.is_dir() else []
    return Baseline(recorded_at=journal.now(),
                    files={str(p): fingerprint(p) for p in watched_files(paths)}, fonts=fonts)


def load_baseline(paths: Paths) -> Baseline | None:
    try:
        raw = json.loads(paths.baseline.read_text(encoding="utf-8"))
        return Baseline(recorded_at=str(raw.get("recorded_at", "")), files=dict(raw["files"]),
                        fonts=list(raw.get("fonts", [])))
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        return None


def save_baseline(paths: Paths, baseline: Baseline) -> None:
    invariants.writable(paths, paths.baseline, kind="state")
    paths.baseline.parent.mkdir(parents=True, exist_ok=True)
    atomic.write_json(paths.baseline, dataclasses.asdict(baseline), 0o600)
