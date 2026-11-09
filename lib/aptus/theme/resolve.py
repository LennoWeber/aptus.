"""Palette resolution (08-theming §3), a port of shell/core/js/resolve.js: the same inputs give
the same JSON in both (tests/unit/test_theme_resolve.py runs every combination through both)."""
from __future__ import annotations

from typing import Any

from ..paths import Paths
from .inputs import Inputs

# The roles of every resolution, in resolved.json key order (resolve.js ROLES).
ROLES = ("ground", "raised", "raisedHot", "sunken", "line",
         "inkMain", "inkSec", "inkMeta", "inkFaint", "warn", "crit", "onAccent",
         "accent", "accentWash", "washHover", "washCurrent", "washCurrentHover", "washPressed",
         "selectionBg", "selectionFg", "borderActive", "borderInactive", "link",
         "scrim", "scrimAlpha", "shadow", "shadowAlpha", "frameLine", "frameLineAlpha")


class ResolveError(ValueError):
    """An input outside the enums (resolve.js `invariant`)."""


def load_tokens(paths: Paths) -> dict[str, Any]:
    # TODO(S2): json.load(paths.tokens).
    raise NotImplementedError


def resolve(tokens: dict[str, Any], inputs: Inputs) -> dict[str, Any]:
    """{mode, palette, accentName, highContrast, glass, groundAlpha, papirus, gnomeAccent,
    roles: {role: "#rrggbb" | number}, ansi: [16], glyphGrad}; inputs.mode is dark or light."""
    # TODO(S2): port of resolve.js resolve(): checks as its invariant(), roles in ROLES order.
    raise NotImplementedError


def accent_for(tokens: dict[str, Any], accent: str, wallpaper_hue: float,
               wallpaper_chroma: float, current_accent: str, palette_name: str) -> str:
    # TODO(S2): port of resolve.js accentFor().
    raise NotImplementedError


def ground_alpha(tokens: dict[str, Any], glass: bool, mode: str, wallpaper_lightness: float) -> float:
    # TODO(S2): port of resolve.js groundAlpha().
    raise NotImplementedError
