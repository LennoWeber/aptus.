"""The lease (02-isolation §5): aptus's journaled, temporary takeover of Noctalia's artifacts and a
fixed set of dconf keys for the length of a Hyprland session. Only this package writes a leased
slot (CLAUDE.md "aptus-lease"): aptus-session, aptus-theme and aptus-guard call `ops` in-process,
`bin/aptus-lease` is its command line."""
from __future__ import annotations
