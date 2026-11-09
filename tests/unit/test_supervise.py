"""Restart policy of 07 §10."""
from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from aptus import hypr, supervise
from aptus.paths import get
from aptus.supervise import CrashLog, RestartPolicy

POLICY = RestartPolicy()


def crash_at(crashes: CrashLog, times: list[float], policy: RestartPolicy = POLICY) -> list[float]:
    """Crashes at the given times, each restart `delay` after its crash (as run() does)."""
    out = []
    for t in times:
        delay, _ = supervise.next_delay(policy, crashes, t)
        out.append(delay)
        crashes.started = t + delay
    return out


def test_delays_grow() -> None:
    assert POLICY.delays == (0.5, 1.0, 2.0)
    # 07 §10: crashes at 0, 6 and 12 s wait 0.5, 1 and 2 s (the streak, not the window count) …
    assert crash_at(CrashLog(times=[], started=-1), [0, 6, 12]) == [0.5, 1.0, 2.0]
    # … and a run of ≥ 10 s starts a new streak.
    assert crash_at(CrashLog(times=[], started=-1), [0, 12, 24]) == [0.5, 0.5, 0.5]
    assert crash_at(CrashLog(times=[], started=-1), [0, 6, 19, 25]) == [0.5, 1.0, 0.5, 1.0]


def test_crash_limit_slow_retry() -> None:
    crashes = CrashLog(times=[], started=-1)
    assert crash_at(crashes, [0, 1, 2.5]) == [0.5, 1.0, 30.0]
    crashes = CrashLog(times=[], started=-1)
    flags = []
    for t in (0, 1, 2.5, 33, 34):
        flags.append(supervise.next_delay(POLICY, crashes, t)[1])
        crashes.started = t + 0.1
    assert flags == [False, False, True, False, False]   # the lock fallback and the notice fire once


def test_slow_retry_stays_until_a_long_run() -> None:
    """07 §10: after three crashes within 10 s, every restart waits 30 s, and the lock fallback and
    the notice fire once; a run of ≥ 10 s starts over."""
    crashes = CrashLog(times=[], started=-1)
    delays, flags, t = [], [], 0.0
    for _ in range(9):
        t = crashes.started + 0.2                  # each run crashes 0.2 s after its start
        delay, switched = supervise.next_delay(POLICY, crashes, t)
        delays.append(delay)
        flags.append(switched)
        crashes.started = t + delays[-1]
    assert delays == [0.5, 1.0, 30.0, 30.0, 30.0, 30.0, 30.0, 30.0, 30.0]
    assert flags == [False, False, True] + [False] * 6
    t = crashes.started + 15                       # a long run: fast again
    assert supervise.next_delay(POLICY, crashes, t) == (0.5, False)


def test_old_crashes_forgotten() -> None:
    crashes = CrashLog(times=[], started=-1)
    crash_at(crashes, [0, 1])
    assert crash_at(crashes, [30]) == [0.5]                  # the first two aged out, the run was long
    assert crashes.times == [30]


def test_policy_rejects_nonsense() -> None:
    """The supervise invariants: no policy that could spin, no crash before its run started."""
    for bad in (dict(delays=()), dict(delays=(0.5, 0)), dict(crash_window=0), dict(crash_limit=0),
                dict(slow_retry=-1)):
        with pytest.raises(ValueError, match="supervise invariant: bad restart policy"):
            RestartPolicy(**bad)
    with pytest.raises(ValueError, match="supervise invariant: negative streak"):
        supervise.next_delay(POLICY, CrashLog(times=[], streak=-1), 5)
    with pytest.raises(ValueError, match="crash before the run started"):
        supervise.next_delay(POLICY, CrashLog(times=[], started=10), 5)


def run_script(script: str, policy: RestartPolicy = RestartPolicy((0.01, 0.01, 0.01), 10, 3, 0.01)
               ) -> list[str]:
    """Run `sh -c script` under the supervisor; returns the lines the script appended to $LOG."""
    home = get().home
    log = home / "runs.log"
    env_script = f'LOG="{log}"; {script}'
    assert supervise.run(get(), policy, ["sh", "-c", env_script]) == 0
    return log.read_text().splitlines() if log.exists() else []


def test_restart_flag_restarts_at_once(monkeypatch: pytest.MonkeyPatch) -> None:
    p = get()
    # First run asks for a restart (flag + exit 0), the second exits 0 without the flag.
    script = (f'echo run >> "$LOG"; if [ "$(wc -l < "$LOG")" -eq 1 ]; then '
              f'touch "{p.restart_flag}"; fi; exit 0')
    # A slow retry of 60 s would hang the test if the restart was treated as a crash.
    lines = run_script(script, RestartPolicy((60.0,), 10, 3, 60.0))
    assert lines == ["run", "run"]
    assert not p.restart_flag.exists()


def test_exit_zero_ends() -> None:
    assert run_script('echo run >> "$LOG"; exit 0') == ["run"]


def test_crash_limit_locks_when_marker(monkeypatch: pytest.MonkeyPatch) -> None:
    p = get()
    popen: list[list[str]] = []
    notes: list[tuple] = []
    real_popen = subprocess.Popen

    def fake_popen(cmd, *a, **kw):             # type: ignore[no-untyped-def]
        if cmd[0] == "hyprlock":
            popen.append(list(cmd))
            return None
        return real_popen(cmd, *a, **kw)

    monkeypatch.setattr(subprocess, "Popen", fake_popen)
    monkeypatch.setattr(hypr, "notify", lambda *a, **kw: notes.append(a))
    p.locked_marker.parent.mkdir(parents=True)
    p.locked_marker.touch()
    # Crash three times quickly, then exit cleanly.
    script = ('echo run >> "$LOG"; if [ "$(wc -l < "$LOG")" -le 3 ]; then exit 1; fi; exit 0')
    lines = run_script(script)
    assert len(lines) == 4
    assert popen == [["hyprlock"]]              # no aptus hyprlock.conf yet: plain hyprlock
    assert len(notes) == 1 and "keeps crashing" in notes[0][0]


def test_crash_limit_without_marker_only_notifies(monkeypatch: pytest.MonkeyPatch) -> None:
    started: list = []
    notes: list = []
    real_popen = subprocess.Popen
    monkeypatch.setattr(subprocess, "Popen",
                        lambda cmd, *a, **kw: started.append(cmd) if cmd[0] == "hyprlock"
                        else real_popen(cmd, *a, **kw))
    monkeypatch.setattr(hypr, "notify", lambda *a, **kw: notes.append(a))
    script = ('echo run >> "$LOG"; if [ "$(wc -l < "$LOG")" -le 3 ]; then exit 1; fi; exit 0')
    run_script(script)
    assert started == [] and len(notes) == 1


def test_command_and_env(test_home: Path) -> None:
    p = get()
    assert supervise.shell_command(p) == ["qs", "-p", str(p.shell), "--no-duplicate"]
    assert "APTUS_DEV" not in supervise.shell_env(p, {"APTUS_DEV": "1", "A": "b"})
    p.dev_flag.parent.mkdir(parents=True)
    p.dev_flag.touch()
    assert supervise.shell_env(p, {"A": "b"}) == {"A": "b", "APTUS_DEV": "1"}
