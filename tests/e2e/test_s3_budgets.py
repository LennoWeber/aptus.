"""S3 budgets (07 §12) measured in the nested session: shell RSS, idle CPU and wakeups, frame times
of the notch under a toast burst and an OSD burst. Reported in PHASES.md; the test fails only
beyond the budget."""
from __future__ import annotations

import pytest


def test_idle_rss_cpu_and_wakeups(nested) -> None:
    pytest.skip("phase 7")


def test_frame_times_under_toasts_and_osd(nested) -> None:
    pytest.skip("phase 7")
