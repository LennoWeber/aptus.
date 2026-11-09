"""Colour maths for the palette resolution (08-theming §3), a line-by-line port of
shell/core/js/colour.js: sRGB ↔ OKLab/OKLCH, mixing in OKLab, rounding half away from zero to
8-bit sRGB. Results must be byte-identical to the JS (tests/unit/test_theme_resolve.py)."""
from __future__ import annotations

import math
import re
from collections.abc import Sequence

_HEX = re.compile(r"#?[0-9a-fA-F]{6}")


def round8(x: float) -> int:
    v = math.floor(x + 0.5)
    return 0 if v < 0 else 255 if v > 255 else v


def hex_to_rgb(hex_colour: str) -> tuple[int, int, int]:
    """"#rrggbb" → (r, g, b); ValueError for anything else."""
    if not isinstance(hex_colour, str) or not _HEX.fullmatch(hex_colour):
        raise ValueError(f"not a #rrggbb colour: {hex_colour!r}")
    h = hex_colour.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def rgb_to_hex(rgb: Sequence[float]) -> str:
    return "#" + "".join(f"{round8(c):02x}" for c in rgb[:3])


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else math.pow((c + 0.055) / 1.055, 2.4)


def linear_to_srgb(c: float) -> float:
    return 12.92 * c if c <= 0.0031308 else 1.055 * math.pow(c, 1 / 2.4) - 0.055


def hex_to_oklab(hex_colour: str) -> tuple[float, float, float]:
    r8, g8, b8 = hex_to_rgb(hex_colour)
    r, g, b = srgb_to_linear(r8 / 255), srgb_to_linear(g8 / 255), srgb_to_linear(b8 / 255)
    l = math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    m = math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    s = math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def oklab_to_hex(lab: Sequence[float]) -> str:
    l = lab[0] + 0.3963377774 * lab[1] + 0.2158037573 * lab[2]
    m = lab[0] - 0.1055613458 * lab[1] - 0.0638541728 * lab[2]
    s = lab[0] - 0.0894841775 * lab[1] - 1.2914855480 * lab[2]
    l, m, s = l * l * l, m * m * m, s * s * s
    r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

    def ch(c: float) -> float:
        return 255 * linear_to_srgb(min(1, max(0, c)))
    return rgb_to_hex((ch(r), ch(g), ch(b)))


def oklab_to_oklch(lab: Sequence[float]) -> tuple[float, float, float]:
    c = math.sqrt(lab[1] * lab[1] + lab[2] * lab[2])
    h = math.atan2(lab[2], lab[1]) * 180 / math.pi
    if h < 0:
        h += 360
    return lab[0], c, h


def mix(a: str, b: str, t: float) -> str:
    A, B = hex_to_oklab(a), hex_to_oklab(b)
    return oklab_to_hex((A[0] + (B[0] - A[0]) * t, A[1] + (B[1] - A[1]) * t, A[2] + (B[2] - A[2]) * t))


def over(fg: str, bg: str, amount: float) -> str:
    return mix(bg, fg, amount)


def toward(start: str, end: str, t: float) -> str:
    return mix(start, end, t)


def hue_distance(a: float, b: float) -> float:
    d = math.fmod(abs(a - b), 360)
    return 360 - d if d > 180 else d


def hue(hex_colour: str) -> float:
    return oklab_to_oklch(hex_to_oklab(hex_colour))[2]
