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

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


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
