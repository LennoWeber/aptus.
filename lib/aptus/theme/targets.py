"""The target manifest theme/targets.toml (08 §5): one entry per row of 02-isolation §4. Adding an
app is adding an entry and a template. Also the coverage rule (02 §4): Noctalia's enabled
templates against the entries' `noctalia` lists."""
from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path


class Mechanism(str, Enum):
    LEASE = "lease"
    SCOPE = "scope"
    OWN = "own"
    BAKE = "bake"
    NEVER = "never"            # stays Noctalia's on purpose (with a `note` saying why)


@dataclass(frozen=True)
class FileOut:
    template: str              # path below theme/templates ("ghostty/theme")
    out: str                   # path inside the generation ("ghostty/noctalia")
    slot: str = ""             # lease / bake: the artifact (~ allowed; may hold one `*`)
    dest: str = ""             # own: where the file is written (~ allowed)


@dataclass(frozen=True)
class ScopeSpec:
    """Scope target outputs: a mirror of `mirror` in scope/<into> whose entries are symlinks except
    `replace` (a link to the rendered file), or a copy of `source` with the text between `begin`
    and `end` replaced by the rendered file (starship)."""
    into: str
    mirror: str = ""
    replace: str = ""
    source: str = ""
    begin: str = ""
    end: str = ""


@dataclass(frozen=True)
class Target:
    id: str
    row: int                                   # row in 02-isolation §4
    mechanism: Mechanism
    noctalia: tuple[str, ...] = ()             # Noctalia template ids this covers
    kind: str = "file"                         # lease: "file" | "ini-sections" | "dconf"
    files: tuple[FileOut, ...] = ()
    sections: tuple[str, ...] = ()             # ini-sections globs
    dconf: tuple[tuple[str, str], ...] = ()    # (key name, value template; "" = record only)
    scope: ScopeSpec | None = None
    own: str = ""                              # builtin Own step: icons | qt6ct | bat | ""
    when: str = "always"                       # always | exists:<path> | which:<command>
    present: bool = False                      # lease only the slots that exist (02 §4 "only if present")
    reload: str = "none"                       # none | signal:<comm>:<SIG> | exec:<cmd> | builtin:<name> | bake:<process>:<cmd>
    note: str = ""


@dataclass(frozen=True)
class Manifest:
    path: Path
    targets: tuple[Target, ...]
    inert: dict[str, str] = field(default_factory=dict)   # Noctalia id → why it does not matter in Hyprland


@dataclass
class Coverage:
    covered: dict[str, str] = field(default_factory=dict)    # Noctalia id → target id
    inert: dict[str, str] = field(default_factory=dict)      # Noctalia id → reason
    uncovered: list[str] = field(default_factory=list)       # reported: "uncovered: <id>"
