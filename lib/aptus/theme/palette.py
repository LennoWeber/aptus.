"""Colour maths for the palette resolution (08-theming §3), a line-by-line port of
shell/core/js/colour.js: sRGB ↔ OKLab/OKLCH, mixing in OKLab, rounding half away from zero to
8-bit sRGB. Results must be byte-identical to the JS (tests/unit/test_theme_resolve.py)."""
from __future__ import annotations

from collections.abc import Sequence


def round8(x: float) -> int:
    raise NotImplementedError


def hex_to_rgb(hex_colour: str) -> tuple[int, int, int]:
    """"#rrggbb" → (r, g, b); ValueError for anything else."""
    raise NotImplementedError


def rgb_to_hex(rgb: Sequence[float]) -> str:
    raise NotImplementedError


def srgb_to_linear(c: float) -> float:
    raise NotImplementedError


def linear_to_srgb(c: float) -> float:
    raise NotImplementedError


def hex_to_oklab(hex_colour: str) -> tuple[float, float, float]:
    raise NotImplementedError


def oklab_to_hex(lab: Sequence[float]) -> str:
    raise NotImplementedError


def oklab_to_oklch(lab: Sequence[float]) -> tuple[float, float, float]:
    raise NotImplementedError


def mix(a: str, b: str, t: float) -> str:
    raise NotImplementedError


def over(fg: str, bg: str, amount: float) -> str:
    raise NotImplementedError


def toward(start: str, end: str, t: float) -> str:
    raise NotImplementedError


def hue_distance(a: float, b: float) -> float:
    raise NotImplementedError


def hue(hex_colour: str) -> float:
    raise NotImplementedError
