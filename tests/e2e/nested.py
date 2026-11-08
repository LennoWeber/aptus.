"""The nested Hyprland harness (07 §13, design/probes.md "How the nested probes run").

A Hyprland in a window of Lenno's session, with HOME pointing at a temporary directory, a private
session bus (dbus-run-session), HYPRLAND_NO_SD_VARS=1 (no import into the real user manager) and
APTUS_TEST=1. Every hyprctl call names the nested instance (-i); the real session's signature is
exported as APTUS_REAL_HYPRLAND_SIGNATURE so the tools refuse it.
"""
from __future__ import annotations

import json
import os
import shutil
import signal
import struct
import subprocess
import time
import zlib
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[2]


@dataclass
class Nested:
    root: Path                      # temporary directory: home/, cfg/, logs
    home: Path
    signature: str = ""             # the nested HYPRLAND_INSTANCE_SIGNATURE
    wayland_display: str = ""       # its socket name (wayland-N)
    proc: subprocess.Popen | None = None
    shell_pid: int = 0
    log: list[str] = field(default_factory=list)

    def start(self, timeout: float = 10.0) -> None:
        """Start Hyprland with tests/e2e/hyprland.lua; wait for its socket."""
        self.home.mkdir(parents=True, exist_ok=True)
        local_bin = self.home / ".local" / "bin"
        local_bin.mkdir(parents=True, exist_ok=True)
        for name in ("aptus", "aptus-session", "aptus-supervise"):
            link = local_bin / name
            if not link.is_symlink():
                link.symlink_to(REPO / "bin" / name)
        walls = self.home / "Pictures" / "Wallpapers"
        walls.mkdir(parents=True, exist_ok=True)
        write_test_png(walls / "test.png")
        cfg = self.root / "cfg"
        cfg.mkdir(parents=True, exist_ok=True)
        shutil.copy(REPO / "tests" / "e2e" / "hyprland.lua", cfg / "hyprland.lua")
        if not (cfg / "aptus").is_symlink():
            (cfg / "aptus").symlink_to(REPO / "hypr")
        real = real_signature()
        env = {k: v for k, v in os.environ.items() if k not in ("HYPRLAND_INSTANCE_SIGNATURE", "APTUS_DEV")}
        env.update(HOME=str(self.home), HYPRLAND_NO_SD_VARS="1", HYPRLAND_NO_SD_NOTIFY="1",
                   APTUS_TEST="1", APTUS_REAL_HYPRLAND_SIGNATURE=real)
        hypr_dir = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "hypr"
        before = set(os.listdir(hypr_dir)) if hypr_dir.exists() else set()
        log = open(self.root / "hyprland.log", "wb")
        self.proc = subprocess.Popen(["dbus-run-session", "--", "Hyprland", "--config", str(cfg / "hyprland.lua")],
                                     env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)

        def found() -> str:
            new = set(os.listdir(hypr_dir)) - before if hypr_dir.exists() else set()
            for sig in new:
                if (hypr_dir / sig / ".socket.sock").exists():
                    return sig
            return ""
        self.signature = self.wait_for(found, timeout)
        if self.signature == real:
            raise RuntimeError("found the real session's signature; refusing")
        def display() -> str:
            for inst in self.hyprctl("instances", as_json=True) or []:
                if inst.get("instance") == self.signature:
                    return inst.get("wl_socket", "")
            return ""
        self.wayland_display = self.wait_for(display, timeout)

    def stop(self) -> None:
        if self.signature:
            try:
                self.hyprctl("dispatch", "hl.dsp.exit()")
            except Exception:
                pass
        if self.proc:
            try:
                self.proc.wait(5)
            except subprocess.TimeoutExpired:
                os.killpg(self.proc.pid, signal.SIGTERM)
                try:
                    self.proc.wait(5)
                except subprocess.TimeoutExpired:
                    pass
        # Everything started inside the session carries our temporary HOME: the supervisor and
        # the shell must not outlive it (they would crash-loop without a display).
        for pid in test_processes(self.home):
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        # A Hyprland that was killed leaves its runtime dir behind; only ever the nested one.
        if self.signature and self.signature != real_signature():
            runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "hypr" / self.signature
            if self.proc is None or self.proc.poll() is not None:
                shutil.rmtree(runtime, ignore_errors=True)

    def hyprctl(self, *args: str, as_json: bool = False) -> Any:
        if not self.signature:
            raise RuntimeError("no nested signature")
        cmd = ["hyprctl", "-i", self.signature, *args] + (["-j"] if as_json else [])
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=10).stdout
        if as_json:
            try:
                return json.loads(out)
            except json.JSONDecodeError:
                return None
        return out

    def exec(self, command: str) -> None:
        """Run a command inside the nested session (hl.dsp.exec_cmd), so it inherits the private
        bus and the temporary HOME."""
        self.hyprctl("dispatch", f"hl.dsp.exec_cmd({lua_string(command)})")

    def start_shell(self, timeout: float = 10.0) -> None:
        """aptus-session start inside the nested session; wait until `shell state` answers."""
        def answers() -> bool:
            try:
                return self.state() is not None
            except Exception:
                return False
        self.wait_for(answers, timeout)

    def shortcut(self, name: str) -> None:
        """hl.dsp.global("aptus:<name>") over the socket (virtual keyboards cannot fire binds)."""
        self.hyprctl("dispatch", f'hl.dsp.global("aptus:{name}")')

    def msg(self, target: str, function: str, *args: str) -> str:
        """aptus msg with WAYLAND_DISPLAY set to the nested socket."""
        env = dict(os.environ, HOME=str(self.home), WAYLAND_DISPLAY=self.wayland_display, APTUS_TEST="1",
                   HYPRLAND_INSTANCE_SIGNATURE=self.signature, APTUS_REAL_HYPRLAND_SIGNATURE=real_signature())
        r = subprocess.run([str(REPO / "bin" / "aptus"), "msg", target, function, *args],
                           env=env, capture_output=True, text=True, timeout=10)
        self.log.append(f"msg {target} {function} {' '.join(args)} → {r.returncode}: {r.stdout.strip()[:200]}")
        if r.returncode != 0:
            raise RuntimeError(f"aptus msg {target} {function}: exit {r.returncode}: {r.stdout}{r.stderr}")
        return r.stdout.strip()

    def state(self) -> dict:
        return json.loads(self.msg("shell", "state"))

    def click(self, x: int, y: int) -> None:
        """A left click through vpointer.py (zwlr_virtual_pointer_v1 on the nested socket)."""
        runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
        subprocess.run(["python3", "-I", str(Path(__file__).with_name("vpointer.py")),
                        os.path.join(runtime, self.wayland_display), "click", str(x), str(y)],
                       check=True, timeout=10)

    def screenshot(self, path: Path) -> Path:
        """grim of the nested output (WAYLAND_DISPLAY = the nested socket)."""
        env = dict(os.environ, WAYLAND_DISPLAY=self.wayland_display)
        subprocess.run(["grim", str(path)], env=env, check=True, timeout=10)
        return path

    def wait_for(self, predicate, timeout: float = 5.0, interval: float = 0.05) -> Any:
        end = time.monotonic() + timeout
        while True:
            v = predicate()
            if v:
                return v
            if time.monotonic() > end:
                raise TimeoutError(f"waited {timeout} s for {getattr(predicate, '__name__', 'a condition')}")
            time.sleep(interval)


