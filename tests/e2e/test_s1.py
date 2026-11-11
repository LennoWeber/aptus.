"""End-to-end S1 checks in a nested Hyprland (07 §13)."""
from __future__ import annotations

import json
import re
import subprocess
import time
from pathlib import Path

from nested import Nested


def test_shell_starts(nested: Nested) -> None:
    st = nested.state()
    assert st["services"]["config"]["loaded"]
    assert list(st["monitors"]) == [m["name"] for m in nested.hyprctl("monitors", as_json=True)]
    status = json.loads(nested.paths.session_status.read_text())
    assert status.get("test") is True


def test_globalshortcuts_listed(nested: Nested) -> None:
    out = nested.hyprctl("globalshortcuts")
    shortcuts = Path(__file__).resolve().parents[2] / "shell" / "registry" / "Shortcuts.qml"
    names = re.findall(r'^\s*"([a-z][\w-]*)": \(\) =>', shortcuts.read_text(), re.M)
    assert names
    for name in names:
        assert f"aptus:{name}" in out, name


def test_state_json(nested: Nested) -> None:
    st = nested.state()
    for m in st["monitors"].values():
        assert m["notch"] == "rest" and m["deck"] is False and m["top"] == ""
    assert "hypr" in st["services"] and "tokens" in st["services"]


def test_outside_write_after_a_missing_file(nested: Nested) -> None:
    # The test HOME starts without settings.json: Config writes the empty file and watches it, so
    # an outside write (atomic or in place) is seen without `shell reloadConfig` (07 §8).
    path = nested.paths.settings
    nested.wait_for(path.exists, 5)
    assert json.loads(path.read_text()) == {"v": 2}

    def accent() -> str:
        return nested.state()["services"]["tokens"]["accent"]

    tmp = path.with_name(path.name + ".e2e-tmp")
    tmp.write_text(json.dumps({"v": 2, "appearance.accent": "sky"}) + "\n")
    tmp.replace(path)
    nested.wait_for(lambda: accent() == "sky", 5)
    path.write_text(json.dumps({"v": 2}) + "\n")
    nested.wait_for(lambda: accent() == "jade", 5)


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


def test_escape_closes_mode(nested: Nested) -> None:
    # Esc reaches the shell through the keyboard focus of the open mode (05 §3), not a bind.
    assert nested.msg("surface", "open", "spotlight") == "ok"
    mon = nested.state()["global"]["activeMonitor"]
    nested.wait_for(lambda: nested.state()["monitors"][mon]["keyboard"] is True)
    time.sleep(0.2)                                            # the layer takes the keyboard focus
    nested.key("Escape")
    nested.wait_for(lambda: nested.state()["monitors"][mon]["notch"] == "rest", 3)


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
    assert errs is not None, "hyprctl configerrors -j gave no JSON"
    assert all(not e for e in errs), errs


def test_no_deprecated_config(nested: Nested) -> None:
    # A deprecated option shows a notification on every start of Lenno's session.
    assert nested.hyprctl("deprecated-config").strip() == "all good!"


def test_screenshot(nested: Nested) -> None:
    out = nested.screenshot(nested.root / "s1.png")
    assert out.stat().st_size > 1000


def test_wallpaper_next_keeps_monitor_images(nested: Nested) -> None:
    # `wallpaper next` changes `all` only; a monitor's own image stays (wallpaper.md §6).
    from nested import write_test_png
    walls = nested.home / "Pictures" / "Wallpapers"
    write_test_png(walls / "second.png", 320, 180)
    state = nested.paths.state / "wallpaper.json"
    mon = nested.state()["global"]["activeMonitor"]
    own = str(walls / "test.png")
    assert nested.msg("wallpaper", "set", own, mon) == "ok"
    nested.wait_for(lambda: state.exists() and json.loads(state.read_text()).get("monitors", {}).get(mon) == own)
    assert nested.msg("wallpaper", "next") == "ok"
    nested.wait_for(lambda: json.loads(state.read_text()).get("all"))
    st = json.loads(state.read_text())
    assert st["monitors"] == {mon: own}
    assert st["all"] in (own, str(walls / "second.png"))


def test_shell_restart(nested: Nested) -> None:
    # `shell restart` writes the flag, quits, and the supervisor starts the shell at once (07 §10).
    from nested import test_processes

    def shells() -> set[int]:
        out = set()
        for pid in test_processes(nested.home):
            try:
                if Path(f"/proc/{pid}/comm").read_text().strip() in ("qs", "quickshell"):
                    out.add(pid)
            except OSError:
                pass
        return out

    before = shells()
    assert before
    assert nested.msg("shell", "restart") == "ok"
    nested.wait_for(lambda: shells() and not (shells() & before), 10)

    def answers() -> bool:
        try:
            return nested.state()["services"]["config"]["loaded"]
        except Exception:
            return False
    nested.wait_for(answers, 10)
    assert not nested.paths.restart_flag.exists()   # the supervisor took it
