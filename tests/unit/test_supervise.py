"""Restart policy of 07 §10."""
from __future__ import annotations



def test_delays_grow() -> None:
    raise NotImplementedError


def test_crash_limit_slow_retry() -> None:
    raise NotImplementedError


def test_old_crashes_forgotten() -> None:
    raise NotImplementedError


def test_restart_flag_restarts_at_once() -> None:
    raise NotImplementedError


def test_exit_zero_ends() -> None:
    raise NotImplementedError


def test_crash_limit_locks_when_marker() -> None:
    raise NotImplementedError


def test_crash_limit_without_marker_only_notifies() -> None:
    raise NotImplementedError


def test_command_and_env() -> None:
    raise NotImplementedError


def test_policy_rejects_nonsense() -> None:
    import pytest
    from aptus.supervise import RestartPolicy
    RestartPolicy()
    for bad in (dict(delays=()), dict(delays=(0.5, 0.0)), dict(crash_limit=0), dict(crash_window=0),
                dict(slow_retry=-1)):
        with pytest.raises(ValueError, match="supervise invariant"):
            RestartPolicy(**bad)

