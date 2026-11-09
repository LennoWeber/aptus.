"""aptus-theme render (08 §4): the template language and the generations.

Template language (no logic): `{{ name }}` or `{{ name | filter }}`; names are the resolved roles,
`ansi0`…`ansi15`, `mode`, `accent.name`, `papirus.folder`, `gnome.accent`, `font.*`, `cursor.*`,
`frame.edge`, `window.gap`, `glass`, `reduce_motion`, `generation`. Filters: hex, hexnoh, rgb,
rgba(a), hyprrgba(a), argb(a), hsl, int. An unknown name or filter fails that target only.

Output: ~/.local/state/aptus/theme/gen-<n>/ with every target's files, resolved.json and
inputs.json; then `current` is swapped to it atomically; the last three generations are kept. An
unchanged input hash (resolved.json + manifest + templates + inputs) renders nothing.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from ..paths import Paths
from .inputs import Inputs
from .targets import FileOut, Manifest


class TemplateError(ValueError):
    """An unknown name or filter, or a malformed placeholder, in one template."""


@dataclass
class Generation:
    n: int                                     # gen-<n>
    path: Path
    input_hash: str
    resolved: dict[str, Any]
    reused: bool = False                       # the input hash was unchanged: nothing rendered
    failed: dict[str, str] = field(default_factory=dict)   # target id → error (previous output kept)


FILTERS = ("hex", "hexnoh", "rgb", "rgba", "hyprrgba", "argb", "hsl", "int")
KEEP = 3                                       # generations kept (08 §4)
PLACEHOLDER = re.compile(r"\{\{\s*([A-Za-z0-9_.]+)\s*(?:\|\s*([a-z]+)(?:\(([0-9.]+)\))?\s*)?\}\}")


def context(resolved: dict[str, Any], tokens: dict[str, Any], inputs: Inputs,
            generation: int) -> dict[str, str]:
    """Every name a template may use → its value (colours as "#rrggbb", the rest as text)."""
    raise NotImplementedError


def apply_filter(value: str, name: str, arg: str | None) -> str:
    """One filter on a "#rrggbb" value; TemplateError for an unknown filter, a missing or
    surplus argument, or a filter on a value that is not a colour."""
    raise NotImplementedError


def render_text(template: str, ctx: dict[str, str]) -> str:
    """Replace every placeholder; a `{{` that does not form one is a TemplateError."""
    raise NotImplementedError


def input_hash(resolved: dict[str, Any], inputs: Inputs, manifest_path: Path,
               templates: Path) -> str:
    """SHA-256 over resolved.json, inputs.json, the manifest and every template file (sorted)."""
    raise NotImplementedError


def current(paths: Paths) -> Generation | None:
    """The generation `current` points at (None when there is none or it is unreadable)."""
    raise NotImplementedError


def render(paths: Paths, inputs: Inputs, manifest: Manifest) -> Generation:
    """Resolve, hash, and when the hash changed write gen-<n+1>/ (each target's files; a failing
    target keeps its previous output, copied from the current generation), resolved.json,
    inputs.json; swap `current`; prune."""
    raise NotImplementedError


def prune(paths: Paths, keep: int = KEEP) -> None:
    """Remove all but the newest `keep` gen-<n>/ directories (never the one `current` names)."""
    raise NotImplementedError


def output(gen: Generation, f: FileOut) -> Path:
    """gen.path / f.out."""
    raise NotImplementedError
