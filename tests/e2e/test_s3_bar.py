"""S3 acceptance, bar and notch states: workspaces strip, fullscreen leave (M-31) and the hot edge,
ways out (Esc, click outside, activation) for toasts, cards and the OSD; screenshots."""
from __future__ import annotations

import json
import os
import subprocess
import time
from pathlib import Path

import pytest

from nested import Nested, write_test_png
from s3bus import (BellWindow, FakePlayer, FakeTray, Window, close_notification, distance, drained, grab, mean, notify,
                   notify_waiting, passive, pointer, setting, settle, shell_pid, wheel)


def shots(nested: Nested) -> Path:
    """Where the screenshots go: $APTUS_SHOTS (kept for the visual review), else the session's folder."""
    d = Path(os.environ.get("APTUS_SHOTS") or nested.root / "shots")
    d.mkdir(parents=True, exist_ok=True)
    return d


def mon(nested: Nested) -> dict:
    return next(m for m in nested.hyprctl("monitors", as_json=True) if m["focused"])


def state_of(nested: Nested) -> dict:
    st = nested.state()
    return st["monitors"][st["global"]["activeMonitor"]]


def strip(nested: Nested) -> list[int]:
    st = nested.state()
    return st["services"]["bar"]["strips"][st["global"]["activeMonitor"]]


@pytest.fixture
def window(nested: Nested):
    w = Window(nested, "aptus.e2e.s3")
    yield w
    w.close()


@pytest.fixture
def player(nested: Nested):
    p = FakePlayer(nested, "aptusbar", playing=True)
    nested.wait_for(lambda: nested.state()["services"]["media"]["active"].endswith("aptusbar"), 5)
    yield p
    p.stop()


def test_strip_follows_workspaces(nested: Nested, window: Window) -> None:
    nested.hyprctl("dispatch", 'hl.dsp.focus({ workspace = "3" })')
    nested.wait_for(lambda: 3 in strip(nested), 3)               # active, so shown though empty
    nested.hyprctl("dispatch", 'hl.dsp.focus({ workspace = "1" })')
    nested.wait_for(lambda: 3 not in strip(nested), 3)           # empty and left: gone ("used")
    assert 1 in strip(nested)


def test_fullscreen_leave_and_critical_above(nested: Nested, window: Window) -> None:
    window.fullscreen()
    try:
        nested.wait_for(lambda: state_of(nested)["fullscreen"], 3)
        normal = notify(nested, "Normal", "", "-a", "TestApp")
        settle(0.6)
        assert state_of(nested)["passiveTop"]["kind"] == "hidden"
        crit = notify(nested, "Critical", "above the window", "-a", "TestApp", "-u", "critical")
        nested.wait_for(lambda: state_of(nested)["passiveTop"]["kind"] == "toast", 3)
        settle(0.6)
        nested.screenshot(shots(nested) / "fullscreen-critical.png")
        nested.shortcut("vol-up")
        nested.wait_for(lambda: state_of(nested)["passiveTop"]["kind"] == "osd", 3)   # the OSD too
        close_notification(nested, crit)
        close_notification(nested, normal)
        # wave-2 review: the held one was closed by its sender, so leaving summarises nothing
        nested.wait_for(lambda: nested.state()["services"]["notifications"]["held"] == 0, 3)
    finally:
        window.leave()
    settle(0.5)
    assert not any(e["key"] == "held" for e in passive(nested)), "a summary of a closed notification"
    drained(nested)                         # a clean state for the next test (the OSD fades)


