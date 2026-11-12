"""S3 acceptance, notifications (notch.md §6, 05 §8) with notify-send on the nested session's
private bus: arrival rules, timing, critical, replaces-id, stack, history; Ipc `notch toast`;
the inline reply field."""
from __future__ import annotations

import json
import subprocess
import time

import pytest

from nested import Nested, write_test_png
from s3bus import Window, bus_address, close_notification, gdbus, name_owner, notify, pointer, settle

SENT: list[int] = []


def active(nested: Nested) -> dict:
    st = nested.state()
    return st["monitors"][st["global"]["activeMonitor"]]


def toasts(nested: Nested) -> list[dict]:
    return [e for e in active(nested)["passive"] if e["kind"] == "toast"]


def toast_for(nested: Nested, nid: int) -> dict | None:
    return next((e for e in toasts(nested) if e["key"] == f"n:{nid}"), None)


def history(nested: Nested) -> int:
    return nested.state()["services"]["notifications"]["history"]


def svc(nested: Nested) -> dict:
    return nested.state()["services"]["notifications"]


def progress(nested: Nested) -> list[tuple[str, float]]:
    return [(i["id"], i["fraction"]) for i in nested.state()["services"]["progress"]["items"]]


def away(nested: Nested) -> None:
    """The pointer off the notch (hovering a toast pauses its countdown)."""
    m = next(m for m in nested.hyprctl("monitors", as_json=True) if m["focused"])
    pointer(nested, "move", m["x"] + m["width"] // 2, m["y"] + m["height"] - 100)


def send(nested: Nested, summary: str, body: str = "", *args: str) -> int:
    nid = notify(nested, summary, body, *args)
    SENT.append(nid)
    return nid


@pytest.fixture
def fullscreen_window(nested: Nested):
    """A fullscreen kitty on the active monitor (left and closed afterwards)."""
    w = Window(nested, "aptus.e2e.held")
    w.fullscreen()
    nested.wait_for(lambda: active(nested)["fullscreen"], 3)    # the shell has seen it too
    yield w
    if (w.client() or {}).get("fullscreen"):
        w.leave()
    w.close()


@pytest.fixture(autouse=True)
def quiet(nested: Nested):
    """Every test starts without toasts: the senders close what the tests sent before."""
    nested.wait_for(lambda: nested.state()["services"]["notifications"]["serverActive"], 10)
    for nid in SENT:
        try:
            close_notification(nested, nid)
        except Exception:
            pass
    SENT.clear()
    nested.wait_for(lambda: not toasts(nested), 12)
    yield


def test_aptus_owns_the_notification_name(nested: Nested) -> None:
    owner = name_owner(nested, "org.freedesktop.Notifications")
    assert owner
    out = gdbus(nested, "--dest", "org.freedesktop.DBus", "--object-path", "/org/freedesktop/DBus",
                "--method", "org.freedesktop.DBus.GetConnectionUnixProcessID", owner)
    pid = int(out.strip("()").split()[-1].rstrip(","))
    cmd = open(f"/proc/{pid}/cmdline", "rb").read().split(b"\0")
    assert any(c.endswith(b"qs") or c.endswith(b"quickshell") for c in cmd), cmd
    info = gdbus(nested, "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications",
                 "--method", "org.freedesktop.Notifications.GetServerInformation")
    assert "aptus" in info.lower() or "quickshell" in info.lower()


def test_normal_toast_and_history(nested: Nested) -> None:
    before = history(nested)
    nid = send(nested, "Hello", "A <b>bold</b> body", "-a", "TestApp")
    e = nested.wait_for(lambda: toast_for(nested, nid), 5)
    assert e["priority"] == 0
    assert active(nested)["passiveTop"]["kind"] == "toast"
    nested.wait_for(lambda: history(nested) == before + 1, 5)


def test_low_urgency_goes_to_today_only(nested: Nested) -> None:
    before = history(nested)
    nid = send(nested, "Quiet", "", "-u", "low", "-a", "TestApp")
    nested.wait_for(lambda: history(nested) == before + 1, 5)
    settle(0.5)
    assert toast_for(nested, nid) is None


def test_critical_has_no_timeout(nested: Nested) -> None:
    nid = send(nested, "Battery", "Critical", "-u", "critical", "-a", "TestApp")
    e = nested.wait_for(lambda: toast_for(nested, nid), 5)
    assert e["priority"] >= 2
    time.sleep(10)                                     # past the longest normal timeout (toast.maxTimeoutMs)
    assert toast_for(nested, nid) is not None


def test_replaces_id_updates_in_place(nested: Nested) -> None:
    nid = send(nested, "Download", "1 of 3", "-a", "TestApp")
    first = nested.wait_for(lambda: toast_for(nested, nid), 5)
    again = notify(nested, "Download", "2 of 3", "-a", "TestApp", "-r", str(nid))
    assert again == nid
    settle(0.5)
    same = [e for e in toasts(nested) if e["key"] == f"n:{nid}"]
    assert len(same) == 1 and same[0]["id"] == first["id"]


def test_burst_becomes_one_stack_toast(nested: Nested) -> None:
    ids = [send(nested, f"Message {i}", "", "-a", f"App{i}") for i in range(3)]
    nested.wait_for(lambda: toasts(nested), 5)
    settle(0.5)
    t = toasts(nested)
    assert len(t) == 1, t                              # the second and third joined the first one's toast
    assert t[0]["key"] == f"n:{ids[0]}"
    # its count and apps, newest app first (notifications.js stackStep)
    assert svc(nested)["stack"] == {"count": 3, "apps": ["App2", "App1", "App0"]}


def test_countdown_restarts_on_replace_and_stack_join(nested: Nested) -> None:
    """notch.md §6 rule 3: a replace or a stack join restarts the toast's countdown."""
    away(nested)
    nid = send(nested, "Countdown", "", "-a", "TestApp")          # 4 s + 9 × 40 ms = 4.36 s
    nested.wait_for(lambda: toast_for(nested, nid), 5)
    t0 = time.monotonic()
    time.sleep(3.0)
    notify(nested, "Countdown", "", "-a", "TestApp", "-r", str(nid))
    time.sleep(max(0.0, 5.2 - (time.monotonic() - t0)))           # past the first deadline
    assert toast_for(nested, nid) is not None, "the replace restarted the countdown"
    nested.wait_for(lambda: toast_for(nested, nid) is None, 5)
    # a stack: the third arrival (within notifications.stackWindow of the second) restarts it too
    first = send(nested, "Stack one", "", "-a", "AppA")
    nested.wait_for(lambda: toast_for(nested, first), 5)
    send(nested, "Stack two", "", "-a", "AppB")
    nested.wait_for(lambda: (svc(nested)["stack"] or {}).get("count") == 2, 3)
    t0 = time.monotonic()
    time.sleep(1.6)
    send(nested, "Stack three", "", "-a", "AppC")
    nested.wait_for(lambda: (svc(nested)["stack"] or {}).get("count") == 3, 3)
    time.sleep(max(0.0, 5.2 - (time.monotonic() - t0)))           # past the second join's deadline
    assert toast_for(nested, first) is not None, "the join restarted the countdown"
    nested.wait_for(lambda: toast_for(nested, first) is None, 5)


def test_progress_activity_from_a_value_hint(nested: Nested) -> None:
    """notch.md §6 rule 4: a notification with a `value` hint is a progress activity, no toast;
    at 100 it leaves the activity and toasts."""
    nid = send(nested, "Download", "3 of 10 MB", "-a", "TestApp", "-h", "int:value:30")
    nested.wait_for(lambda: progress(nested) == [(f"n:{nid}", 0.3)], 5)
    settle(0.3)
    assert toast_for(nested, nid) is None
    notify(nested, "Download", "6 of 10 MB", "-a", "TestApp", "-r", str(nid), "-h", "int:value:60")
    nested.wait_for(lambda: progress(nested) == [(f"n:{nid}", 0.6)], 5)
    notify(nested, "Download", "done", "-a", "TestApp", "-r", str(nid), "-h", "int:value:100")
    nested.wait_for(lambda: progress(nested) == [], 5)
    nested.wait_for(lambda: toast_for(nested, nid), 5)


def test_toast_close_button_middle_click_and_menu(nested: Nested) -> None:
    """notch.md §6: ✕ (on hover) and a middle click dismiss; the right-click menu closes with Esc
    and its first row mutes the app for an hour (its next notification goes to Today only)."""
    m = next(m for m in nested.hyprctl("monitors", as_json=True) if m["focused"])
    cx, top = m["x"] + m["width"] // 2, m["y"] + 32               # the 420 × 72 toast below the bar
    nid = send(nested, "Close me", "", "-a", "TestApp")
    nested.wait_for(lambda: toast_for(nested, nid), 5)
    settle(0.6)
    pointer(nested, "move", cx, top + 36)                          # the ✕ shows on hover
    settle(0.4)
    pointer(nested, "click", cx + 210 - 2 - 14, top + 2 + 14)
    nested.wait_for(lambda: toast_for(nested, nid) is None, 3)
    away(nested)
    nid = send(nested, "Middle", "", "-a", "TestApp")
    nested.wait_for(lambda: toast_for(nested, nid), 5)
    settle(0.6)
    pointer(nested, "mclick", cx, top + 36)
    nested.wait_for(lambda: toast_for(nested, nid) is None, 3)
    away(nested)
    nid = send(nested, "Menu", "", "-a", "MuteMe")
    nested.wait_for(lambda: toast_for(nested, nid), 5)
    settle(0.6)
    pointer(nested, "rclick", cx, top + 36)
    nested.wait_for(lambda: (active(nested)["menu"] or {}).get("owner") == "notch:toast", 3)
    settle(0.3)
    nested.key("Escape")
    nested.wait_for(lambda: active(nested)["menu"] is None, 3)
    assert toast_for(nested, nid) is not None, "Esc closed only the menu"
    pointer(nested, "rclick", cx, top + 36)
    nested.wait_for(lambda: (active(nested)["menu"] or {}).get("owner") == "notch:toast", 3)
    settle(0.3)
    nested.key("Down")
    nested.key("Return")                                          # "Mute MuteMe for 1 hour"
    nested.wait_for(lambda: toast_for(nested, nid) is None, 3)
    away(nested)
    before = history(nested)
    muted = send(nested, "Muted", "", "-a", "MuteMe")
    nested.wait_for(lambda: history(nested) == before + 1, 5)
    settle(0.5)
    assert toast_for(nested, muted) is None


def test_image_is_copied_once_for_its_replaces(nested: Nested) -> None:
    """today.md §6, wave-2 review: the image is copied into the cache once confirmed; replaces with
    the same unchanged image reuse the copy; a malformed file:// URL is no image, not a lost
    notification."""
    img = nested.root / "sender-image.png"
    write_test_png(img, 64, 64)
    cache = nested.paths.cache / "notif"
    files = lambda: set(cache.iterdir()) if cache.exists() else set()
    before = files()
    nid = send(nested, "With image", "", "-a", "TestApp", "-h", f"string:image-path:{img}")
    nested.wait_for(lambda: len(files() - before) == 1, 5)
    for i in range(5):
        notify(nested, f"With image {i}", "", "-a", "TestApp", "-r", str(nid), "-h", f"string:image-path:{img}")
    settle(1.5)
    assert len(files() - before) == 1, sorted(p.name for p in files() - before)
    close_notification(nested, nid)                  # its toast goes: the next one is not stacked
    nested.wait_for(lambda: toast_for(nested, nid) is None, 5)
    n = history(nested)
    bad = send(nested, "Bad image URL", "", "-a", "TestApp", "-h", "string:image-path:file:///tmp/%E0%A4%A.png")
    nested.wait_for(lambda: history(nested) == n + 1, 5)
    nested.wait_for(lambda: toast_for(nested, bad), 5)


def test_held_then_closed_by_its_sender_is_not_summarised(nested: Nested, fullscreen_window) -> None:
    nid = send(nested, "Gone before you look", "", "-a", "TestApp")
    nested.wait_for(lambda: svc(nested)["held"] >= 1, 5)
    close_notification(nested, nid)
    nested.wait_for(lambda: svc(nested)["held"] == 0, 5)
    fullscreen_window.leave()
    settle(1.0)
    assert not any(e["key"] == "held" for e in toasts(nested))


def test_ipc_notch_toast(nested: Nested) -> None:
    before = history(nested)
    assert nested.msg("notch", "toast", json.dumps({"appName": "Test", "summary": "Injected", "body": "x"})) == "ok"
    nested.wait_for(lambda: any(e["key"].startswith("n:-") for e in toasts(nested)), 5)
    nested.wait_for(lambda: history(nested) == before + 1, 5)
    with pytest.raises(RuntimeError, match="must be a JSON object"):
        nested.msg("notch", "toast", "not json")


def test_held_under_fullscreen_then_summary(nested: Nested, fullscreen_window) -> None:
    nid = send(nested, "While you watch", "", "-a", "TestApp")
    nested.wait_for(lambda: nested.state()["services"]["notifications"]["held"] >= 1, 5)
    assert toast_for(nested, nid) is None
    fullscreen_window.leave()
    nested.wait_for(lambda: any(e["key"] == "held" for e in toasts(nested)), 5)


def test_sender_close_removes_the_toast(nested: Nested) -> None:
    before = history(nested)
    nid = send(nested, "Closing", "", "-a", "TestApp")
    nested.wait_for(lambda: toast_for(nested, nid), 5)
    close_notification(nested, nid)
    nested.wait_for(lambda: toast_for(nested, nid) is None, 5)
    nested.wait_for(lambda: history(nested) == before, 5)


def test_toast_ways_out(nested: Nested) -> None:
    # the timeout: 4 s + 40 ms a character (notch.md §6)
    nid = send(nested, "Short", "", "-a", "TestApp")
    nested.wait_for(lambda: toast_for(nested, nid), 5)
    nested.wait_for(lambda: toast_for(nested, nid) is None, 8)
    # a click on the body: the default action (none here), then it goes
    nid = send(nested, "Click me", "", "-a", "TestApp")
    nested.wait_for(lambda: toast_for(nested, nid), 5)
    settle(0.6)                                        # the bulge has grown
    mon = next(m for m in nested.hyprctl("monitors", as_json=True) if m["focused"])
    pointer(nested, "click", mon["x"] + mon["width"] // 2, mon["y"] + 32 + 36)
    nested.wait_for(lambda: toast_for(nested, nid) is None, 3)


def test_toast_waits_while_spotlight_is_open(nested: Nested) -> None:
    """notch.md §9, §12: under an interactive mode toasts queue; it shows when the mode closes."""
    assert nested.msg("surface", "open", "spotlight") == "ok"
    try:
        nested.wait_for(lambda: active(nested)["notch"] == "spotlight", 3)
        nid = send(nested, "Behind Spotlight", "", "-a", "TestApp")
        nested.wait_for(lambda: toast_for(nested, nid), 5)            # queued, not dropped
        settle(0.5)
        assert active(nested)["passiveTop"]["kind"] != "toast"
    finally:
        nested.msg("surface", "close", "spotlight")
    nested.wait_for(lambda: active(nested)["passiveTop"]["kind"] == "toast", 3)


def reply_toast(nested: Nested, summary: str) -> int:
    """A notification with the inline-reply action (notify-send has no option for it)."""
    out = gdbus(nested, "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications",
                "--method", "org.freedesktop.Notifications.Notify", "Chat", "0", "", summary, "reply please",
                '["inline-reply", "Reply"]', "{}", "0")
    nid = int(out.strip("(),u ").split()[-1].rstrip(","))
    SENT.append(nid)
    return nid


def click_reply(nested: Nested) -> None:
    """The toast's first action button (Reply): 48 px into the toast (padding, icon, gap), in the
    action row 12 px above the 104 px toast's bottom."""
    m = next(m for m in nested.hyprctl("monitors", as_json=True) if m["focused"])
    # away first: a surface that grew under a resting pointer gets no enter until it moves
    pointer(nested, "move", m["x"] + m["width"] // 2, m["y"] + m["height"] - 100)
    pointer(nested, "click", m["x"] + m["width"] // 2 - 210 + 70, m["y"] + 32 + 78)


def test_inline_reply_takes_the_keyboard_and_sends(nested: Nested) -> None:
    """notch.md §6: Reply opens a field that takes the keyboard; Enter sends; Esc returns."""
    mon = subprocess.Popen(["stdbuf", "-oL", "gdbus", "monitor", "--address", bus_address(nested),
                            "--dest", "org.freedesktop.Notifications"], stdout=subprocess.PIPE, text=True)
    try:
        # Esc closes only the field: the toast stays
        nid = reply_toast(nested, "Esc first")
        nested.wait_for(lambda: toast_for(nested, nid), 5)
        settle(0.6)
        click_reply(nested)
        settle(0.4)
        # the reply is SurfaceManager state: the entry is replying, the monitor has the keyboard
        assert toast_for(nested, nid)["replying"] and active(nested)["keyboard"]
        nested.key("Escape")
        settle(0.3)
        assert toast_for(nested, nid) is not None
        assert not toast_for(nested, nid)["replying"] and not active(nested)["keyboard"]
        close_notification(nested, nid)
        nested.wait_for(lambda: toast_for(nested, nid) is None, 3)
        # typed text and Enter: NotificationReplied, and the toast goes
        nid = reply_toast(nested, "Then send")
        nested.wait_for(lambda: toast_for(nested, nid), 5)
        settle(0.6)
        click_reply(nested)
        settle(0.4)
        env = dict(__import__("os").environ, WAYLAND_DISPLAY=nested.wayland_display)
        subprocess.run(["wtype", "on my way"], env=env, check=True, timeout=10)
        nested.key("Return")
        nested.wait_for(lambda: toast_for(nested, nid) is None, 3)
    finally:
        time.sleep(0.5)
        mon.terminate()
    out = mon.communicate(timeout=5)[0]
    assert f"NotificationReplied (uint32 {nid}, 'on my way')" in out, out[-600:]
