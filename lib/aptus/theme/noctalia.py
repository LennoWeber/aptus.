"""Noctalia's enabled templates, read-only (02 §4 coverage rule): `[theme.templates]` from
~/.config/noctalia/*.toml (in name order) with ~/.local/state/noctalia/settings.toml as the final
overlay, as Noctalia 5 reads them: `builtin_ids` (when `enable_builtin_templates` is not false),
`community_ids` (when `enable_community_templates` is not false) and `[theme.templates.user.<id>]`
(unless `enabled = false`). Nothing here ever writes."""
from __future__ import annotations

import os
import tomllib
from collections.abc import Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from ..paths import Paths


@dataclass
class Enabled:
    builtin: list[str] = field(default_factory=list)
    community: list[str] = field(default_factory=list)
    user: dict[str, str] = field(default_factory=dict)       # user template id → output path ("" if dynamic)
    sources: list[str] = field(default_factory=list)         # files read
    error: str = ""                                          # unreadable or not TOML (reported, not raised)


def sources(paths: Paths) -> list[Path]:
    """~/.config/noctalia/*.toml (sorted), then ~/.local/state/noctalia/settings.toml, those that
    exist."""
    found = sorted(paths.noctalia_config.glob("*.toml")) if paths.noctalia_config.is_dir() else []
    if paths.noctalia_settings.is_file():
        found.append(paths.noctalia_settings)
    return found


def merge(tables: Sequence[dict[str, Any]]) -> dict[str, Any]:
    """Later tables override earlier ones key by key (nested tables merged, lists replaced)."""
    out: dict[str, Any] = {}
    for table in tables:
        for key, value in table.items():
            if isinstance(value, dict) and isinstance(out.get(key), dict):
                out[key] = merge([out[key], value])
            else:
                out[key] = value
    return out


def _ids(value: Any) -> list[str]:
    return [v for v in value if isinstance(v, str)] if isinstance(value, list) else []


def _output(paths: Paths, value: Any) -> str:
    """A user template's output path with `~` expanded; "" when it is not a plain string."""
    if not isinstance(value, str) or not value:
        return ""
    if value == "~" or value.startswith("~/"):
        value = str(paths.home) + value[1:]
    return os.path.normpath(value)


def enabled(paths: Paths) -> Enabled:
    """The enabled template ids; read-only (`open(…, "rb")` only), errors reported in `error`."""
    result = Enabled()
    tables = []
    for src in sources(paths):
        try:
            with open(src, "rb") as f:
                tables.append(tomllib.load(f))
            result.sources.append(str(src))
        except (OSError, tomllib.TOMLDecodeError) as e:
            result.error = f"{src}: {e}"
    templates = merge(tables).get("theme", {}).get("templates", {})
    if not isinstance(templates, dict):
        return result
    if templates.get("enable_builtin_templates", True) is not False:
        result.builtin = _ids(templates.get("builtin_ids"))
    if templates.get("enable_community_templates", True) is not False:
        result.community = _ids(templates.get("community_ids"))
    user = templates.get("user", {})
    for tid, cfg in (user.items() if isinstance(user, dict) else ()):
        if isinstance(cfg, dict) and cfg.get("enabled", True) is not False:
            result.user[tid] = _output(paths, cfg.get("output_path"))
    return result
