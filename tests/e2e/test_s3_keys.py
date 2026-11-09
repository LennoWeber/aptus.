"""S3 acceptance, keys (11 §3, 05 §6 hardware keys and media): every key does what it says and
shows the OSD. Volume and mute act on the Audio test double (never PipeWire), brightness and the
keyboard light on the fake sysfs tree (tests/e2e/fakehw.py), media on the fake MPRIS player
(tests/e2e/fake_mpris.py) on the nested bus. Shortcuts are dispatched with hl.dsp.global (virtual
keyboards cannot fire binds, probes.md)."""
from __future__ import annotations

import pytest


def test_volume_keys_step_and_show_the_osd(nested) -> None:
    pytest.skip("phase 7")


def test_mute_and_mic_mute(nested) -> None:
    pytest.skip("phase 7")


def test_brightness_keys_on_the_fake_backlight(nested) -> None:
    pytest.skip("phase 7")


def test_keyboard_light(nested) -> None:
    pytest.skip("phase 7")


def test_caps_lock_osd(nested) -> None:
    pytest.skip("phase 7")


def test_media_keys_act_on_the_fake_player(nested) -> None:
    pytest.skip("phase 7")


def test_nothing_to_play(nested) -> None:
    pytest.skip("phase 7")