def real_signature() -> str:
    """The signature of the session the tests run in (to refuse it); raises when there is none,
    so the harness never runs blind."""
    sig = os.environ.get("APTUS_REAL_HYPRLAND_SIGNATURE") or os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    if not sig:
        raise RuntimeError("no Hyprland session signature: the nested harness runs only inside Hyprland")
    return sig


def lua_string(text: str) -> str:
    """A Lua string literal (decimal escapes for anything unusual)."""
    out = []
    for ch in text:
        if ch.isascii() and ch.isprintable() and ch not in '"\\':
            out.append(ch)
        else:
            out.extend(f"\\{b}" for b in ch.encode())
    return '"' + "".join(out) + '"'


def test_processes(home: Path) -> list[int]:
    """Processes whose environment has APTUS_TEST=1 and this HOME (only ever the test's own)."""
    want = (b"APTUS_TEST=1", b"HOME=" + str(home).encode())
    pids = []
    for d in os.listdir("/proc"):
        if not d.isdigit() or int(d) == os.getpid():
            continue
        try:
            env = open(f"/proc/{d}/environ", "rb").read().split(b"\0")
        except OSError:
            continue
        if all(w in env for w in want):
            pids.append(int(d))
    return pids


def write_test_png(path: Path, width: int = 480, height: int = 270) -> None:
    """A small warm gradient PNG (stdlib only) as the test wallpaper."""
    if path.exists():
        return
    rows = []
    for y in range(height):
        row = bytearray([0])
        for x in range(width):
            row += bytes((40 + x * 120 // width, 60 + y * 80 // height, 70))
        rows.append(bytes(row))
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(b"".join(rows), 6)) + chunk(b"IEND", b"")
    path.write_bytes(png)
