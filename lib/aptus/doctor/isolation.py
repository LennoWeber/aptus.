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

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from ..paths import Paths
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
    # TODO(S2): the eight check_* in order (load_baseline once); then write doctor_stamp (atomic,
    #   the doctor's only write).
    raise NotImplementedError


def check_journal(paths: Paths) -> Check:
    """1: no journal, `released`, or `held` by a live owner; `taking`/`releasing` or a dead
    owner fails (recover has not run), an unreadable journal fails."""
    # TODO(S2): ops.status; None/released → ok; held + owner_alive → ok; else FAIL with the state
    #   and 'run aptus-lease recover'.
    raise NotImplementedError


def check_slots(paths: Paths) -> Check:
    """2: with no live owner, every slot of the last released journal equals its `before`, unless
    it changed after the release (mtime newer: Noctalia wrote it); a dconf value that differs is a
    warning (Lenno may have changed it in Umbriel); conflicts newer than the last check warn."""
    # TODO(S2): owner alive → ok ('inside Hyprland'); journal.last_released; per file/ini slot
    #   digest vs before_digest, mtime > released_at → ok; dconf differ → warn; conflicts
    #   dirs newer than doctor_stamp → warn.
    raise NotImplementedError


def check_environment(paths: Paths) -> Check:
    """3: none of ENV_VARS (nor XCURSOR_THEME with aptus's cursor theme) in `systemctl --user
    show-environment` unless a live owner holds the lease."""
    # TODO(S2): system.run systemctl --user show-environment; names in ENV_VARS (and XCURSOR_THEME
    #   == tokens cursor theme) without a live owner → FAIL; skipped tool → warn.
    raise NotImplementedError


def check_units(paths: Paths) -> Check:
    """4: no active `aptus-*` unit (aptus-recover.service aside) unless Hyprland runs."""
    # TODO(S2): systemctl --user list-units 'aptus-*' --state=active --plain --no-legend; anything
    #   but aptus-recover.service while not hyprland_running → FAIL.
    raise NotImplementedError


def check_umbriel(paths: Paths) -> Check:
    """5: a running Umbriel's environment, else any file of its config, has no
    QT_QPA_PLATFORMTHEME."""
    # TODO(S2): system.processes(UMBRIEL_NAMES) environ; else every file below umbriel_config read
    #   as text for the variable name.
    raise NotImplementedError


def check_coverage(paths: Paths) -> Check:
    """6: every enabled Noctalia template is covered or inert (02 §4); uncovered ids fail."""
    # TODO(S2): targets.coverage(noctalia.enabled(paths), slot paths); uncovered → FAIL listing
    #   ids; kept → detail; noctalia error → warn.
    raise NotImplementedError


def check_traps(paths: Paths, baseline: Baseline | None) -> Check:
    """7: no adw-gtk3* theme in ~/.local/share/themes or /usr/share/themes; no font file in
    ~/.local/share/fonts that is not in the install baseline or that is one of aptus's own."""
    # TODO(S2): adw-gtk3* in user_themes and system_themes; fonts dir entries minus baseline.fonts,
    #   and any named like the repo's own font files → FAIL.
    raise NotImplementedError


def check_untouched(paths: Paths, baseline: Baseline | None) -> Check:
    """8: ~/.config/umbriel (every file), Noctalia's settings.toml and greetd's config.toml have
    their baseline hashes, unless they changed outside every recorded lease period (Lenno, in
    Umbriel); a change during a lease period fails. Without a baseline: a warning."""
    # TODO(S2): per watched file: fingerprint vs baseline; differs: mtime inside a lease_periods()
    #   pair → FAIL, else ok (changed outside aptus).
    raise NotImplementedError


def lease_periods(paths: Paths) -> list[tuple[float, float]]:
    """(taken_at, released_at) epoch pairs from history/ and a held journal (released: now)."""
    # TODO(S2): history/*.json and the current journal: (taken_at, released_at or now) as epoch
    #   seconds.
    raise NotImplementedError


def hyprland_running(paths: Paths) -> bool:
    # TODO(S2): system.processes(['Hyprland']) non-empty.
    raise NotImplementedError


def fingerprint(path: Path) -> dict[str, Any]:
    """{sha256, mtime, size} of a file, {missing: true} when absent."""
    # TODO(S2): sha256 of bytes, st_mtime, st_size; FileNotFoundError → {missing: true}.
    raise NotImplementedError


def watched_files(paths: Paths) -> list[Path]:
    """The files check 8 covers: every regular file below ~/.config/umbriel, Noctalia's
    settings.toml, greetd's config.toml."""
    # TODO(S2): sorted rglob files of umbriel_config, noctalia_settings, greetd_config.
    raise NotImplementedError


def record_baseline(paths: Paths) -> Baseline:
    """Fingerprint the watched files and list ~/.local/share/fonts (install.sh, read-only)."""
    # TODO(S2): fingerprint each watched file; sorted names in fonts dir; recorded_at now.
    raise NotImplementedError


def load_baseline(paths: Paths) -> Baseline | None:
    # TODO(S2): json → Baseline; None when missing or broken.
    raise NotImplementedError


def save_baseline(paths: Paths, baseline: Baseline) -> None:
    # TODO(S2): atomic.write_json(paths.baseline, asdict).
    raise NotImplementedError
