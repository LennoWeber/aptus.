"""S3 acceptance, notifications (notch.md §6, 05 §8) with notify-send on the nested session's
private bus: arrival rules, timing, critical, replaces-id, stack, history; Ipc `notch toast`."""
from __future__ import annotations

import pytest


def test_aptus_owns_the_notification_name(nested) -> None:
    pytest.skip("phase 7")


def test_normal_toast_and_history(nested) -> None:
    pytest.skip("phase 7")


def test_low_urgency_goes_to_today_only(nested) -> None:
    pytest.skip("phase 7")


def test_critical_has_no_timeout(nested) -> None:
    pytest.skip("phase 7")


def test_replaces_id_updates_in_place(nested) -> None:
    pytest.skip("phase 7")


def test_burst_becomes_one_stack_toast(nested) -> None:
    pytest.skip("phase 7")


def test_ipc_notch_toast(nested) -> None:
    pytest.skip("phase 7")


def test_held_under_dnd_then_summary(nested) -> None:
    pytest.skip("phase 7")


def test_sender_close_removes_the_toast(nested) -> None:
    pytest.skip("phase 7")


def test_toast_ways_out(nested) -> None:
    pytest.skip("phase 7")
