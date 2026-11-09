"""aptus doctor config and deps."""
from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

import pytest

from aptus import doctor
from aptus.doctor import config as dconfig, deps
from aptus.paths import get

REPO = Path(__file__).resolve().parents[2]


def write_settings(data: object) -> None:
    p = get().settings
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(data if isinstance(data, str) else json.dumps(data), encoding="utf-8")


def failures(checks: list[doctor.Check]) -> list[doctor.Check]:
    return [c for c in checks if not c.ok]


def test_config_ok() -> None:
    assert [c.ok for c in dconfig.check(get())] == [True]       # absent: defaults
    write_settings({"v": 2, "appearance.mode": "light", "bar.tray.max": 4,
                    "idle.dimAfter": 120, "jot.file": "~/Notes/x.md"})
    checks = dconfig.check(get())
    assert failures(checks) == []
    assert "4 value(s)" in checks[0].detail
    assert doctor.main(["config"]) == 0


def test_config_v1_ignored() -> None:
    write_settings({"theme": "dark", "barHeight": 30})            # no "v": a v1 file
    checks = dconfig.check(get())
    assert len(checks) == 1 and checks[0].ok and checks[0].warn
    assert "v1" in checks[0].detail
    assert doctor.main(["config"]) == 0
    write_settings({"v": 3})
    assert failures(dconfig.check(get()))


def test_config_bad_value(capsys: pytest.CaptureFixture[str]) -> None:
    write_settings({"v": 2, "appearance.mode": "purple", "bar.tray.max": 99,
                    "bar.height": 40, "nonsense.key": 1, "focus.default": 33,
                    "idle.dimAfter": 600, "idle.lockAfter": 300})
    checks = dconfig.check(get())
    bad = {c.name for c in failures(checks)}
    assert {"config: appearance.mode", "config: bar.tray.max", "config: bar.height",
            "config: focus.default", "config: idle.lockAfter"} <= bad
    unknown = next(c for c in checks if c.name == "config: nonsense.key")
    assert unknown.ok and unknown.warn
    assert doctor.main(["config"]) == 1
    out = capsys.readouterr().out
    assert "FAIL config: appearance.mode: must be one of dark, light, auto" in out
    # A syntax error names line and column.
    write_settings('{\n  "v": 2,\n  "x": }\n')
    (c,) = dconfig.check(get())
    assert not c.ok and "line 3" in c.detail and "column" in c.detail


def test_deps_lists_missing(monkeypatch: pytest.MonkeyPatch) -> None:
    present = {"qs", "Hyprland", "hyprctl", "journalctl", "rpm", "fc-list"}
    monkeypatch.setattr(shutil, "which", lambda c: f"/usr/bin/{c}" if c in present else None)

    def fake_run(cmd, *a, **kw):                    # type: ignore[no-untyped-def]
        if cmd[0] == "rpm":                          # mako is installed, nothing else
            out = "".join("mako\n" if p == "mako" else f"package {p} is not installed\n" for p in cmd[4:])
            return subprocess.CompletedProcess(cmd, len(cmd) - 5, out, "")
        return subprocess.CompletedProcess(cmd, 0, "Inter\nJetBrains Mono,JetBrains Mono NL\n", "")

    monkeypatch.setattr(subprocess, "run", fake_run)
    checks = {c.name: c for c in deps.check()}
    assert checks["deps: qs"].ok and checks["deps: hyprctl"].ok
    assert not checks["deps: hyprlock"].ok and "missing" in checks["deps: hyprlock"].detail
    assert not checks["deps: cliphist"].ok
    assert checks["deps: ddcutil"].ok and checks["deps: ddcutil"].warn     # optional
    assert not checks["deps: no mako"].ok and checks["deps: no dunst"].ok
    assert checks["deps: font Inter"].ok and checks["deps: font JetBrains Mono"].ok
    assert not checks["deps: font Inter Display"].ok
    text = doctor.render(deps.check())
    assert "FAIL deps: hyprlock: missing (lock fallback)" in text
    assert "ok   deps: qs" in text
    assert "warn deps: ddcutil" in text
    unknown = doctor.run(["nope"], get())
    assert not unknown[0].ok


def test_messages_match_the_shell() -> None:
    # The shared case list; tests/qml/tst_config.qml checks config.js against the same file.
    cases = json.loads((REPO / "tests" / "fixtures" / "validate-cases.json").read_text(encoding="utf-8"))
    schema = json.loads((REPO / "shell" / "config" / "settings-schema.json").read_text(encoding="utf-8"))
    for key, value, message in cases["cases"]:
        assert dconfig.validate(schema, key, value, cases["home"]) == message, (key, value)


def test_cross_rules_match_the_shell() -> None:
    # The shared cross-rule cases; tests/qml/tst_config.qml checks crossCheck against them.
    cases = json.loads((REPO / "tests" / "fixtures" / "validate-cases.json").read_text(encoding="utf-8"))
    schema = json.loads((REPO / "shell" / "config" / "settings-schema.json").read_text(encoding="utf-8"))
    defaults = {k: e["default"] for k, e in schema["keys"].items()}
    for overrides, problems in cases["crossCases"]:
        assert dconfig.cross_check(schema, {**defaults, **overrides}) == [tuple(p) for p in problems], overrides


def test_cross_rule_messages() -> None:
    write_settings({"v": 2, "focus.durations": [30, 60, 120], "idle.dimAfter": 600, "idle.lockAfter": 300})
    detail = {c.name: c.detail for c in failures(dconfig.check(get()))}
    assert detail["config: focus.default"] == "must be one of 30, 60, 120; the default is used"
    assert detail["config: idle.lockAfter"] == "must be later than Dim after; the default is used"
