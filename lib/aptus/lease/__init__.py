"""The lease (02-isolation §5): aptus's journaled, temporary takeover of Noctalia's artifacts and a
fixed set of dconf keys for the length of a Hyprland session. Only this package writes a leased
slot (CLAUDE.md); aptus-theme reaches the slots through `ops.update` under the flock."""
from __future__ import annotations
