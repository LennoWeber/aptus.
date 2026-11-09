"""Unit-test fixtures: every unit test runs with APTUS_TEST=1 and a temporary HOME (07 §13).
The e2e tests have their own conftest (they need the real session's signature to refuse it)."""
from __future__ import annotations

import os
import socket
import sys
import threading
from collections.abc import Callable, Iterator, Sequence
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "lib"))


def write_stub(directory: Path, name: str, script: str) -> Path:
    """Write an executable stub `name` with the given script into `directory`."""
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / name
    path.write_text(script)
    path.chmod(0o755)
    return path


@pytest.fixture
def stub_bin() -> Callable[[Path, str, str], Path]:
    """stub_bin(dir, name, script) -> Path of the written executable."""
    return write_stub


@pytest.fixture
def fake_hypr(test_home: Path, monkeypatch: pytest.MonkeyPatch) -> Iterator[Callable[..., list[bytes]]]:
    """fake_hypr(answers, sig="s1") -> seen: a fake Hyprland command socket for `sig` in the
    temporary HOME (XDG_RUNTIME_DIR=<home>/r keeps the path short for the AF_UNIX limit). It
    answers one connection per entry of `answers`; `seen` collects the requests."""
    from aptus import hypr, paths
    servers: list[tuple[socket.socket, threading.Thread]] = []

    def make(answers: Sequence[bytes], sig: str = "s1") -> list[bytes]:
        monkeypatch.setenv("XDG_RUNTIME_DIR", str(test_home / "r"))
        path = hypr.socket_path(paths.get(), sig)
        path.parent.mkdir(parents=True, exist_ok=True)
        server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        server.bind(str(path))
        server.listen()
        seen: list[bytes] = []

        def serve() -> None:
            for answer in answers:
                conn, _ = server.accept()
                with conn:
                    seen.append(conn.recv(4096))
                    conn.sendall(answer)

        t = threading.Thread(target=serve, daemon=True)
        t.start()
        servers.append((server, t))
        return seen

    yield make
    for server, t in servers:
        t.join(2)
        server.close()


@pytest.fixture(autouse=True)
def test_home(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """HOME → <tmp>/home, APTUS_TEST=1, XDG_* and the Hyprland signature removed, and a fake
    APTUS_REAL_HYPRLAND_SIGNATURE so hypr.check_allowed fails closed for anything real."""
    home = tmp_path / "home"
    home.mkdir()
    for name in list(os.environ):
        if name.startswith("XDG_"):
            monkeypatch.delenv(name)
    for name in ("HYPRLAND_INSTANCE_SIGNATURE", "WAYLAND_DISPLAY", "DISPLAY", "APTUS_DEV",
                 "APTUS_LOG", "INVOCATION_ID", "QS_CONFIG_PATH"):
        monkeypatch.delenv(name, raising=False)
    monkeypatch.setenv("HOME", str(home))
    monkeypatch.setenv("APTUS_TEST", "1")
    monkeypatch.setenv("APTUS_REAL_HYPRLAND_SIGNATURE", "aptus-unit-tests-real-session")
    # Safety net: tools that could reach the real session fail loudly if a test forgets a fake.
    guard = tmp_path / "guard-bin"
    guard.mkdir()
    for tool in ("qs", "hyprctl", "hyprlock", "systemctl", "systemd-run", "systemd-cat"):
        write_stub(guard, tool, f"#!/bin/sh\necho 'unit tests: {tool} is blocked' >&2\nexit 99\n")
    monkeypatch.setenv("PATH", f"{guard}{os.pathsep}{os.environ.get('PATH', '/usr/bin')}")
    return home
