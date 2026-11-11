"""Inputs of a render (08 §2): the appearance settings (settings.json over the schema defaults),
the mode `auto` resolves to now, the wallpaper analysis the shell passes (or the last generation's),
and the settings that shape Own files (frame.edge, motion.reduce) and bakes."""
from __future__ import annotations

import json
import math
from dataclasses import asdict, dataclass
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


# camelCase key (resolve.js, the shell's --inputs) → field name
_FIELDS = {"mode": "mode", "accent": "accent", "contrast": "contrast", "glass": "glass",
           "modeSetting": "mode_setting", "wallpaperHue": "wallpaper_hue",
           "wallpaperChroma": "wallpaper_chroma", "wallpaperLightness": "wallpaper_lightness",
           "currentAccent": "current_accent", "frameEdge": "frame_edge",
           "reduceMotion": "reduce_motion", "bakeTargets": "bake_targets"}
_TYPES = {"mode": str, "accent": str, "contrast": str, "glass": bool, "mode_setting": str,
          "wallpaper_hue": (int, float), "wallpaper_chroma": (int, float),
          "wallpaper_lightness": (int, float), "current_accent": str, "frame_edge": int,
          "reduce_motion": bool, "bake_targets": (list, tuple)}


def _valid(spec: dict[str, Any], value: Any) -> bool:
    t = spec.get("type")
    if t == "enum":
        return value in spec.get("values", [])
    if t == "bool":
        return isinstance(value, bool)
    if t == "list":
        return isinstance(value, list) and all(v in spec.get("values", []) for v in value)
    if t == "object":
        return value is None and spec.get("nullable", False) or isinstance(value, dict)
    return True


def setting(schema: dict[str, Any], settings: dict[str, Any], key: str) -> Any:
    """settings.json value of a key (the file is flat: {"v": 2, "appearance.mode": …}), else the
    schema default (a value outside the schema's type or enum falls back to the default; the
    shell's Config reports it)."""
    spec = schema["keys"][key]
    if key in settings and _valid(spec, settings[key]):
        return settings[key]
    return spec["default"]


def _read_json(path: Path) -> dict[str, Any]:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return raw if isinstance(raw, dict) and "v" in raw else {}


def system_reduced_motion(paths: Paths) -> bool:
    """org.gnome.desktop.interface enable-animations is false (`gsettings get`, as the shell's
    Motion reads it); False when it cannot be read."""
    from ..lease import system
    r = system.run(paths, ["gsettings", "get", "org.gnome.desktop.interface", "enable-animations"])
    return not r.skipped and r.code == 0 and r.stdout.strip() == "false"


def from_settings(paths: Paths, now: datetime | None = None) -> Inputs:
    """The inputs at session start: settings.json (mode with `auto` resolved by sun.py, accent,
    contrast, glass, frame.edge, motion.reduce with `auto` resolved as the shell's Motion.reduced
    does, isolation.bakeTargets) and the wallpaper inputs of the current generation's inputs.json
    (the shell's last values; −1 without one)."""
    from . import render, sun
    schema = json.loads(paths.schema.read_text(encoding="utf-8"))
    settings = _read_json(paths.settings)

    def get(key: str) -> Any:
        return setting(schema, settings, key)
    mode_setting = get("appearance.mode")
    mode = sun.mode_at(now or datetime.now(), get("weather.location")) \
        if mode_setting == "auto" else mode_setting
    reduce = get("motion.reduce")
    last = render.current(paths)
    prev = last.inputs if last is not None and last.inputs is not None else None
    return Inputs(mode=mode, accent=get("appearance.accent"), contrast=get("appearance.contrast"),
                  glass=bool(get("appearance.glass")), mode_setting=mode_setting,
                  wallpaper_hue=prev.wallpaper_hue if prev else -1,
                  wallpaper_chroma=prev.wallpaper_chroma if prev else -1,
                  wallpaper_lightness=prev.wallpaper_lightness if prev else -1,
                  current_accent=last.resolved.get("accentName", "jade") if last else "jade",
                  frame_edge=int(get("frame.edge")),
                  reduce_motion=reduce == "on" or (reduce == "auto" and system_reduced_motion(paths)),
                  bake_targets=tuple(get("isolation.bakeTargets")))


def from_dict(raw: Any) -> Inputs:
    """to_dict's shape back to Inputs; ValueError for unknown keys, wrong types, a missing
    mode/accent/contrast/glass, or a mode that is not dark or light."""
    if not isinstance(raw, dict):
        raise ValueError("inputs must be a JSON object")
    unknown = sorted(set(raw) - set(_FIELDS))
    if unknown:
        raise ValueError(f"unknown inputs: {', '.join(unknown)}")
    kw: dict[str, Any] = {}
    for key, value in raw.items():
        name = _FIELDS[key]
        want = _TYPES[name]
        if isinstance(value, bool) and want is not bool and bool not in (want if isinstance(want, tuple) else (want,)):
            raise ValueError(f"{key}: a boolean is not allowed")
        if not isinstance(value, want):
            raise ValueError(f"{key}: wrong type {type(value).__name__}")
        if isinstance(value, float) and not math.isfinite(value):
            raise ValueError(f"{key}: not a finite number")
        kw[name] = tuple(value) if name == "bake_targets" else value
    for need in ("mode", "accent", "contrast", "glass"):
        if need not in kw:
            raise ValueError(f"inputs without {need}")
    if kw["mode"] not in ("dark", "light"):
        raise ValueError(f"mode {kw['mode']!r} (auto is resolved before)")
    return Inputs(**kw)


def from_json(text: str) -> Inputs:
    """The shell's `--inputs` JSON (to_dict's shape); ValueError for a malformed one."""
    return from_dict(json.loads(text))


def to_dict(inputs: Inputs) -> dict[str, Any]:
    """camelCase keys as resolve.js takes them (mode, accent, contrast, glass, wallpaperHue, …)."""
    d = asdict(inputs)
    out = {key: d[name] for key, name in _FIELDS.items()}
    out["bakeTargets"] = list(inputs.bake_targets)
    return out