def test_hot_edge_reveal(nested: Nested, window: Window) -> None:
    window.fullscreen()
    try:
        m = mon(nested)
        band = lambda: mean(grab(nested, m["x"] + 40, m["y"] + 8, 200, 16))   # the bar's left zone
        pointer(nested, "move", m["x"] + m["width"] // 2, m["y"] + m["height"] // 2)
        settle(0.8)                                              # the bar has slid out (M-31)
        hidden = band()
        start = time.monotonic()           # before the helper: it returns a while after the move
        pointer(nested, "move", m["x"] + m["width"] // 2, m["y"])
        nested.wait_for(lambda: distance(hidden, band()) > 8, 3)  # the bar slides back in
        assert time.monotonic() - start >= 0.38                  # not before the 400 ms push
        shown = band()
        pointer(nested, "move", m["x"] + m["width"] // 2, m["y"] + m["height"] // 2)
        nested.wait_for(lambda: distance(hidden, band()) < distance(shown, band()), 3)   # and out again
    finally:
        window.leave()


def test_pinned_card_ways_out(nested: Nested, player: FakePlayer) -> None:
    m = mon(nested)
    for way in ("escape", "outside", "again"):
        drained(nested)                     # a toast or OSD on top would take the card's keyboard
        assert nested.msg("surface", "open", "card:media", '{"pinned": true}') == "ok"
        nested.wait_for(lambda: state_of(nested)["notch"] == "card:media" and state_of(nested)["keyboard"], 3)
        settle(0.4)
        if way == "escape":
            nested.key("Escape")
        elif way == "outside":
            nested.click(m["x"] + m["width"] // 2, m["y"] + m["height"] - 60)
        else:
            nested.msg("surface", "toggle", "card:media")
        nested.wait_for(lambda: state_of(nested)["notch"] == "rest", 3)


def test_pinned_card_under_a_toast_then_escape(nested: Nested, player: FakePlayer) -> None:
    """A toast arriving over a pinned card shows above it (notch.md §9) and the card gives up the
    keyboard meanwhile (rules.js keyboard), so Esc does not reach the shell; once the toast is
    gone the card has the keyboard again and Esc closes it (05 §3)."""
    drained(nested)
    assert nested.msg("surface", "open", "card:media", '{"pinned": true}') == "ok"
    nested.wait_for(lambda: state_of(nested)["notch"] == "card:media" and state_of(nested)["keyboard"], 3)
    nid = notify(nested, "Over the card", "", "-a", "TestApp")
    try:
        nested.wait_for(lambda: state_of(nested)["passiveTop"]["kind"] == "toast", 3)
        s = state_of(nested)
        assert s["notch"] == "card:media" and not s["keyboard"]
        nested.key("Escape")                # to the window below: neither the toast nor the card closes
        settle(0.4)
        s = state_of(nested)
        assert s["notch"] == "card:media" and s["passiveTop"]["kind"] == "toast"
    finally:
        close_notification(nested, nid)
    nested.wait_for(lambda: state_of(nested)["passiveTop"]["kind"] == "card" and state_of(nested)["keyboard"], 3)
    settle(0.3)
    nested.key("Escape")
    nested.wait_for(lambda: state_of(nested)["notch"] == "rest", 3)


def test_hover_card_opens_and_collapses(nested: Nested, player: FakePlayer) -> None:
    m = mon(nested)
    cx, y = m["x"] + m["width"] // 2, m["y"] + 16
    opened = False
    for dx in [d * s for d in range(12, 220, 8) for s in (-1, 1)]:   # the compact slots beside the clock
        pointer(nested, "move", cx + dx, y)
        time.sleep(0.45)                                         # 300 ms rest, then the card
        if state_of(nested)["notch"] == "card:media":
            opened = True
            break
    assert opened, "no hover card beside the clock"
    assert not state_of(nested)["keyboard"]                      # a hover card never takes the keyboard
    pointer(nested, "move", cx, m["y"] + m["height"] - 100)
    nested.wait_for(lambda: state_of(nested)["notch"] == "rest", 2)


def changed_columns(a: bytes, b: bytes, width: int) -> list[int]:
    """The x of every column where two RGB grabs of the same width differ."""
    rows = len(a) // (3 * width)
    return [x for x in range(width)
            if any(a[(y * width + x) * 3:(y * width + x) * 3 + 3] != b[(y * width + x) * 3:(y * width + x) * 3 + 3]
                   for y in range(rows))]


def test_tray_item_menu_and_attention(nested: Nested) -> None:
    """bar.md §5: an item appears left of the status cluster; click activates; right click shows
    its DBusMenu as an aptus menu (keyboard: Down, Return triggers the first row); NeedsAttention
    adds the warn dot."""
    m = mon(nested)
    right = lambda: grab(nested, m["x"] + m["width"] // 2, m["y"], m["width"] // 2, 32)
    before = right()
    tray = FakeTray(nested)
    try:
        settle(1.0)
        cols = changed_columns(before, right(), m["width"] // 2)
        cols = [c for c in cols if c > m["width"] // 4]               # the right zone, not the clock
        assert cols, "no tray item appeared"
        x = m["x"] + m["width"] // 2 + (min(cols) + max(cols)) // 2
        pointer(nested, "move", x, m["y"] + 300)
        pointer(nested, "click", x, m["y"] + 16)
        nested.wait_for(lambda: any(c.startswith("Activate") for c in tray.calls()), 3)
        pointer(nested, "rclick", x, m["y"] + 16)
        nested.wait_for(lambda: (state_of(nested)["menu"] or {}).get("owner") == "tray:aptus-test-tray", 3)
        settle(0.3)
        nested.key("Down")
        nested.key("Return")
        nested.wait_for(lambda: "Event 1 clicked" in tray.calls(), 3)        # "Open", through DBusMenu
        nested.wait_for(lambda: state_of(nested)["menu"] is None, 3)
        pointer(nested, "move", x, m["y"] + 300)
        settle(0.8)                                                        # no tooltip left over
        calm = grab(nested, x - 12, m["y"], 24, 32)
        tray.toggle()
        nested.wait_for(lambda: grab(nested, x - 12, m["y"], 24, 32) != calm, 3)   # the attention dot
    finally:
        tray.stop()


def urgent_toast(nested: Nested, ws: int) -> bool:
    return any(e["kind"] == "toast" and e["key"] == f"urgent:{ws}" for e in passive(nested))


def test_urgent_toast_and_its_repeat(nested: Nested) -> None:
    """bar.md §3, notch.md §6: an urgent window on a workspace not shown toasts once per urgency;
    once the workspace was shown it may toast again."""
    drained(nested)
    nested.hyprctl("dispatch", 'hl.dsp.focus({ workspace = "1" })')
    w = BellWindow(nested, "aptus.e2e.urgent")
    try:
        w.to_workspace("2")
        nested.hyprctl("dispatch", 'hl.dsp.focus({ workspace = "1" })')
        settle(0.5)
        assert not urgent_toast(nested, 2)
        w.ring()
        nested.wait_for(lambda: urgent_toast(nested, 2), 5)
        nested.wait_for(lambda: not urgent_toast(nested, 2), 12)     # the toast's own timeout
        w.ring()                                                    # still the same urgency: no second toast
        settle(1.5)
        assert not urgent_toast(nested, 2)
        nested.hyprctl("dispatch", 'hl.dsp.focus({ workspace = "2" })')   # seen (the window takes the focus)
        settle(0.5)
        nested.hyprctl("dispatch", 'hl.dsp.focus({ workspace = "1" })')
        settle(0.5)
        w.ring()
        nested.wait_for(lambda: urgent_toast(nested, 2), 5)
    finally:
        w.close()
    drained(nested)


def test_wheel_on_the_strip_steps_through_used_workspaces(nested: Nested, window: Window) -> None:
    """bar.md §3: the wheel over the strip goes to the previous / next used workspace, one step per
    notch."""
    other = Window(nested, "aptus.e2e.wheel")
    try:
        window.to_workspace("1")
        other.to_workspace("2")
        nested.hyprctl("dispatch", 'hl.dsp.focus({ workspace = "1" })')
        nested.wait_for(lambda: strip(nested) == [1, 2], 3)
        m = mon(nested)
        active_ws = lambda: (nested.hyprctl("activeworkspace", as_json=True) or {}).get("id")
        wheel(nested, m["x"] + 60, m["y"] + 16, 1)                    # down: the next one
        nested.wait_for(lambda: active_ws() == 2, 3)
        settle(0.3)
        wheel(nested, m["x"] + 60, m["y"] + 16, -1)                   # up: back
        nested.wait_for(lambda: active_ws() == 1, 3)
    finally:
        other.close()


def test_tray_overflow(nested: Nested) -> None:
    """bar.md §5: items beyond bar.tray.max sit behind the overflow button; its menu lists them and
    a row activates its item."""
    m = mon(nested)
    right = lambda: grab(nested, m["x"] + m["width"] // 2, m["y"], m["width"] // 2, 32)
    setting(nested, "bar.tray.max", 0)
    settle(0.5)
    before = right()
    tray = FakeTray(nested)
    try:
        settle(1.0)
        cols = [c for c in changed_columns(before, right(), m["width"] // 2) if c > m["width"] // 4]
        assert cols, "no overflow button appeared"
        x = m["x"] + m["width"] // 2 + (min(cols) + max(cols)) // 2
        pointer(nested, "click", x, m["y"] + 16)
        nested.wait_for(lambda: (state_of(nested)["menu"] or {}).get("owner") == "tray:overflow", 3)
        settle(0.3)
        nested.key("Down")
        nested.key("Return")
        nested.wait_for(lambda: any(c.startswith("Activate") for c in tray.calls()), 3)
        nested.wait_for(lambda: state_of(nested)["menu"] is None, 3)
    finally:
        tray.stop()
        setting(nested, "bar.tray.max")
        pointer(nested, "move", m["x"] + m["width"] // 2, m["y"] + 300)


def test_privacy_reports_nothing_under_test(nested: Nested) -> None:
    p = nested.state()["services"]["privacy"]
    assert p["mic"] == 0 and p["camera"] == 0
    # the test shell is no PipeWire client (pw-dump reads the real graph, read only; the nested
    # session's xdg-desktop-portal, D-Bus-activated by Qt, is one, but it is not the shell)
    mine = {str(shell_pid(nested))}
    try:
        dump = json.loads(subprocess.run(["pw-dump"], capture_output=True, text=True, timeout=10).stdout or "[]")
    except (FileNotFoundError, json.JSONDecodeError):
        pytest.skip("pw-dump unavailable")
    clients = [o for o in dump if o.get("type") == "PipeWire:Interface:Client"]
    pids = {str((o.get("info") or {}).get("props", {}).get("application.process.id", "")) for o in clients}
    assert not (pids & mine)


def test_screenshots(nested: Nested) -> None:
    """Rest, toast, OSD, event and card on a 1920×1080 headless output, for the visual review
    (a player with a cover, so the compact look and the card show it)."""
    cover = nested.root / "cover.png"
    write_test_png(cover, 300, 300)
    player = FakePlayer(nested, "aptusshot", playing=True, art=cover.as_uri())
    nested.wait_for(lambda: nested.state()["services"]["media"]["active"].endswith("aptusshot"), 5)
    name = "S3SHOT"
    nested.hyprctl("output", "create", "headless", name)
    nested.hyprctl("dispatch", 'hl.monitor({ output = "' + name + '", mode = "1920x1080@60", position = "4000x0", scale = 1 })')
    try:
        nested.wait_for(lambda: name in nested.state()["monitors"], 10)
        nested.hyprctl("dispatch", f'hl.dsp.focus({{ monitor = "{name}" }})')
        nested.wait_for(lambda: nested.state()["global"]["activeMonitor"] == name, 5)
        out = shots(nested)
        env = dict(os.environ, WAYLAND_DISPLAY=nested.wayland_display)

        def top() -> str:
            return nested.state()["monitors"][name]["passiveTop"]["kind"]

        def shot(tag: str, kind: str = "rest") -> None:
            """After the notch of the screenshot output shows `kind` (and its morph settled)."""
            nested.wait_for(lambda: top() == kind, 3)
            settle(0.8)
            subprocess.run(["grim", "-o", name, str(out / f"{tag}.png")], env=env, check=True, timeout=10)

        shot("rest")
        nid, waiting = notify_waiting(nested, "Lunch?", "Shall we go at <b>12:30</b>?", "-a", "Chat",
                                      "-A", "yes=Yes", "-A", "no=No")
        shot("toast-actions", "toast")
        close_notification(nested, nid)
        waiting.terminate()
        nested.shortcut("vol-up")
        shot("osd-volume", "osd")
        nested.shortcut("kbd-up")
        shot("osd-kbd", "osd")
        nested.wait_for(lambda: top() == "rest", 3)
        nested.msg("notch", "event", "Headphones connected · 70 %", "headphones")
        shot("event", "event")
        nested.wait_for(lambda: not any(e["kind"] == "event" for e in nested.state()["monitors"][name]["passive"]), 5)
        nested.msg("surface", "open", "card:media", '{"pinned": true}')
        shot("card-media", "card")
        nested.msg("surface", "close", "card:media")
        assert nested.msg("theme", "mode", "light") == "ok"
        shot("rest-light")
        nid = notify(nested, "Build finished", "aptus · 2 warnings", "-a", "Terminal")
        shot("toast-light", "toast")
        close_notification(nested, nid)
        for tag in ("rest", "toast-actions", "osd-volume", "osd-kbd", "event", "card-media", "rest-light", "toast-light"):
            head = (out / f"{tag}.png").read_bytes()[16:24]
            assert int.from_bytes(head[:4], "big") == 1920 and int.from_bytes(head[4:], "big") == 1080
    finally:
        nested.msg("theme", "mode", "dark")
        nested.hyprctl("output", "remove", name)
        player.stop()
