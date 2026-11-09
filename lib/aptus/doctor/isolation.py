"""`aptus doctor isolation` (02-isolation §10): one line per check, non-zero exit on any failure.

1. The journal is `released` (or `held` by a live owner).
2. Outside Hyprland: every slot equals the last journal's `before` (unless the file changed after
   the release, i.e. Noctalia wrote it since); nothing in conflicts/ is newer than the last check.
3. No aptus variable in `systemctl --user show-environment` unless a live Hyprland owns a lease.
4. No `aptus-*` unit running unless Hyprland is running.
5. Umbriel's environment (a running Umbriel process, else its config) has no QT_QPA_PLATFORMTHEME.
6. Every enabled Noctalia template is covered (02 §4 coverage rule).
7. No `adw-gtk3*` theme exists; no font files were added by aptus.
8. ~/.config/umbriel, ~/.local/state/noctalia/settings.toml and /etc/greetd/config.toml have their
   install-time hashes, unless they changed outside every recorded lease period (Lenno, in Umbriel).
Everything here only reads.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class Baseline:
    """install/baseline.json, written by install.sh (check 8) and read by the doctor."""
    recorded_at: str = ""                                     # ISO 8601
    files: dict[str, dict[str, Any]] = field(default_factory=dict)   # path → {sha256, mtime, size} | {missing: true}
    fonts: list[str] = field(default_factory=list)            # names in ~/.local/share/fonts at install
