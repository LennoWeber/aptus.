"""aptus-session start/stop without any fake tools: scope-only (no guard, so no lease), nothing
reaches a user manager. The lease path with fakes is in test_s2_session.py."""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest

from aptus import session
from aptus.lease import preflight
from aptus.paths import get

HYPR_ENV = {"XDG_CURRENT_DESKTOP": "Hyprland", "HYPRLAND_INSTANCE_SIGNATURE": "sig1"}


@pytest.fixture
def no_exec(monkeypatch: pytest.MonkeyPatch) -> list[object]:
    calls: list[object] = []
    monkeypatch.setattr(session, "exec_supervisor", lambda paths: calls.append(paths))
    return calls


@pytest.fixture
def forbidden(monkeypatch: pytest.MonkeyPatch) -> list[list[str]]:
    """Any subprocess in session.start would be a bug: record and fail."""
    seen: list[list[str]] = []

    def boom(cmd, *a, **kw):                    # type: ignore[no-untyped-def]
        seen.append(list(cmd))
        raise AssertionError(f"unexpected subprocess {cmd}")

    for name in ("run", "Popen", "check_call", "check_output", "call"):
        monkeypatch.setattr(subprocess, name, boom)
    return seen


def test_not_hyprland_exits_zero(monkeypatch: pytest.MonkeyPatch, no_exec: list,
                                 forbidden: list) -> None:
    assert session.check_environment({"XDG_CURRENT_DESKTOP": "KDE"}) is not None
    assert session.check_environment({}) is not None
    assert session.check_environment({"XDG_CURRENT_DESKTOP": "Hyprland"}) is not None  # no signature
    assert session.check_environment(HYPR_ENV) is None
    assert session.check_environment({**HYPR_ENV, "XDG_CURRENT_DESKTOP": "sway:Hyprland"}) is None
    monkeypatch.setenv("XDG_CURRENT_DESKTOP", "Umbriel")
    assert session.main(["start"]) == 0
    assert no_exec == [] and not get().session_status.exists()    # nothing touched
    assert session.main(["bogus"]) == 2


def test_scope_only_report(forbidden: list) -> None:
    report = session.start(get(), {**HYPR_ENV, "APTUS_TEST": "1"})
    assert report.mode is session.Mode.SCOPE_ONLY
    assert report.reasons == ["the guard did not start"]
    assert report.notice == preflight.NOTICE_FAILED
    assert report.generation == 1 and not report.guard
    assert report.warnings == []
    assert forbidden == []


def test_test_mode_skips_units_and_env(forbidden: list, test_home: Path,
                                       monkeypatch: pytest.MonkeyPatch) -> None:
    import os
    before = dict(os.environ)
    report = session.start(get(), {**HYPR_ENV, "APTUS_TEST": "1"})
    assert not report.guard
    assert forbidden == []                       # no systemctl, systemd-run, import-environment
    assert dict(os.environ) == before
    assert not get().systemd_user.exists()       # no units written
    assert get().runtime.is_dir() and str(get().runtime).startswith(str(test_home))


def test_status_written(no_exec: list, monkeypatch: pytest.MonkeyPatch) -> None:
    for k, v in HYPR_ENV.items():
        monkeypatch.setenv(k, v)
    assert session.main(["start"]) == 1          # exec_supervisor "returned": reported as failure
    assert len(no_exec) == 1
    data = json.loads(get().session_status.read_text())
    assert data["mode"] == "scope-only" and data["signature"] == "sig1"
    assert data["test"] is True and data["reasons"] == ["the guard did not start"]
    assert data["warnings"] == [] and data["generation"] == 1 and data["guard"] is False
    assert data["notice"] == preflight.NOTICE_FAILED
    assert get().runtime.stat().st_mode & 0o777 == 0o700


def test_stop_is_noop(forbidden: list, test_home: Path) -> None:
    before = sorted(p for p in test_home.rglob("*"))
    assert session.main(["stop"]) == 0
    assert forbidden == []
    after = sorted(p for p in test_home.rglob("*") if not p.name.startswith("aptus-"))
    assert after == [p for p in before if not p.name.startswith("aptus-")]
