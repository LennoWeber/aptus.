"""Palette resolution (08-theming §3), a port of shell/core/js/resolve.js: the same inputs give
the same JSON in both (tests/unit/test_theme_resolve.py runs every combination through both)."""
from __future__ import annotations

import json
from typing import Any

from ..paths import Paths
from . import palette
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
    with open(paths.tokens, encoding="utf-8") as f:
        return json.load(f)


def _check(tokens: dict[str, Any], inputs: Inputs) -> None:
    if not tokens.get("palettes") or not tokens.get("accents"):
        raise ResolveError("tokens without palettes or accents")
    if inputs.mode not in ("dark", "light"):
        raise ResolveError(f"mode {inputs.mode} (auto is resolved before)")
    if inputs.accent != "wallpaper" and inputs.accent not in tokens["accents"]:
        raise ResolveError(f"unknown accent {inputs.accent}")
    if inputs.contrast not in ("normal", "high"):
        raise ResolveError(f"contrast {inputs.contrast}")


def resolve(tokens: dict[str, Any], inputs: Inputs) -> dict[str, Any]:
    """{mode, palette, accentName, highContrast, glass, groundAlpha, papirus, gnomeAccent,
    roles: {role: "#rrggbb" | number}, ansi: [16], glyphGrad}; inputs.mode is dark or light."""
    _check(tokens, inputs)
    mode = inputs.mode
    palette_name = tokens["modes"][mode]
    p = tokens["palettes"][palette_name]
    accent_name = accent_for(tokens, inputs.accent, inputs.wallpaper_hue, inputs.wallpaper_chroma,
                             inputs.current_accent, palette_name)
    accent = tokens["accents"][accent_name][palette_name]
    high = inputs.contrast == "high"
    ink_sec, ink_meta = p["ink"]["sec"], p["ink"]["meta"]
    if high:
        t = tokens["contrastHigh"]["toward"]
        ink_sec = palette.toward(ink_sec, p["ink"]["main"], t)
        ink_meta = palette.toward(ink_meta, p["ink"]["main"], t)
    w = tokens["washes"]
    main, ground = p["ink"]["main"], p["ground"]
    roles = {
        "ground": ground, "raised": p["raised"], "raisedHot": p["raisedHot"], "sunken": p["sunken"],
        "line": p["line"], "inkMain": main, "inkSec": ink_sec, "inkMeta": ink_meta,
        "inkFaint": p["ink"]["faint"], "warn": p["warn"], "crit": p["crit"], "onAccent": p["onAccent"],
        "accent": accent,
        "accentWash": palette.over(accent, ground, w["accentWash"]),
        "washHover": palette.over(main, ground, w["hover"]),
        "washCurrent": palette.over(main, ground, w["current"]),
        "washCurrentHover": palette.over(main, ground, w["currentHover"]),
        "washPressed": palette.over(main, ground, w["pressed"]),
        "selectionBg": palette.over(accent, ground, p["selectionAmount"]),
        "selectionFg": main,
        "borderActive": accent, "borderInactive": p["line"], "link": accent,
        "scrim": p["scrim"]["color"], "scrimAlpha": p["scrim"]["alpha"],
        "shadow": p["shadow"]["color"], "shadowAlpha": p["shadow"]["alpha"],
        "frameLine": p["line"], "frameLineAlpha": tokens["frameLine"]["alpha"],
    }
    return {
        "mode": mode, "palette": palette_name, "accentName": accent_name, "highContrast": high,
        "glass": bool(inputs.glass),
        "groundAlpha": ground_alpha(tokens, bool(inputs.glass), mode, inputs.wallpaper_lightness),
        "papirus": tokens["accents"][accent_name]["papirus"],
        "gnomeAccent": tokens["accents"][accent_name]["gnome"],
        "roles": {r: roles[r] for r in ROLES}, "ansi": list(p["ansi"]), "glyphGrad": p["glyphGrad"],
    }


def accent_for(tokens: dict[str, Any], accent: str, wallpaper_hue: float,
               wallpaper_chroma: float, current_accent: str, palette_name: str) -> str:
    accents = tokens["accents"]
    current = current_accent if current_accent in accents else tokens["accentOrder"][0]
    if accent != "wallpaper":
        return accent if accent in accents else current
    if wallpaper_hue is None or wallpaper_hue < 0 or wallpaper_chroma is None \
            or wallpaper_chroma < tokens["wallpaperAccent"]["minChroma"]:
        return current
    pal = palette_name or "ember"
    best = current
    best_d = palette.hue_distance(palette.hue(accents[current][pal]), wallpaper_hue)
    for name in tokens["accentOrder"]:
        d = palette.hue_distance(palette.hue(accents[name][pal]), wallpaper_hue)
        if d < best_d - 1e-9:
            best, best_d = name, d
    return best


def ground_alpha(tokens: dict[str, Any], glass: bool, mode: str, wallpaper_lightness: float) -> float:
    if not glass:
        return tokens["glass"]["solidAlpha"]
    surfaces = tokens.get("surfaces") or {}
    half = surfaces["wallpaper"]["darkLightnessThreshold"] if surfaces.get("wallpaper") else 0.5
    wrong = wallpaper_lightness is not None and wallpaper_lightness >= 0 and (
        wallpaper_lightness > half if mode == "dark" else wallpaper_lightness < half)
    return tokens["glass"]["groundAlphaWrongHalf"] if wrong else tokens["glass"]["groundAlpha"]
