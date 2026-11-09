"""S3 acceptance, multi-monitor: a headless output added and removed in the nested session with a
toast and a card open; no crash, surfaces on the removed monitor close, the strips follow
auto-workspace-monitors.sh (05 §7)."""
from __future__ import annotations

import pytest


def test_add_and_remove_an_output_with_surfaces_open(nested) -> None:
    pytest.skip("phase 7")
