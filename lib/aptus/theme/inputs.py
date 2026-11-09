"""Inputs of a render (08 §2): the appearance settings (settings.json over the schema defaults),
the mode `auto` resolves to now, the wallpaper analysis the shell passes (or the last generation's),
and the settings that shape Own files (frame.edge, motion.reduce) and bakes."""
from __future__ import annotations

from dataclasses import dataclass


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
