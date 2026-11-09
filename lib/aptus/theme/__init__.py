"""The theming pipeline (08-theming): resolve the palette (identical to shell/core/js/resolve.js),
render every target of theme/targets.toml into a generation, and apply it: lease targets through
aptus-lease, scope mirrors, Own files, reload hooks."""
from __future__ import annotations
