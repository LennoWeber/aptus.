"""Owner liveness and recovery (02 §5.7). Recovery runs from aptus-recover.service when the user
manager starts and at the start of every aptus session; it acts only when the journal says a lease
is taking/held/releasing and the owner is dead, and then performs release (§5.6). It never takes.

    owner alive ⇔ owner.boot_id == current boot_id
                ∧ /proc/<hyprland_pid> exists ∧ /proc/<hyprland_pid>/comm == "Hyprland"
                ∧ $XDG_RUNTIME_DIR/hypr/<signature>/.socket.sock accepts a connection
"""
from __future__ import annotations
