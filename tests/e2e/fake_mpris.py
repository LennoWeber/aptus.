#!/usr/bin/python3
"""A fake MPRIS player for the S3 e2e tests (brief: media keys act on a fake player on the
nested session's private bus, never on the real one).

Run inside the nested session (`Nested.exec`), so DBUS_SESSION_BUS_ADDRESS is the private bus:

    /usr/bin/python3 tests/e2e/fake_mpris.py <name> <state-file> [--playing] [--bare] [--art=<file URL>]

It owns `org.mpris.MediaPlayer2.<name>`, implements `org.mpris.MediaPlayer2` and
`org.mpris.MediaPlayer2.Player` (PlayPause, Play, Pause, Next, Previous, Seek, SetPosition and
the properties Quickshell reads) and appends every method call to <state-file>, one line each,
so the test can assert on what the shell did. `--bare` serves no metadata (notch.md §12); `--art` a cover. Uses
the system python3 with `gi` (GLib/Gio).
"""
from __future__ import annotations

import os
import sys
from dataclasses import dataclass, field

XML = """
<node>
  <interface name="org.mpris.MediaPlayer2">
    <method name="Raise"/>
    <method name="Quit"/>
    <property name="CanQuit" type="b" access="read"/>
    <property name="CanRaise" type="b" access="read"/>
    <property name="HasTrackList" type="b" access="read"/>
    <property name="Identity" type="s" access="read"/>
    <property name="DesktopEntry" type="s" access="read"/>
    <property name="SupportedUriSchemes" type="as" access="read"/>
    <property name="SupportedMimeTypes" type="as" access="read"/>
  </interface>
  <interface name="org.mpris.MediaPlayer2.Player">
    <method name="Next"/>
    <method name="Previous"/>
    <method name="Pause"/>
    <method name="PlayPause"/>
    <method name="Stop"/>
    <method name="Play"/>
    <method name="Seek"><arg direction="in" name="Offset" type="x"/></method>
    <method name="SetPosition"><arg direction="in" name="TrackId" type="o"/><arg direction="in" name="Position" type="x"/></method>
    <method name="OpenUri"><arg direction="in" name="Uri" type="s"/></method>
    <signal name="Seeked"><arg name="Position" type="x"/></signal>
    <property name="PlaybackStatus" type="s" access="read"/>
    <property name="LoopStatus" type="s" access="readwrite"/>
    <property name="Rate" type="d" access="readwrite"/>
    <property name="Shuffle" type="b" access="readwrite"/>
    <property name="Metadata" type="a{sv}" access="read"/>
    <property name="Volume" type="d" access="readwrite"/>
    <property name="Position" type="x" access="read"/>
    <property name="MinimumRate" type="d" access="read"/>
    <property name="MaximumRate" type="d" access="read"/>
    <property name="CanGoNext" type="b" access="read"/>
    <property name="CanGoPrevious" type="b" access="read"/>
    <property name="CanPlay" type="b" access="read"/>
    <property name="CanPause" type="b" access="read"/>
    <property name="CanSeek" type="b" access="read"/>
    <property name="CanControl" type="b" access="read"/>
  </interface>
</node>
"""
ROOT = "org.mpris.MediaPlayer2"
PLAYER = "org.mpris.MediaPlayer2.Player"
PATH = "/org/mpris/MediaPlayer2"


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
    volume: float = 1.0


