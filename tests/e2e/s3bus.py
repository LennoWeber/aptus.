"""The nested session's private D-Bus for the S3 e2e tests: notify-send and gdbus calls, and the
fake MPRIS player, always on the nested bus (brief: never a notification, tray or MPRIS client on
the real session bus).

The bus address is read from a process inside the nested session (one with APTUS_TEST=1 and the
test HOME); it must differ from the address of the bus the tests run on.
"""
from __future__ import annotations

import json
import os
import signal
import subprocess
import time
from pathlib import Path

from aptus import atomic
from nested import Nested, test_processes

HERE = Path(__file__).resolve().parent


def bus_address(nested: Nested) -> str:
    """DBUS_SESSION_BUS_ADDRESS of the nested session (refuses the real one)."""
    real = os.environ.get("DBUS_SESSION_BUS_ADDRESS", "")
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    for pid in test_processes(nested.home):
        try:
            env = open(f"/proc/{pid}/environ", "rb").read().split(b"\0")
        except OSError:
            continue
        for e in env:
            if e.startswith(b"DBUS_SESSION_BUS_ADDRESS="):
                addr = e.split(b"=", 1)[1].decode()
                if addr and addr != real and f"path={runtime}/bus" not in addr:
                    return addr
    raise RuntimeError("no nested session bus found")


def nested_env(nested: Nested) -> dict[str, str]:
    """An environment for a client on the nested bus (and the nested HOME)."""
    env = {k: v for k, v in os.environ.items() if k not in ("DBUS_SESSION_BUS_ADDRESS", "WAYLAND_DISPLAY")}
    env.update(DBUS_SESSION_BUS_ADDRESS=bus_address(nested), HOME=str(nested.home), APTUS_TEST="1")
    return env


def notify(nested: Nested, summary: str, body: str = "", *args: str) -> int:
    """notify-send on the nested bus; returns the notification id (-p)."""
    r = subprocess.run(["notify-send", "-p", *args, summary, body], env=nested_env(nested),
                       capture_output=True, text=True, timeout=10, check=True)
    return int(r.stdout.strip().splitlines()[-1])


