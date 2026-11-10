"""S3 acceptance, notifications (notch.md §6, 05 §8) with notify-send on the nested session's
private bus: arrival rules, timing, critical, replaces-id, stack, history; Ipc `notch toast`."""
from __future__ import annotations

import json
import time

import pytest

from nested import Nested
from s3bus import Window, close_notification, gdbus, name_owner, notify, pointer, settle

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
