"""S3 acceptance, keys (11 §3, 05 §6 hardware keys and media): every key does what it says and
shows the OSD. Volume and mute act on the Audio test double (never PipeWire), brightness and the
keyboard light on the fake sysfs tree (tests/e2e/fakehw.py), media on the fake MPRIS player
(tests/e2e/fake_mpris.py) on the nested bus. Shortcuts are dispatched with hl.dsp.global (virtual
keyboards cannot fire binds, probes.md)."""
from __future__ import annotations

import pytest

from nested import Nested
from s3bus import FakePlayer, settle


def active(nested: Nested) -> dict:
    st = nested.state()
    return st["monitors"][st["global"]["activeMonitor"]]


def osd(nested: Nested, kind: str) -> dict | None:
    return next((e for e in active(nested)["passive"] if e["kind"] == "osd" and e["key"] == kind), None)


def svc(nested: Nested, name: str) -> dict:
    return nested.state()["services"][name]


@pytest.fixture(autouse=True)
def no_osd(nested: Nested):
    """Every test starts without an OSD or event on screen (an OSD fades 1.2 s after its last
    change, an event 1.6 s after it shows)."""
    nested.wait_for(lambda: not any(e["kind"] in ("osd", "event") for e in active(nested)["passive"]), 8)
    yield


def test_volume_keys_step_and_show_the_osd(nested: Nested) -> None:
    a = svc(nested, "audio")
    assert a["available"] and a["testDouble"]
    v0 = a["volume"]
    nested.shortcut("vol-up")
    nested.wait_for(lambda: osd(nested, "volume"), 3)
    v1 = nested.wait_for(lambda: svc(nested, "audio")["volume"] > v0 and svc(nested, "audio")["volume"], 3)
    assert round(v1 * 100) % 5 == 0                     # snaps to the 5 % grid
    nested.shortcut("vol-down-fine")
    nested.wait_for(lambda: abs(svc(nested, "audio")["volume"] - (v1 - 0.01)) < 1e-6, 3)
    nested.shortcut("vol-down")
    nested.wait_for(lambda: svc(nested, "audio")["volume"] < v1 - 0.01, 3)


def test_mute_and_mic_mute(nested: Nested) -> None:
    nested.shortcut("mute")
    nested.wait_for(lambda: svc(nested, "audio")["muted"], 3)
    assert osd(nested, "volume")
    nested.shortcut("mute")
    nested.wait_for(lambda: not svc(nested, "audio")["muted"], 3)
    nested.shortcut("mic-mute")
    nested.wait_for(lambda: svc(nested, "audio")["micMuted"], 3)
    nested.wait_for(lambda: osd(nested, "mic"), 3)
    nested.shortcut("mic-mute")
    nested.wait_for(lambda: not svc(nested, "audio")["micMuted"], 3)


def test_brightness_keys_on_the_fake_backlight(nested: Nested) -> None:
    hw = nested.hw
    b = nested.wait_for(lambda: svc(nested, "brightness")["hasBacklight"] and svc(nested, "brightness"), 5)
    assert b["device"] == hw.backlight
    raw0 = hw.backlight_value()
    nested.shortcut("bright-up")
    nested.wait_for(lambda: hw.backlight_value() > raw0, 3)
    assert hw.backlight_value() * 100 // hw.backlight_max % 5 == 0
    nested.wait_for(lambda: osd(nested, "brightness"), 3)
    nested.shortcut("bright-down-fine")
    up = hw.backlight_value()
    nested.wait_for(lambda: hw.backlight_value() == up - hw.backlight_max // 100, 3)
    # never below the minimum (osd.brightnessMin): many steps down stop at 1 %
    for _ in range(25):
        nested.shortcut("bright-down")
    nested.wait_for(lambda: hw.backlight_value() == -(-hw.backlight_max // 100), 5)
    assert all(line.split()[0] in (hw.backlight, hw.kbd) for line in hw.writes())


def test_keyboard_light(nested: Nested) -> None:
    hw = nested.hw
    nested.wait_for(lambda: svc(nested, "brightness")["kbdMax"] == hw.kbd_max, 5)
    k0 = hw.kbd_value()
    nested.shortcut("kbd-up")
    nested.wait_for(lambda: hw.kbd_value() == min(hw.kbd_max, k0 + 1), 3)
    nested.wait_for(lambda: osd(nested, "kbd"), 3)
    on = hw.kbd_value()
    nested.shortcut("kbd-toggle")
    nested.wait_for(lambda: hw.kbd_value() == 0, 3)
    nested.shortcut("kbd-toggle")
    nested.wait_for(lambda: hw.kbd_value() == on, 3)       # back to the level before
    nested.shortcut("kbd-down")
    nested.wait_for(lambda: hw.kbd_value() == on - 1, 3)


def test_caps_lock_osd(nested: Nested) -> None:
    nested.shortcut("capslock-on")
    nested.wait_for(lambda: osd(nested, "caps"), 3)
    nested.shortcut("capslock-off")
    settle(0.3)
    assert osd(nested, "caps")                            # the same OSD, updated in place


def test_media_keys_act_on_the_fake_player(nested: Nested) -> None:
    player = FakePlayer(nested, "aptustest", playing=True)
    try:
        nested.wait_for(lambda: svc(nested, "media")["active"].endswith("aptustest"), 5)
        nested.shortcut("media-toggle")
        nested.wait_for(lambda: any(c in ("PlayPause", "Pause") for c in player.calls()), 3)
        nested.shortcut("media-next")
        nested.wait_for(lambda: "Next" in player.calls(), 3)
        nested.shortcut("media-prev")
        nested.wait_for(lambda: "Previous" in player.calls(), 3)
    finally:
        player.stop()
    nested.wait_for(lambda: svc(nested, "media")["players"] == 0, 5)


def test_nothing_to_play(nested: Nested) -> None:
    assert svc(nested, "media")["players"] == 0
    nested.shortcut("media-toggle")
    nested.wait_for(lambda: any(e["kind"] == "event" for e in active(nested)["passive"]), 3)


def test_event_after_an_osd_leaves_on_time(nested: Nested) -> None:
    """An event that waited behind an OSD shows once the OSD collapses and leaves event.ms later
    (phase 7 found it staying: the expiry timer was stopped by an older _expire call)."""
    nested.shortcut("kbd-up")
    nested.wait_for(lambda: osd(nested, "kbd"), 3)
    nested.msg("notch", "event", "After the OSD", "info")
    nested.wait_for(lambda: active(nested)["passiveTop"]["kind"] == "event", 3)
    nested.wait_for(lambda: not any(e["kind"] == "event" for e in active(nested)["passive"]), 2.5)


def test_no_osd_while_the_deck_or_a_mode_is_open(nested: Nested) -> None:
    mon = nested.state()["global"]["activeMonitor"]
    assert nested.msg("surface", "open", "deck") == "ok"
    try:
        v0 = svc(nested, "audio")["volume"]
        nested.shortcut("vol-up")
        nested.wait_for(lambda: svc(nested, "audio")["volume"] != v0, 3)
        settle(0.3)
        assert osd(nested, "volume") is None             # the Deck's slider moves instead
    finally:
        nested.msg("surface", "close", "deck")
    assert nested.msg("surface", "open", "spotlight") == "ok"
    try:
        nested.shortcut("vol-down")
        settle(0.3)
        assert nested.state()["monitors"][mon]["passiveTop"]["kind"] != "osd"   # suppressed under a mode
    finally:
        nested.msg("surface", "close", "spotlight")
