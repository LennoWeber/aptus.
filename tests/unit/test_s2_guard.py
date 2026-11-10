"""aptus-guard's parts (02 §7): the wait, logind's record, the environment it unsets, its state
file and its refusals. The whole guard runs in test_s2_session.py."""
from __future__ import annotations

import json
import os
import subprocess
import time
from pathlib import Path

import pytest

import s2_fakes as fakes
from aptus import paths as paths_mod
from aptus.lease import guard, ops
from aptus.lease.journal import SlotKind
from aptus.lease.slots import SlotSpec


@pytest.fixture
def p(test_home: Path, monkeypatch: pytest.MonkeyPatch) -> paths_mod.Paths:
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(test_home / "r"))
    (test_home / "r").mkdir()
    return paths_mod.get()


@pytest.fixture
def hypr(p, test_home, tmp_path):
    h = fakes.hyprland(test_home, tmp_path)
    yield h
    h.kill()


def test_wait_exit_stop_and_poll() -> None:
    child = subprocess.Popen(["sleep", "0.2"])
    fd = guard.pidfd(child.pid)
    r, w = os.pipe()
    try:
        assert guard.wait(fd, r, 0.05, lambda: False) == "exited"
        child.wait()
        live = subprocess.Popen(["sleep", "30"])
        fd2 = guard.pidfd(live.pid)
        os.write(w, b"\x0f")
        assert guard.wait(fd2, r, 0.05, lambda: False) == "stopped"
        calls = []
        assert guard.wait(fd2, r, 0.01, lambda: calls.append(1) or len(calls) > 2) == "other-session"
        live.kill()
        live.wait()
        os.close(fd2)
    finally:
        os.close(fd)
        os.close(r)
        os.close(w)
    gone = subprocess.Popen(["true"])
    gone.wait()                                    # reaped: the pid no longer exists
    with pytest.raises(ProcessLookupError):
        guard.pidfd(gone.pid)


def test_write_state(p) -> None:
    guard.write_state(p, guard.GuardState.SCOPE_ONLY, "why")
    assert p.guard_state.read_text() == "scope-only\nwhy\n"


def test_unset_only_aptus_values(p) -> None:
    fakes.systemctl(p.home)
    (p.home / ".aptus-test/systemctl.json").write_text(json.dumps({"env": {
        "APTUS_SESSION": "1", "QT_QPA_PLATFORMTHEME": "gtk3", "XCURSOR_THEME": "Adwaita",
        "XCURSOR_SIZE": "24", "HYPRCURSOR_SIZE": "24", "PATH": "/usr/bin"}}))
    assert guard.unset_environment(p) == ["APTUS_SESSION", "XCURSOR_THEME", "HYPRCURSOR_SIZE"]
    assert fakes.user_env(p.home) == {"QT_QPA_PLATFORMTHEME": "gtk3", "XCURSOR_SIZE": "24",
                                      "PATH": "/usr/bin"}          # someone else's value stays
    assert guard.unset_environment(p) == []


def take(p, hypr) -> None:
    fakes.one_session(p.home)
    f = p.config_home / "gtk-3.0/noctalia.css"
    f.parent.mkdir(parents=True)
    f.write_text("noctalia\n")
    spec = SlotSpec(id="gtk3.artifact", kind=SlotKind.FILE, target="gtk3", path=f, content=b"aptus\n")
    assert ops.take(p, hypr.env, [spec], ops.owner(p, hypr.env), 1).held


def test_other_session_needs_a_change_and_the_lease(p, hypr) -> None:
    last: list = [None]
    assert not guard.other_session_opened(p, hypr.signature, hypr.pid, last)   # no record yet
    take(p, hypr)
    p.logind_user.parent.mkdir(parents=True)
    p.logind_user.write_text("1")
    assert not guard.other_session_opened(p, hypr.signature, hypr.pid, last)   # only this one
    fakes.one_session(p.home, "2", {"Id": "7", "Class": "user", "Type": "wayland", "State": "online"})
    assert not guard.other_session_opened(p, hypr.signature, hypr.pid, last)   # record unchanged
    p.logind_user.write_text("2")
    os.utime(p.logind_user, (time.time() + 5, time.time() + 5))
    assert not guard.other_session_opened(p, hypr.signature, hypr.pid + 1, [None])  # not our lease
    assert guard.other_session_opened(p, hypr.signature, hypr.pid, last)


def test_failing_loginctl_keeps_the_lease(p, hypr) -> None:
    take(p, hypr)
    fakes.tool(p.home, "loginctl", "code = 1\n")
    p.logind_user.parent.mkdir(parents=True)
    p.logind_user.write_text("x")
    assert not guard.other_session_opened(p, hypr.signature, hypr.pid, [None])


def test_release_if_ours(p, hypr) -> None:
    take(p, hypr)
    assert not guard.release_if_ours(p, hypr.pid + 1, hypr.signature).acted
    assert not guard.release_if_ours(p, hypr.pid, "other").acted
    assert guard.release_if_ours(p, hypr.pid, hypr.signature).acted


def test_main_refusals(p) -> None:
    assert guard.main([]) == 2
    assert guard.main(["x", "sig"]) == 2
    assert guard.main([str(os.getpid()), os.environ["APTUS_REAL_HYPRLAND_SIGNATURE"]]) == 3
