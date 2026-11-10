"""The theming pipeline (08-theming): resolve the palette (identical to shell/core/js/resolve.js),
render every target of theme/targets.toml into a generation, and apply it.

apply (render.lock held throughout, a lock of its own at state/theme/lock):
  render → generation N and state/theme/resolved.json (the shell's Tokens watch it) →
  lease targets through aptus.lease.ops.update (only while this session holds the lease; the
  lease lock is taken inside ops) → scope mirrors (swap) → Own files → reload hooks.
The session's start uses the same apply_generation after ops.take."""
from __future__ import annotations
