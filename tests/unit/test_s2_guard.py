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
from aptus.lease import guard, journal, ops
from aptus.lease.journal import SlotKind
from aptus.lease.slots import SlotSpec
from aptus.theme import hooks


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
    fd = os.pidfd_open(child.pid)
    r, w = os.pipe()
    try:
        assert guard.wait(fd, r, 0.05, lambda: False) == "exited"
        child.wait()
        live = subprocess.Popen(["sleep", "30"])
        fd2 = os.pidfd_open(live.pid)
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
        os.pidfd_open(gone.pid)


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


def take(p, hypr, reload: str = "none") -> None:
    fakes.one_session(p.home)
    f = p.config_home / "gtk-3.0/noctalia.css"
    f.parent.mkdir(parents=True)
    f.write_text("noctalia\n")
    spec = SlotSpec(id="gtk3.artifact", kind=SlotKind.FILE, target="gtk3", path=f, content=b"aptus\n",
                    reload=reload)
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


def test_release_only_of_this_owner(p, hypr) -> None:
    """The guard's release: ops.release with `expect` acts only on this session's journal."""
    take(p, hypr)
    assert not ops.release(p, expect=(hypr.signature, hypr.pid + 1)).acted
    assert not ops.release(p, expect=("other", hypr.pid)).acted
    assert ops.release(p, expect=(hypr.signature, hypr.pid)).acted


def test_main_refusals(p) -> None:
    assert guard.main([]) == 2
    assert guard.main(["x", "sig"]) == 2
    assert guard.main([str(os.getpid()), os.environ["APTUS_REAL_HYPRLAND_SIGNATURE"]]) == 3


# --- the phase-7 review fixes ------------------------------------------------------------------

def aptus_env(p) -> None:
    fakes.systemctl(p.home)
    (p.home / ".aptus-test/systemctl.json").write_text(json.dumps({"env": {
        "APTUS_SESSION": "1", "QT_QPA_PLATFORMTHEME": "qt6ct", "XCURSOR_SIZE": "24"}}))


def test_a_failed_slot_still_unsets_the_environment(p) -> None:
    aptus_env(p)
    report = ops.ReleaseReport(acted=True, failed={"gtk3.artifact": "busy"})
    assert guard.after_release(p, report, "") == guard.GuardState.FAILED
    assert fakes.user_env(p.home) == {"XCURSOR_SIZE": "24"}


def test_give_back_unsets_first_and_retries_a_release_that_raised(p, hypr, monkeypatch) -> None:
    take(p, hypr)
    aptus_env(p)
    monkeypatch.setattr(guard, "BACKOFF", 0)
    real = ops.release
    calls = []

    def flaky(*args, **kw):
        calls.append(fakes.user_env(p.home))
        if len(calls) == 1:
            raise ops.LeaseError("the lease lock is busy")
        return real(*args, **kw)
    monkeypatch.setattr(ops, "release", flaky)
    assert guard.give_back(p, hypr.pid, hypr.signature) == guard.GuardState.RELEASED
    assert calls[0] == {"XCURSOR_SIZE": "24"}            # unset before the first attempt
    assert len(calls) == 2 and journal.load(p) is None


def test_a_failure_after_the_release_still_runs_the_hooks(p, hypr, monkeypatch) -> None:
    """Wave-2 review 6: a step after ops.release that raises (here the environment unset) does not
    retry the release, which would find no journal and skip the hooks: the release ran once and
    its hooks ran with the journal's reloads."""
    take(p, hypr, reload="builtin:tmux")
    aptus_env(p)
    monkeypatch.setattr(guard, "BACKOFF", 0)
    real_unset, real_release = guard.unset_environment, ops.release
    unsets, releases, reloads = [], [], []

    def unset(paths):
        unsets.append(1)
        if len(unsets) == 2:                              # the one after the release
            raise OSError("systemctl hung up")
        return real_unset(paths)
    monkeypatch.setattr(guard, "unset_environment", unset)
    monkeypatch.setattr(ops, "release", lambda *a, **kw: releases.append(1) or real_release(*a, **kw))
    monkeypatch.setattr(hooks, "run_reloads", lambda paths, r, sig: reloads.append(dict(r)) or [])
    assert guard.give_back(p, hypr.pid, hypr.signature) == guard.GuardState.RELEASED
    assert len(releases) == 1 and journal.load(p) is None
    assert reloads == [{"gtk3": "builtin:tmux"}]


def test_give_back_gives_up_after_its_retries(p, hypr, monkeypatch) -> None:
    take(p, hypr)
    monkeypatch.setattr(guard, "BACKOFF", 0)
    calls = []
    monkeypatch.setattr(ops, "release",
                        lambda *a, **kw: calls.append(1) or (_ for _ in ()).throw(OSError("disk full")))
    assert guard.give_back(p, hypr.pid, hypr.signature) == guard.GuardState.FAILED
    assert len(calls) == guard.RETRIES and journal.load(p) is not None


def test_a_change_before_the_take_is_checked_again_once_held(p, hypr) -> None:
    """Umbriel opens between preflight and the take: the change seen while nothing was held is
    not used up."""
    last: list = [None]
    fakes.one_session(p.home, "2", {"Id": "7", "Class": "user", "Type": "wayland", "State": "online"})
    p.logind_user.parent.mkdir(parents=True)
    p.logind_user.write_text("2 7")
    assert not guard.other_session_opened(p, hypr.signature, hypr.pid, last)   # nothing held
    fakes.one_session(p.home)
    take(p, hypr)
    fakes.one_session(p.home, "2", {"Id": "7", "Class": "user", "Type": "wayland", "State": "online"})
    assert guard.other_session_opened(p, hypr.signature, hypr.pid, last)       # same record


def test_a_failing_loginctl_is_asked_again(p, hypr) -> None:
    take(p, hypr)
    p.logind_user.parent.mkdir(parents=True)
    p.logind_user.write_text("2 7")
    fakes.tool(p.home, "loginctl", "code = 1\n")
    last: list = [None]
    assert not guard.other_session_opened(p, hypr.signature, hypr.pid, last)
    fakes.one_session(p.home, "2", {"Id": "7", "Class": "user", "Type": "wayland", "State": "online"})
    assert guard.other_session_opened(p, hypr.signature, hypr.pid, last)       # no new change needed


def test_ready_needs_ok_and_an_active_unit(p) -> None:
    fakes.systemctl(p.home)
    assert not guard.ready(p)                                  # no guard.state
    guard.write_state(p, guard.GuardState.OK)
    assert not guard.ready(p)                                  # the unit does not run
    unit = subprocess.Popen(["sleep", "30"])
    try:
        (p.home / ".aptus-test/systemd-run.json").write_text(json.dumps({"units": {"aptus-guard": unit.pid}}))
        assert guard.ready(p)
        guard.write_state(p, guard.GuardState.RELEASED)
        assert not guard.ready(p)
    finally:
        unit.kill()
        unit.wait(5)
