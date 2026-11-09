"""The target manifest theme/targets.toml (08 §5): one entry per row of 02-isolation §4. Adding an
app is adding an entry and a template. Also the coverage rule (02 §4): Noctalia's enabled
templates against the entries' `noctalia` lists."""
from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any

from ..lease.journal import SlotKind
from ..paths import Paths
from .noctalia import Enabled


class Mechanism(str, Enum):
    LEASE = "lease"
    SCOPE = "scope"
    OWN = "own"
    BAKE = "bake"
    NEVER = "never"            # stays Noctalia's on purpose (with a `note` saying why)


@dataclass(frozen=True)
class FileOut:
    """One rendered file of a target and where it goes. Paths may start with `~` or one of
    {config} {state} {cache} {data} (the XDG base directories, so tests and a changed XDG variable
    agree with paths.py)."""
    template: str              # path below theme/templates ("ghostty/noctalia")
    out: str                   # path inside the generation ("ghostty/noctalia")
    name: str = "artifact"     # slot id "<target>.<name>"; a `*` slot adds ".<sha256(path)[:8]>"
    slot: str = ""             # lease / bake: the artifact (may hold one `*`, globbed, sorted)
    dest: str = ""             # own: where the file is written
    at: str = ""               # scope mirror: the path inside the mirror this file replaces
    missing_only: bool = False # scope mirror: used only when the mirrored source lacks `at`


@dataclass(frozen=True)
class ScopeSpec:
    """Scope outputs below scope/: a mirror of `mirror` in scope/<into> (symlinks to every entry,
    except the target's files at their `at` paths), or a copy of `source` with the text between
    the `begin` and `end` lines replaced by the rendered file (starship)."""
    into: str                  # name below scope/ ("kitty", "starship.toml"); no "/" or ".."
    mirror: str = ""
    source: str = ""
    begin: str = ""
    end: str = ""


@dataclass(frozen=True)
class Target:
    id: str
    row: int                                   # row in 02-isolation §4
    mechanism: Mechanism
    noctalia: tuple[str, ...] = ()             # Noctalia template ids this covers (or keeps, for never)
    kind: SlotKind = SlotKind.FILE             # lease / bake
    files: tuple[FileOut, ...] = ()
    sections: tuple[str, ...] = ()             # ini-sections globs
    dconf: tuple[tuple[str, str], ...] = ()    # (key name, value template; "" = record only)
    requires: tuple[tuple[str, str], ...] = () # dconf: (key name, target id) — the key is only
                                               # recorded when that target is not applied (icons)
    scope: ScopeSpec | None = None
    own: str = ""                              # builtin Own step: icons | bat | ""
    when: str = "always"                       # always | exists:<path> | which:<command>
    present: bool = False                      # lease only the slots that exist (02 §4 "only if present")
    reload: str = "none"                       # none | signal:<comm>:<SIG> | exec:<cmd> | builtin:<name> | bake:<process>:<cmd>
    note: str = ""


@dataclass
class Manifest:
    path: Path
    targets: tuple[Target, ...]
    inert: dict[str, str] = field(default_factory=dict)   # Noctalia id → why it does not matter in Hyprland


@dataclass
class Coverage:
    covered: dict[str, str] = field(default_factory=dict)    # Noctalia id → target id
    kept: dict[str, str] = field(default_factory=dict)       # Noctalia id → target id of a `never` target
    inert: dict[str, str] = field(default_factory=dict)      # Noctalia id → reason
    uncovered: list[str] = field(default_factory=list)       # reported: "uncovered: <id>"


class ManifestError(ValueError):
    """targets.toml is malformed (unknown field, mechanism, kind, reload or a missing template)."""


def load(path: Path) -> Manifest:
    """Parse and validate targets.toml (tomllib)."""
    raise NotImplementedError


def parse_target(raw: dict[str, Any]) -> Target:
    """One `[[target]]` table; the one-file shorthand (template/out/slot at the top level) becomes
    a single FileOut."""
    raise NotImplementedError


def expand(paths: Paths, value: str) -> Path:
    """`~` → paths.home, {config} {state} {cache} {data} → the XDG base directories; every other
    path must be absolute (ManifestError)."""
    raise NotImplementedError


def active(paths: Paths, target: Target) -> bool:
    """The `when` rule: always, exists:<path>, which:<command> (under test: $HOME/.aptus-test/bin)."""
    raise NotImplementedError


def slots(paths: Paths, target: Target) -> list[tuple[FileOut, Path]]:
    """(file, slot path) of a lease or bake target: `*` expanded by glob (sorted), and with
    `present` only the slots that exist."""
    raise NotImplementedError


def coverage(manifest: Manifest, enabled: Enabled, slot_paths: Sequence[Path]) -> Coverage:
    """Each enabled Noctalia id is covered by a lease/scope/own/bake target's `noctalia` list, kept
    by a `never` target's, inert, or (a user template) covered when its output path is one of
    `slot_paths`; else uncovered."""
    raise NotImplementedError
