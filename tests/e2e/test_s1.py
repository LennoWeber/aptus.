"""End-to-end S1 checks in a nested Hyprland (07 §13)."""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

from nested import Nested


def test_shell_starts(nested: Nested) -> None:
    st = nested.state()
    assert st["services"]["config"]["loaded"]
    assert list(st["monitors"]) == [m["name"] for m in nested.hyprctl("monitors", as_json=True)]
    status = json.loads((nested.home / ".aptus-run" / "aptus" / "session.json").read_text())
    assert status.get("test") is True


def test_globalshortcuts_listed(nested: Nested) -> None:
    out = nested.hyprctl("globalshortcuts")
    names = Path(__file__).resolve().parents[2] / "shell" / "registry" / "Shortcuts.qml"
    import re
    block = names.read_text().split("readonly property var names: [", 1)[1].split("]", 1)[0]
    for name in re.findall(r'"([a-z-]+)"', block):
        assert f"aptus:{name}" in out, name


def test_state_json(nested: Nested) -> None:
    st = nested.state()
    for m in st["monitors"].values():
        assert m["notch"] == "rest" and m["deck"] is False and m["top"] == ""
    assert "hypr" in st["services"] and "tokens" in st["services"]


def test_surface_open_back(nested: Nested) -> None:
    assert nested.msg("surface", "open", "spotlight") == "ok"
    st = nested.state()
    mon = st["global"]["activeMonitor"]
    assert st["monitors"][mon]["notch"] == "spotlight" and st["monitors"][mon]["keyboard"] is True
    assert nested.msg("surface", "open", "deck") == "ok"          # mode closes, Deck opens (07 §5)
    st = nested.state()
    assert st["monitors"][mon]["notch"] == "rest" and st["monitors"][mon]["deck"] is True
    nested.msg("surface", "back")
    assert nested.state()["monitors"][mon]["deck"] is False


def test_reserve_zone(nested: Nested) -> None:
    mon = nested.hyprctl("monitors", as_json=True)[0]
    assert mon["reserved"][1] == 32, mon["reserved"]           # top reserved by aptus-reserve


def test_mask_click_through(nested: Nested) -> None:
    nested.exec("kitty --class aptus.e2e.click")
    nested.wait_for(lambda: any(c["class"] == "aptus.e2e.click" for c in nested.hyprctl("clients", as_json=True)), 10)
    nested.hyprctl("dispatch", 'hl.dsp.focus({ workspace = "1" })')
    c = next(c for c in nested.hyprctl("clients", as_json=True) if c["class"] == "aptus.e2e.click")
    x, y = c["at"][0] + c["size"][0] // 2, c["at"][1] + c["size"][1] // 2
    nested.click(x, y)
    active = nested.hyprctl("activewindow", as_json=True)
    assert active and active.get("class") == "aptus.e2e.click"


def test_configerrors_empty(nested: Nested) -> None:
    errs = nested.hyprctl("configerrors", as_json=True)
    assert errs in ([], [""], None) or all(not e for e in errs), errs


def test_no_deprecated_config(nested: Nested) -> None:
    # A deprecated option shows a notification on every start of Lenno's session.
    assert nested.hyprctl("deprecated-config").strip() == "all good!"


def test_screenshot(nested: Nested) -> None:
    out = nested.screenshot(nested.root / "s1.png")
    assert out.stat().st_size > 1000
