"""Hyprland IPC client against a fake socket."""
from __future__ import annotations

import socket
import threading
from pathlib import Path

import pytest

from aptus import hypr

# A fake Hyprland command socket lives in the temporary HOME: XDG_RUNTIME_DIR=<home>/r gives
# hypr_runtime <home>/r/hypr (short, for the 108-byte AF_UNIX limit).
SIG = "s1"
REAL = "aptus-unit-tests-real-session"


def test_request_roundtrip(test_home: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(test_home / "r"))
    monkeypatch.setenv("HYPRLAND_INSTANCE_SIGNATURE", SIG)
    path = test_home / "r" / "hypr" / SIG / ".socket.sock"
    path.parent.mkdir(parents=True)
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(str(path))
    server.listen()
    seen: list[bytes] = []

    def serve() -> None:
        conn, _ = server.accept()
        with conn:
            seen.append(conn.recv(4096))
            conn.sendall(b"Hyprland 0.57.1 " + b"x" * 70000)   # longer than one recv

    t = threading.Thread(target=serve)
    t.start()
    assert hypr.socket_path(hypr.get(), SIG) == path
    answer = hypr.request("version")
    t.join(2)
    server.close()
    assert seen == [b"version"]
    assert answer.startswith("Hyprland 0.57.1") and len(answer) == 16 + 70000


def test_json_request(test_home: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(test_home / "r"))
    monkeypatch.setenv("HYPRLAND_INSTANCE_SIGNATURE", SIG)
    path = test_home / "r" / "hypr" / SIG / ".socket.sock"
    path.parent.mkdir(parents=True)
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(str(path))
    server.listen()
    answers = [b'[{"name": "eDP-1"}]', b"not json", b'["line 3: oops", ""]']
    seen: list[bytes] = []

    def serve() -> None:
        for answer in answers:
            conn, _ = server.accept()
            with conn:
                seen.append(conn.recv(4096))
                conn.sendall(answer)

    t = threading.Thread(target=serve)
    t.start()
    assert hypr.request_json("monitors") == [{"name": "eDP-1"}]
    with pytest.raises(hypr.HyprError):
        hypr.request_json("clients")
    assert hypr.config_errors() == ["line 3: oops"]
    t.join(2)
    server.close()
    assert seen == [b"j/monitors", b"j/clients", b"j/configerrors"]


def test_missing_socket_raises(test_home: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(test_home / "r"))
    with pytest.raises(hypr.HyprError):
        hypr.signature()                       # not inside Hyprland
    monkeypatch.setenv("HYPRLAND_INSTANCE_SIGNATURE", SIG)
    with pytest.raises(hypr.HyprError) as e:
        hypr.request("version")
    assert not isinstance(e.value, hypr.RefusedInstance)


def test_refuses_real_signature_in_tests(test_home: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(test_home / "r"))
    monkeypatch.setenv("APTUS_REAL_HYPRLAND_SIGNATURE", "real")     # short: AF_UNIX path limit
    monkeypatch.setenv("HYPRLAND_INSTANCE_SIGNATURE", "real")
    path = test_home / "r" / "hypr" / "real" / ".socket.sock"
    path.parent.mkdir(parents=True)
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(str(path))
    server.listen()
    server.settimeout(0.2)
    with pytest.raises(hypr.RefusedInstance):
        hypr.request("version")
    with pytest.raises(hypr.RefusedInstance):
        hypr.dispatch('hl.dsp.global("aptus:spotlight")')
    with pytest.raises(TimeoutError):
        server.accept()                        # nothing ever connected
    server.close()
    # Outside tests the check is a no-op.
    hypr.check_allowed(REAL, {"APTUS_REAL_HYPRLAND_SIGNATURE": REAL})


def test_refuses_when_real_signature_unknown(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("APTUS_REAL_HYPRLAND_SIGNATURE")
    with pytest.raises(hypr.RefusedInstance):
        hypr.check_allowed(SIG)
    with pytest.raises(hypr.RefusedInstance):
        hypr.request("version", sig=SIG)
    monkeypatch.setenv("APTUS_REAL_HYPRLAND_SIGNATURE", "")
    with pytest.raises(hypr.RefusedInstance):
        hypr.request("version", sig=SIG)


def test_explicit_sig_is_checked(test_home: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(test_home / "r"))
    monkeypatch.setenv("HYPRLAND_INSTANCE_SIGNATURE", SIG)     # the environment is fine …
    with pytest.raises(hypr.RefusedInstance):
        hypr.request("version", sig=REAL)                       # … the explicit one is not
    with pytest.raises(hypr.RefusedInstance):
        hypr.notify("hello", sig=REAL)
    path = test_home / "r" / "hypr" / "s2" / ".socket.sock"
    path.parent.mkdir(parents=True)
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(str(path))
    server.listen()
    seen: list[bytes] = []

    def serve() -> None:
        conn, _ = server.accept()
        with conn:
            seen.append(conn.recv(4096))
            conn.sendall(b"ok")

    t = threading.Thread(target=serve)
    t.start()
    assert hypr.request("version", sig="s2") == "ok"
    t.join(2)
    server.close()
    assert seen == [b"version"]


def test_dispatch_sends_lua(test_home: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(test_home / "r"))
    monkeypatch.setenv("HYPRLAND_INSTANCE_SIGNATURE", SIG)
    path = test_home / "r" / "hypr" / SIG / ".socket.sock"
    path.parent.mkdir(parents=True)
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(str(path))
    server.listen()
    answers = [b"ok", b"ok", b"ok", b"error: unknown dispatcher"]
    seen: list[bytes] = []

    def serve() -> None:
        for answer in answers:
            conn, _ = server.accept()
            with conn:
                seen.append(conn.recv(4096))
                conn.sendall(answer)

    t = threading.Thread(target=serve)
    t.start()
    hypr.dispatch('hl.dsp.global("aptus:spotlight")')
    hypr.eval_lua('hl.config({ general = { gaps_out = 6 } })')
    hypr.notify("aptus keeps crashing —\n see logs", 5000)
    with pytest.raises(hypr.HyprError):
        hypr.dispatch("hl.dsp.nothing()")
    t.join(2)
    server.close()
    assert seen[0] == b'dispatch hl.dsp.global("aptus:spotlight")'
    assert seen[1] == b"eval hl.config({ general = { gaps_out = 6 } })"
    assert seen[2] == "notify 0 5000 0 aptus keeps crashing — see logs".encode()