class Player:
    """The two MPRIS interfaces over Gio.DBusConnection.register_object."""

    def __init__(self, state: PlayerState, log_path: str) -> None:
        from gi.repository import Gio, GLib
        self.Gio, self.GLib = Gio, GLib
        self.state = state
        self.log_path = log_path
        self.conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        info = Gio.DBusNodeInfo.new_for_xml(XML)
        for iface in info.interfaces:
            self.conn.register_object(PATH, iface, self._on_call, self._on_get, self._on_set)
        Gio.bus_own_name_on_connection(self.conn, f"{ROOT}.{state.name}", Gio.BusNameOwnerFlags.NONE, None, None)

    def _log(self, line: str) -> None:
        with open(self.log_path, "a", encoding="utf-8") as f:
            f.write(line + "\n")

    def metadata(self) -> dict:
        """The a{sv} Metadata of the current track (empty when bare)."""
        V = self.GLib.Variant
        if self.state.bare:
            return {}
        s = self.state
        md = {
            "mpris:trackid": V("o", f"/org/aptus/test/track{s.track}"),
            "mpris:length": V("x", s.length_us),
            "xesam:title": V("s", s.titles[s.track % len(s.titles)]),
            "xesam:artist": V("as", [s.artist]),
            "xesam:album": V("s", s.album),
        }
        if s.art_url:
            md["mpris:artUrl"] = V("s", s.art_url)
        return md

    def call(self, method: str, args: tuple) -> None:
        """Run a method call and log it."""
        s = self.state
        self._log(method + ("" if not args else " " + " ".join(str(a) for a in args)))
        changed = []
        if method == "PlayPause":
            s.status = "Paused" if s.status == "Playing" else "Playing"
            changed = ["PlaybackStatus"]
        elif method == "Play":
            s.status, changed = "Playing", ["PlaybackStatus"]
        elif method in ("Pause", "Stop"):
            s.status, changed = ("Paused" if method == "Pause" else "Stopped"), ["PlaybackStatus"]
        elif method in ("Next", "Previous"):
            s.track = (s.track + (1 if method == "Next" else -1)) % len(s.titles)
            s.position_us = 0
            changed = ["Metadata"]
        elif method == "Seek":
            s.position_us = max(0, min(s.length_us, s.position_us + int(args[0])))
            self.seeked()
        elif method == "SetPosition":
            s.position_us = max(0, min(s.length_us, int(args[1])))
            self.seeked()
        if changed:
            self.changed(changed)

    def get_property(self, interface: str, name: str):
        V, s = self.GLib.Variant, self.state
        if interface == ROOT:
            return {"CanQuit": V("b", False), "CanRaise": V("b", False), "HasTrackList": V("b", False),
                    "Identity": V("s", f"Test player {s.name}"), "DesktopEntry": V("s", f"test-{s.name}"),
                    "SupportedUriSchemes": V("as", []), "SupportedMimeTypes": V("as", [])}.get(name)
        props = {
            "PlaybackStatus": V("s", s.status), "Rate": V("d", 1.0), "Metadata": V("a{sv}", self.metadata()),
            "Volume": V("d", s.volume), "Position": V("x", s.position_us), "MinimumRate": V("d", 1.0),
            "MaximumRate": V("d", 1.0), "CanGoNext": V("b", True), "CanGoPrevious": V("b", True),
            "CanPlay": V("b", True), "CanPause": V("b", True), "CanSeek": V("b", not s.bare), "CanControl": V("b", True),
        }
        if s.shuffle is not None:
            props["Shuffle"] = V("b", s.shuffle)
        if s.loop_status is not None:
            props["LoopStatus"] = V("s", s.loop_status)
        return props.get(name)

    def set_property(self, interface: str, name: str, value) -> bool:
        """Shuffle, LoopStatus, Volume (writable); logged like a call."""
        s = self.state
        v = value.unpack()
        self._log(f"Set {name} {v}")
        if name == "Shuffle" and s.shuffle is not None:
            s.shuffle = bool(v)
        elif name == "LoopStatus" and s.loop_status is not None:
            s.loop_status = str(v)
        elif name == "Volume":
            s.volume = float(v)
        else:
            return False
        self.changed([name])
        return True

    def seeked(self) -> None:
        """Emit Seeked(position) after Seek or SetPosition."""
        self.conn.emit_signal(None, PATH, PLAYER, "Seeked", self.GLib.Variant("(x)", (self.state.position_us,)))

    def changed(self, names: list[str]) -> None:
        """Emit PropertiesChanged for the Player interface."""
        V = self.GLib.Variant
        values = {n: self.get_property(PLAYER, n) for n in names}
        self.conn.emit_signal(None, PATH, "org.freedesktop.DBus.Properties", "PropertiesChanged",
                              V("(sa{sv}as)", (PLAYER, values, [])))

    # Gio callbacks
    def _on_call(self, conn, sender, path, iface, method, params, invocation) -> None:
        self.call(method, tuple(params.unpack()))
        invocation.return_value(None)

    def _on_get(self, conn, sender, path, iface, name):
        return self.get_property(iface, name)

    def _on_set(self, conn, sender, path, iface, name, value) -> bool:
        return self.set_property(iface, name, value)


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    address = os.environ.get("DBUS_SESSION_BUS_ADDRESS", "")
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    if not address or f"path={runtime}/bus" in address or not os.environ.get("APTUS_TEST"):
        # dbus-run-session's private bus is a fresh socket; the real one is $XDG_RUNTIME_DIR/bus
        print("fake_mpris: refusing to run outside the nested session's private bus", file=sys.stderr)
        return 3
    flags = set(argv[2:])
    art = next((f.split("=", 1)[1] for f in flags if f.startswith("--art=")), "")
    state = PlayerState(name=argv[0], status="Playing" if "--playing" in flags else "Paused",
                        bare="--bare" in flags, shuffle=False, loop_status="None", art_url=art)
    Player(state, argv[1])
    from gi.repository import GLib
    GLib.MainLoop().run()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
