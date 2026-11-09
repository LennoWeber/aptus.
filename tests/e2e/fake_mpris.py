#!/usr/bin/python3
"""A fake MPRIS player for the S3 e2e tests (brief: media keys act on a fake player on the
nested session's private bus, never on the real one).

Run inside the nested session (`Nested.exec`), so DBUS_SESSION_BUS_ADDRESS is the private bus:

    /usr/bin/python3 tests/e2e/fake_mpris.py <name> <state-file> [--playing] [--bare]

It owns `org.mpris.MediaPlayer2.<name>`, implements `org.mpris.MediaPlayer2` and
`org.mpris.MediaPlayer2.Player` (PlayPause, Play, Pause, Next, Previous, Seek, SetPosition and
the properties Quickshell reads) and appends every method call to <state-file>, one line each,
so the test can assert on what the shell did. `--bare` serves no metadata (notch.md §12). Uses
the system python3 with `gi` (GLib/Gio).
"""
from __future__ import annotations

import sys
from dataclasses import dataclass, field


@dataclass
class PlayerState:
    name: str
    status: str = "Paused"          # "Playing" | "Paused" | "Stopped"
    track: int = 0
    titles: list[str] = field(default_factory=lambda: ["First track", "Second track", "Third track"])
    artist: str = "Test Artist"
    album: str = "Test Album"
    art_url: str = ""               # file:// URL of a cover, "" for none
    length_us: int = 180_000_000
    position_us: int = 0
    shuffle: bool | None = None     # None: the player does not support shuffle
    loop_status: str | None = None  # None: no loop support; "None" | "Track" | "Playlist"
    bare: bool = False              # no metadata at all


class Player:
    """The two MPRIS interfaces over Gio.DBusConnection.register_object."""

    def __init__(self, state: PlayerState, log_path: str) -> None:
        raise NotImplementedError

    def metadata(self) -> dict:
        """The a{sv} Metadata of the current track (empty when bare)."""
        raise NotImplementedError

    def call(self, method: str, args: tuple) -> None:
        """Run a method call and log it."""
        raise NotImplementedError

    def get_property(self, interface: str, name: str):
        raise NotImplementedError

    def changed(self, names: list[str]) -> None:
        """Emit PropertiesChanged for the Player interface."""
        raise NotImplementedError


def main(argv: list[str]) -> int:
    raise NotImplementedError


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
