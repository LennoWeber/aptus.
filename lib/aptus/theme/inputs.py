"""Inputs of a render (08 §2): the appearance settings (settings.json over the schema defaults),
the mode `auto` resolves to now, the wallpaper analysis the shell passes (or the last generation's),
and the settings that shape Own files (frame.edge, motion.reduce) and bakes."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any

from ..paths import Paths


@dataclass(frozen=True)
class Inputs:
    mode: str                          # "dark" | "light" (auto already resolved)
    accent: str                        # one of the six or "wallpaper"
    contrast: str                      # "normal" | "high"
    glass: bool
    mode_setting: str = "dark"         # appearance.mode as set ("auto" kept for the record)
    wallpaper_hue: float = -1          # degrees, −1 unknown
    wallpaper_chroma: float = -1
    wallpaper_lightness: float = -1    # 0..1, −1 unknown
    current_accent: str = "jade"       # ties and grey wallpapers keep it (08 §3 step 2)
    frame_edge: int = 6                # frame.edge → gaps in generated.lua
    reduce_motion: bool = False        # motion.reduce resolved (on, or auto + enable-animations off)
    bake_targets: tuple[str, ...] = () # isolation.bakeTargets


def setting(schema: dict[str, Any], settings: dict[str, Any], key: str) -> Any:
    """settings.json value of a dotted key, else the schema default (no validation: the shell's
    Config owns that; a value outside an enum falls back to the default)."""
    # TODO(S2): walk the dotted key in settings; missing or outside the schema enum →
    #   schema['keys'][key]['default'].
    raise NotImplementedError


def from_settings(paths: Paths, now: datetime | None = None) -> Inputs:
    """The inputs at session start: settings.json (mode with `auto` resolved by sun.py, accent,
    contrast, glass, frame.edge, motion.reduce, isolation.bakeTargets) and the wallpaper inputs of
    the current generation's inputs.json (the shell's last values; −1 without one)."""
    # TODO(S2): settings.json (missing or broken → {}), the schema; auto → sun.mode_at(now,
    #   weather.location); motion.reduce auto → off (no GNOME setting read); wallpaper
    #   values and current_accent from render.current(paths).inputs.
    raise NotImplementedError


def from_json(text: str) -> Inputs:
    """The shell's `--inputs` JSON (to_dict's shape); ValueError for a malformed one."""
    # TODO(S2): json.loads; dict with known keys only (camelCase); types checked; ValueError.
    raise NotImplementedError


def to_dict(inputs: Inputs) -> dict[str, Any]:
    """camelCase keys as resolve.js takes them (mode, accent, contrast, glass, wallpaperHue, …)."""
    # TODO(S2): camelCase as resolve.js reads them, plus modeSetting, frameEdge, reduceMotion,
    #   bakeTargets.
    raise NotImplementedError
