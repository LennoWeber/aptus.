"""S3 acceptance, multi-monitor: a headless output added and removed in the nested session with a
toast and a card open; no crash, surfaces on the removed monitor close, the strips follow
auto-workspace-monitors.sh (05 §7)."""
from __future__ import annotations

from nested import Nested
from s3bus import FakePlayer, close_notification, notify, setting, settle

NAME = "S3TEST"


def test_add_and_remove_an_output_with_surfaces_open(nested: Nested) -> None:
    before = set(nested.state()["monitors"])
    nested.hyprctl("output", "create", "headless", NAME)
    nested.hyprctl("dispatch", 'hl.monitor({ output = "' + NAME + '", mode = "1920x1080@60", position = "4000x0", scale = 1 })')
    nested.wait_for(lambda: NAME in nested.state()["monitors"], 10)
    player = FakePlayer(nested, "aptusmon", playing=True)
    nid = 0
    try:
        nested.hyprctl("dispatch", f'hl.dsp.focus({{ monitor = "{NAME}" }})')
        nested.wait_for(lambda: nested.state()["global"]["activeMonitor"] == NAME, 5)
        # the strips follow the script: the external output holds 1–5, eDP-1 (if any) 6–10
        strips = nested.state()["services"]["bar"]["strips"]
        assert NAME in strips
        nid = notify(nested, "On the new output", "", "-a", "TestApp", "-u", "critical")
        nested.wait_for(lambda: any(e["key"] == f"n:{nid}" for e in nested.state()["monitors"][NAME]["passive"]), 5)
        assert nested.msg("surface", "open", "card:media", '{"pinned": true}') == "ok"
        nested.wait_for(lambda: nested.state()["monitors"][NAME]["notch"] == "card:media", 5)
        settle(0.5)
    finally:
        nested.hyprctl("output", "remove", NAME)
    nested.wait_for(lambda: NAME not in nested.state()["monitors"], 10)
    st = nested.state()
    assert set(st["monitors"]) == before
    assert st["global"]["activeMonitor"] in before
    # the shell survived and the toast went with its monitor (Today keeps the record)
    for m in st["monitors"].values():
        assert all(e["key"] != f"n:{nid}" for e in m["passive"])
    close_notification(nested, nid)
    player.stop()


def test_fixed_workspaces_split_one_to_five_and_six_to_ten(nested: Nested) -> None:
    """bar.md §4, 05 §7 (wave-2 review): `bar.workspaces.show: fixed` follows
    auto-workspace-monitors.sh: the external output holds 1–5, eDP-1 6–10 (a headless output named
    eDP-1 stands in for the laptop panel; the nested output is the external one)."""
    nested_out = nested.state()["global"]["activeMonitor"]
    assert nested_out != "eDP-1"
    setting(nested, "bar.workspaces.show", "fixed")
    try:
        nested.hyprctl("output", "create", "headless", "eDP-1")
        nested.hyprctl("dispatch", 'hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "4000x0", scale = 1 })')
        nested.wait_for(lambda: "eDP-1" in nested.state()["monitors"], 10)

        def split() -> bool:
            strips = nested.state()["services"]["bar"]["strips"]
            # eDP-1 also shows its active workspace (Hyprland gave the new output the first free
            # one, 2: no auto-workspace-monitors.sh in the nested session), as `fixed` shows any
            # used or active workspace outside the fixed ids
            return (set(range(1, 6)) <= set(strips.get(nested_out, [])) and not set(range(6, 11)) & set(strips[nested_out])
                    and set(range(6, 11)) <= set(strips.get("eDP-1", [])))
        nested.wait_for(split, 5)
    finally:
        nested.hyprctl("output", "remove", "eDP-1")
        setting(nested, "bar.workspaces.show")
    nested.wait_for(lambda: "eDP-1" not in nested.state()["monitors"], 10)
    # back to `used`: only the used and the active workspace stay
    nested.wait_for(lambda: not set(range(6, 11)) <= set(nested.state()["services"]["bar"]["strips"][nested_out]), 5)
