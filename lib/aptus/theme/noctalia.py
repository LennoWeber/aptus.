"""Noctalia's enabled templates, read-only (02 §4 coverage rule): `[theme.templates]` from
~/.config/noctalia/*.toml (in name order) with ~/.local/state/noctalia/settings.toml as the final
overlay, as Noctalia 5 reads them: `builtin_ids` (when `enable_builtin_templates` is not false),
`community_ids` (when `enable_community_templates` is not false) and `[theme.templates.user.<id>]`
(unless `enabled = false`). Nothing here ever writes."""
from __future__ import annotations

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
    # TODO(S2): sorted glob of noctalia_config/*.toml, then noctalia_settings if it exists.
    raise NotImplementedError


def merge(tables: Sequence[dict[str, Any]]) -> dict[str, Any]:
    """Later tables override earlier ones key by key (nested tables merged, lists replaced)."""
    # TODO(S2): recursive dict merge, later wins.
    raise NotImplementedError


def enabled(paths: Paths) -> Enabled:
    """The enabled template ids; read-only (`open(…, "rb")` only), errors reported in `error`."""
    # TODO(S2): tomllib each source (open 'rb' only); theme.templates: enable_builtin_templates,
    #   builtin_ids, enable_community_templates, community_ids, user.<id> (enabled,
    #   output_path); errors → Enabled.error.
    raise NotImplementedError