def notify_waiting(nested: Nested, summary: str, body: str = "", *args: str) -> tuple[int, subprocess.Popen]:
    """notify-send with actions (-A) waits for the choice: started in the background, it prints
    the id first. Returns the id and the process (terminate it after closing the notification)."""
    proc = subprocess.Popen(["notify-send", "-p", *args, summary, body], env=nested_env(nested),
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    line = proc.stdout.readline() if proc.stdout else ""
    return int(line.strip()), proc


def shell_pid(nested: Nested) -> int:
    """The test shell's process (qs / quickshell under the test HOME)."""
    for pid in test_processes(nested.home):
        try:
            cmd = open(f"/proc/{pid}/cmdline", "rb").read().split(b"\0")
        except OSError:
            continue
        if cmd and (cmd[0].endswith(b"qs") or cmd[0].endswith(b"quickshell")):
            return pid
    raise RuntimeError("no shell process")


def gdbus(nested: Nested, *args: str) -> str:
    """gdbus call on the nested bus (org.freedesktop.Notifications etc.)."""
    r = subprocess.run(["gdbus", "call", "--address", bus_address(nested), *args],
                       capture_output=True, text=True, timeout=10, check=True)
    return r.stdout.strip()


def close_notification(nested: Nested, nid: int) -> None:
    gdbus(nested, "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications",
          "--method", "org.freedesktop.Notifications.CloseNotification", str(nid))


def name_owner(nested: Nested, name: str) -> str:
    """The unique name owning `name` on the nested bus ("" when nobody does)."""
    try:
        out = gdbus(nested, "--dest", "org.freedesktop.DBus", "--object-path", "/org/freedesktop/DBus",
                    "--method", "org.freedesktop.DBus.GetNameOwner", name)
    except subprocess.CalledProcessError:
        return ""
    return out.strip("()',\" ")


class FakePlayer:
    """tests/e2e/fake_mpris.py on the nested bus; `calls()` reads what it was asked to do."""

    def __init__(self, nested: Nested, name: str, playing: bool = False, art: str = "") -> None:
        """art: a file:// URL of the cover ("" for none)."""
        self.state = nested.root / f"mpris-{name}.log"
        self.state.write_text("")
        argv = ["/usr/bin/python3", "-I", str(HERE / "fake_mpris.py"), name, str(self.state)] + (["--playing"] if playing else [])
        argv += [f"--art={art}"] if art else []
        self.proc = subprocess.Popen(argv, env=nested_env(nested), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.bus = f"org.mpris.MediaPlayer2.{name}"
        nested.wait_for(lambda: name_owner(nested, self.bus), 5)

    def calls(self) -> list[str]:
        return self.state.read_text().splitlines()

    def stop(self) -> None:
        self.proc.terminate()
        try:
            self.proc.wait(5)
        except subprocess.TimeoutExpired:
            self.proc.kill()


class FakeTray:
    """tests/e2e/fake_sni.py on the nested bus: one tray item with a DBusMenu; `calls()` reads
    what it got (Activate, menu events), `toggle()` flips NeedsAttention."""

    def __init__(self, nested: Nested) -> None:
        self.state = nested.root / "sni.log"
        self.state.write_text("")
        self.proc = subprocess.Popen(["/usr/bin/python3", "-I", str(HERE / "fake_sni.py"), str(self.state)],
                                     env=nested_env(nested), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        nested.wait_for(lambda: "registered" in self.calls(), 5)

    def calls(self) -> list[str]:
        return self.state.read_text().splitlines()

    def toggle(self) -> None:
        self.proc.send_signal(signal.SIGUSR1)

    def stop(self) -> None:
        self.proc.terminate()
        try:
            self.proc.wait(5)
        except subprocess.TimeoutExpired:
            self.proc.kill()


def settle(seconds: float = 0.3) -> None:
    """A short pause for an animation or a debounced write."""
    time.sleep(seconds)


def layout(nested: Nested) -> tuple[int, int]:
    """The output layout's extent (the virtual pointer's absolute coordinates span it)."""
    mons = nested.hyprctl("monitors", as_json=True) or []
    return (max(m["x"] + m["width"] for m in mons), max(m["y"] + m["height"] for m in mons))


def pointer(nested: Nested, cmd: str, x: int, y: int) -> None:
    """vpointer.py move/click at layout pixels, with the layout's real extent."""
    nested.vpointer(cmd, x, y, *layout(nested))


def wheel(nested: Nested, x: int, y: int, notches: int) -> None:
    """vpointer.py wheel at layout pixels: notches < 0 scroll up, > 0 down."""
    nested.vpointer("wheel", x, y, *layout(nested), notches)


def setting(nested: Nested, key: str, value: object = None) -> None:
    """Set one key in the nested HOME's settings.json (None resets it), then `shell reloadConfig`
    so the value is in before this returns (the file watch alone would take a moment)."""
    path = nested.paths.settings
    path.parent.mkdir(parents=True, exist_ok=True)
    data = json.loads(path.read_text()) if path.exists() else {}
    data["v"] = 2
    if value is None:
        data.pop(key, None)
    else:
        data[key] = value
    atomic.write_json(path, data)
    assert nested.msg("shell", "reloadConfig") == "ok"


def passive(nested: Nested) -> list[dict]:
    """The active monitor's passive entries (toasts, OSDs, events)."""
    st = nested.state()
    return st["monitors"][st["global"]["activeMonitor"]]["passive"]


def drained(nested: Nested, timeout: float = 12) -> None:
    """Wait until no toast, OSD or event is left on the active monitor (a clean state for the next
    test: an OSD fades 1.2 s after its last change, a toast after its timeout)."""
    nested.wait_for(lambda: not passive(nested), timeout)


def grab(nested: Nested, x: int, y: int, w: int, h: int) -> bytes:
    """RGB bytes of a layout region (grim -t ppm on the nested socket)."""
    env = dict(os.environ, WAYLAND_DISPLAY=nested.wayland_display)
    out = subprocess.run(["grim", "-t", "ppm", "-g", f"{x},{y} {w}x{h}", "-"], env=env, capture_output=True,
                         check=True, timeout=10).stdout
    parts = out.split(b"\n", 3)                         # P6, "w h", maxval, data
    return parts[3]


def mean(rgb: bytes) -> tuple[float, float, float]:
    n = max(1, len(rgb) // 3)
    return (sum(rgb[0::3]) / n, sum(rgb[1::3]) / n, sum(rgb[2::3]) / n)


def distance(a: tuple[float, float, float], b: tuple[float, float, float]) -> float:
    return sum((p - q) ** 2 for p, q in zip(a, b)) ** 0.5


class Window:
    """A kitty window in the nested session (its own class), optionally fullscreen."""

    def __init__(self, nested: Nested, cls: str) -> None:
        self.nested, self.cls = nested, cls
        nested.exec(f"kitty --class {cls}")
        nested.wait_for(lambda: self.client(), 15)
        self.focus()

    def client(self) -> dict | None:
        return next((c for c in self.nested.hyprctl("clients", as_json=True) or [] if c["class"] == self.cls), None)

    def focus(self) -> None:
        self.nested.hyprctl("dispatch", f'hl.dsp.focus({{ window = "class:^{self.cls}$" }})')

    def fullscreen(self) -> None:
        self.focus()
        self.nested.hyprctl("dispatch", "hl.dsp.window.fullscreen()")
        self.nested.wait_for(lambda: (self.client() or {}).get("fullscreen"), 5)

    def leave(self) -> None:
        self.focus()
        self.nested.hyprctl("dispatch", "hl.dsp.window.fullscreen()")
        self.nested.wait_for(lambda: not (self.client() or {}).get("fullscreen"), 5)

    def close(self) -> None:
        self.focus()
        self.nested.hyprctl("dispatch", "hl.dsp.window.close()")
        self.nested.wait_for(lambda: self.client() is None, 5)

    def to_workspace(self, workspace: str) -> None:
        """Move it to another workspace without following it."""
        self.nested.hyprctl("dispatch", f'hl.dsp.window.move({{ window = "class:^{self.cls}$", '
                                        f'workspace = "{workspace}", follow = false }})')
        self.nested.wait_for(lambda: str((self.client() or {}).get("workspace", {}).get("id")) == workspace, 5)


class BellWindow(Window):
    """An X11 kitty (XWayland) that rings its bell once per ring(): kitty sets the X11 urgency hint
    of an unfocused window, which Hyprland reports as `urgent` (a Wayland kitty's or foot's bell
    does not reach it in the nested session)."""

    def __init__(self, nested: Nested, cls: str) -> None:
        self.fifo = nested.root / f"{cls}.bell"
        if not self.fifo.exists():
            os.mkfifo(self.fifo)
        self.nested, self.cls = nested, cls
        nested.exec(f"kitty -o linux_display_server=x11 -o enable_audio_bell=no -o window_alert_on_bell=yes "
                    f"-o confirm_os_window_close=0 --class {cls} "
                    f"sh -c 'while :; do cat {self.fifo} >/dev/null; printf \"\\a\"; done'")
        nested.wait_for(lambda: self.client(), 15)
        time.sleep(0.5)                     # the shell inside reads the fifo

    def ring(self) -> None:
        with open(self.fifo, "w") as f:     # blocks until the reader is there; EOF rings once
            f.write("ring\n")
