"""Hyprland IPC client against a fake socket."""
from __future__ import annotations

from pathlib import Path

import pytest

from aptus import hypr

# A fake Hyprland command socket lives in the temporary HOME: XDG_RUNTIME_DIR=<home>/r gives
# hypr_runtime <home>/r/hypr (short, for the 108-byte AF_UNIX limit).
SIG = "s1"
REAL = "aptus-unit-tests-real-session"


def test_request_roundtrip(test_home: Path, monkeypatch: pytest.MonkeyPatch, fake_hypr) -> None:
    monkeypatch.setenv("HYPRLAND_INSTANCE_SIGNATURE", SIG)
    seen = fake_hypr([b"Hyprland 0.57.1 " + b"x" * 70000])         # longer than one recv
    assert hypr.socket_path(hypr.get(), SIG) == test_home / "r" / "hypr" / SIG / ".socket.sock"
    answer = hypr.request("version")
    assert seen == [b"version"]
    assert answer.startswith("Hyprland 0.57.1") and len(answer) == 16 + 70000


def test_json_request(monkeypatch: pytest.MonkeyPatch, fake_hypr) -> None:
    monkeypatch.setenv("HYPRLAND_INSTANCE_SIGNATURE", SIG)
    seen = fake_hypr([b'[{"name": "eDP-1"}]', b"not json", b'["line 3: oops", ""]'])
    assert hypr.request_json("monitors") == [{"name": "eDP-1"}]
    with pytest.raises(hypr.HyprError):
        hypr.request_json("clients")
    assert hypr.config_errors() == ["line 3: oops"]
    assert seen == [b"j/monitors", b"j/clients", b"j/configerrors"]


def test_missing_socket_raises(test_home: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(test_home / "r"))
    with pytest.raises(hypr.HyprError):
        hypr.signature()                       # not inside Hyprland
    monkeypatch.setenv("HYPRLAND_INSTANCE_SIGNATURE", SIG)
    with pytest.raises(hypr.HyprError) as e:
        hypr.request("version")
    assert not isinstance(e.value, hypr.RefusedInstance)


def test_refuses_real_signature_in_tests(monkeypatch: pytest.MonkeyPatch, fake_hypr) -> None:
    monkeypatch.setenv("APTUS_REAL_HYPRLAND_SIGNATURE", "real")     # short: AF_UNIX path limit
    monkeypatch.setenv("HYPRLAND_INSTANCE_SIGNATURE", "real")
    seen = fake_hypr([], "real")                                      # listens, must never be connected to
    with pytest.raises(hypr.RefusedInstance):
        hypr.request("version")
    with pytest.raises(hypr.RefusedInstance):
        hypr.dispatch('hl.dsp.global("aptus:spotlight")')
    assert seen == []                                                # nothing ever connected
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


def test_explicit_sig_is_checked(monkeypatch: pytest.MonkeyPatch, fake_hypr) -> None:
    monkeypatch.setenv("HYPRLAND_INSTANCE_SIGNATURE", SIG)     # the environment is fine …
    seen = fake_hypr([b"ok"], "s2")
    with pytest.raises(hypr.RefusedInstance):
        hypr.request("version", sig=REAL)                       # … the explicit one is not
    with pytest.raises(hypr.RefusedInstance):
        hypr.notify("hello", sig=REAL)
    assert hypr.request("version", sig="s2") == "ok"
    assert seen == [b"version"]


def test_dispatch_sends_lua(monkeypatch: pytest.MonkeyPatch, fake_hypr) -> None:
    monkeypatch.setenv("HYPRLAND_INSTANCE_SIGNATURE", SIG)
    seen = fake_hypr([b"ok", b"ok", b"ok", b"error: unknown dispatcher"])
    hypr.dispatch('hl.dsp.global("aptus:spotlight")')
    hypr.eval_lua('hl.config({ general = { gaps_out = 6 } })')
    hypr.notify("aptus keeps crashing —\n see logs", 5000)
    with pytest.raises(hypr.HyprError):
        hypr.dispatch("hl.dsp.nothing()")
    assert seen[0] == b'dispatch hl.dsp.global("aptus:spotlight")'
    assert seen[1] == b"eval hl.config({ general = { gaps_out = 6 } })"
    assert seen[2] == "notify 0 5000 0 aptus keeps crashing — see logs".encode()
