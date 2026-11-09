"""Noctalia's enabled templates, read-only (02 §4 coverage rule): `[theme.templates]` from
~/.config/noctalia/*.toml (in name order) with ~/.local/state/noctalia/settings.toml as the final
overlay, as Noctalia 5 reads them: `builtin_ids` (when `enable_builtin_templates` is not false),
`community_ids` (when `enable_community_templates` is not false) and `[theme.templates.user.<id>]`
(unless `enabled = false`). Nothing here ever writes."""
from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class Enabled:
    builtin: list[str] = field(default_factory=list)
    community: list[str] = field(default_factory=list)
    user: dict[str, str] = field(default_factory=dict)       # user template id → output path ("" if dynamic)
    sources: list[str] = field(default_factory=list)         # files read
    error: str = ""                                          # unreadable or not TOML (reported, not raised)
