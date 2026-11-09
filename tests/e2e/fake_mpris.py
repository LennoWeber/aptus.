#!/usr/bin/python3
"""A fake MPRIS player for the S3 e2e tests (brief: media keys act on a fake player on the
nested session's private bus, never on the real one).

Run inside the nested session (`Nested.exec`), so DBUS_SESSION_BUS_ADDRESS is the private bus:

    /usr/bin/python3 tests/e2e/fake_mpris.py <name> <state-file>

It owns `org.mpris.MediaPlayer2.<name>`, implements `org.mpris.MediaPlayer2` and
`org.mpris.MediaPlayer2.Player` (PlayPause, Play, Pause, Next, Previous, Seek, SetPosition and
the properties Quickshell reads) and appends every method call to <state-file>, one line each,
so the test can assert on what the shell did. Uses the system python3 with `gi` (GLib/Gio).
"""
from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class PlayerState:
    name: str
    status: str = "Paused"          # "Playing" | "Paused" | "Stopped"
    track: int = 0
    titles: list[str] = field(default_factory=lambda: ["First track", "Second track", "Third track"])
    artist: str = "Test Artist"
    album: str = "Test Album"
    length_us: int = 180_000_000
    position_us: int = 0
