"""`aptus doctor isolation` (02 §10): each of the eight checks passes on a clean world and fails
(or warns) on the case it exists for. Temporary HOME, fake tools, a fake Hyprland."""
from __future__ import annotations

import json
import os
import shutil
import subprocess
from datetime import datetime
from pathlib import Path

import pytest

import s2_fakes as fakes
from aptus import doctor
from aptus import paths as paths_mod
from aptus.doctor import isolation
from aptus.lease import ops
from aptus.lease.journal import SlotKind
from aptus.lease.kinds import dconf
from aptus.lease.slots import SlotSpec

KEY = dconf.KEY_DIR


@pytest.fixture
def p(test_home: Path, monkeypatch: pytest.MonkeyPatch) -> paths_mod.Paths:
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(test_home / "r"))
    (test_home / "r").mkdir()
    fakes.systemctl(test_home)
    return paths_mod.get()


@pytest.fixture
def hypr(p, test_home, tmp_path):
    h = fakes.hyprland(test_home, tmp_path)
    yield h
    h.kill()


def gtk(p) -> Path:
    f = p.config_home / "gtk-3.0/noctalia.css"
    f.parent.mkdir(parents=True, exist_ok=True)
    if not f.exists():
        f.write_text("noctalia\n")
    return f


def take(p, hypr) -> None:
    fakes.one_session(p.home)
    fakes.dconf(p.home, {KEY + "color-scheme": "'prefer-light'"})
    specs = [SlotSpec(id="gtk3.artifact", kind=SlotKind.FILE, target="gtk3", path=gtk(p),
                      content=b"aptus\n"),
             SlotSpec(id="dconf.color-scheme", kind=SlotKind.DCONF, target="dconf",
                      key=KEY + "color-scheme", value="'prefer-dark'")]
    assert ops.take(p, hypr.env, specs, ops.owner(p, hypr.env), 1).held


def by_name(p) -> dict[str, doctor.Check]:
    return {c.name.split(".", 1)[1]: c for c in isolation.check(p)}


def spawn(tmp_path: Path, name: str, env: dict[str, str]) -> subprocess.Popen:
    exe = tmp_path / "fakebin" / name
    exe.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(shutil.which("sleep"), exe)
    return subprocess.Popen([str(exe), "600"], env=env)


def test_clean_world_passes(p) -> None:
    checks = by_name(p)
    assert list(checks) == ["journal", "slots", "environment", "units", "umbriel", "coverage",
                            "traps", "untouched"]
    assert all(c.ok for c in checks.values()), checks
    assert checks["untouched"].warn                               # no baseline yet
    assert p.doctor_stamp.is_file()                               # the doctor's only write


def test_cli_exit_codes(p, capsys) -> None:
    assert doctor.main(["isolation"]) == 0
    p.lease.mkdir(parents=True)
    p.lease_journal.write_text("{broken")
    assert doctor.main(["isolation"]) == 1
    assert "FAIL isolation.journal" in capsys.readouterr().out


def test_journal(p, hypr) -> None:
    take(p, hypr)
    assert by_name(p)["journal"].ok                               # held by a live owner
    hypr.kill()
    c = by_name(p)["journal"]
    assert not c.ok and "aptus-lease recover" in c.detail
    ops.recover(p)
    assert by_name(p)["journal"].ok


def test_slots(p, hypr) -> None:
    take(p, hypr)
    assert "held" in by_name(p)["slots"].detail
    ops.release(p)
    assert by_name(p)["slots"].ok
    f = gtk(p)
    f.write_text("someone else\n")
    old = datetime(2020, 1, 1).timestamp()
    os.utime(f, (old, old))                                       # changed, but not after the release
    c = by_name(p)["slots"]
    assert not c.ok and "differs" in c.detail
    os.utime(f, None)                                             # written after the release: Noctalia
    assert by_name(p)["slots"].ok
    fakes.dconf(p.home, {KEY + "color-scheme": "'prefer-dark'"})
    c = by_name(p)["slots"]
    assert c.ok and c.warn and "color-scheme" in c.detail


def test_slots_new_conflicts_warn(p) -> None:
    isolation.check(p)                                            # stamp now
    (p.lease_conflicts / "20991231T000000").mkdir(parents=True)
    os.utime(p.lease_conflicts / "20991231T000000", (4e9, 4e9))
    c = by_name(p)["slots"]
    assert c.ok and c.warn and "conflicts" in c.detail


def set_env(p, env: dict[str, str]) -> None:
    (p.home / ".aptus-test/systemctl.json").write_text(json.dumps({"env": env}))


def test_environment(p, hypr) -> None:
    set_env(p, {"PATH": "/usr/bin", "XCURSOR_THEME": "Breeze"})
    assert by_name(p)["environment"].ok                           # not aptus's value
    set_env(p, {"QT_QPA_PLATFORMTHEME": "qt6ct", "XCURSOR_THEME": "Adwaita"})
    c = by_name(p)["environment"]
    assert not c.ok and "QT_QPA_PLATFORMTHEME, XCURSOR_THEME" in c.detail
    take(p, hypr)
    assert by_name(p)["environment"].ok                           # the lease is held
    (p.home / ".aptus-test/bin/systemctl").unlink()
    c = by_name(p)["environment"]
    assert c.ok and c.warn


def test_units(p, tmp_path) -> None:
    unit = spawn(tmp_path, "aptus-guard", {"HOME": str(p.home)})
    try:
        (p.home / ".aptus-test/systemd-run.json").write_text(json.dumps({"units": {"aptus-guard": unit.pid}}))
        c = by_name(p)["units"]
        assert not c.ok and "aptus-guard.service" in c.detail
        h = fakes.hyprland(p.home, tmp_path, "doctor-sig")
        try:
            assert by_name(p)["units"].ok                         # Hyprland runs
        finally:
            h.kill()
    finally:
        unit.kill()
        unit.wait(5)


def test_umbriel(p, tmp_path) -> None:
    p.umbriel_config.mkdir(parents=True)
    (p.umbriel_config / "env.conf").write_text("GTK_THEME=x\n")
    assert by_name(p)["umbriel"].ok
    (p.umbriel_config / "env.conf").write_text("QT_QPA_PLATFORMTHEME=qt6ct\n")
    assert not by_name(p)["umbriel"].ok
    clean = spawn(tmp_path, "umbriel", {"HOME": str(p.home)})
    try:
        assert by_name(p)["umbriel"].ok                           # the running one decides
    finally:
        clean.kill()
        clean.wait(5)
    dirty = spawn(tmp_path, "umbriel", {"HOME": str(p.home), "QT_QPA_PLATFORMTHEME": "qt6ct"})
    try:
        c = by_name(p)["umbriel"]
        assert not c.ok and str(dirty.pid) in c.detail
    finally:
        dirty.kill()
        dirty.wait(5)


def test_coverage(p) -> None:
    p.noctalia_config.mkdir(parents=True)
    (p.noctalia_config / "a.toml").write_text('[theme.templates]\nbuiltin_ids = ["gtk3", "kitty", "brave", "sway"]\n')
    c = by_name(p)["coverage"]
    assert c.ok and "Noctalia's: brave" in c.detail
    (p.noctalia_config / "a.toml").write_text('[theme.templates]\nbuiltin_ids = ["gtk3", "emacs"]\n')
    c = by_name(p)["coverage"]
    assert not c.ok and c.detail == "uncovered: emacs"


def test_traps(p) -> None:
    (p.system_themes / "Adwaita").mkdir(parents=True)
    assert by_name(p)["traps"].ok
    (p.user_themes / "adw-gtk3-dark").mkdir(parents=True)
    assert not by_name(p)["traps"].ok
    shutil.rmtree(p.user_themes)
    p.fonts.mkdir(parents=True)
    (p.fonts / "Lenno.ttf").write_text("x")
    isolation.save_baseline(p, isolation.record_baseline(p))
    assert by_name(p)["traps"].ok
    (p.fonts / "New.otf").write_text("x")
    c = by_name(p)["traps"]
    assert c.ok and c.warn and "New.otf" in c.detail
    (p.fonts / "MaterialSymbolsRounded.ttf").write_text("x")     # aptus's own font
    assert not by_name(p)["traps"].ok


def test_untouched(p, hypr) -> None:
    p.umbriel_config.mkdir(parents=True)
    (p.umbriel_config / "noctalia.toml").write_text("a = 1\n")
    p.greetd_config.parent.mkdir(parents=True)
    p.greetd_config.write_text("[default_session]\n")
    isolation.save_baseline(p, isolation.record_baseline(p))
    assert by_name(p)["untouched"].detail == "unchanged since install"
    (p.umbriel_config / "noctalia.toml").write_text("a = 2\n")   # Lenno, outside any lease
    c = by_name(p)["untouched"]
    assert c.ok and "changed outside aptus" in c.detail
    take(p, hypr)
    ops.release(p)
    (start, _), = isolation.lease_periods(p)
    p.greetd_config.write_text("[changed]\n")
    os.utime(p.greetd_config, (start, start))                    # during the lease
    c = by_name(p)["untouched"]
    assert not c.ok and str(p.greetd_config) in c.detail


def test_baseline_round_trip(p) -> None:
    assert isolation.load_baseline(p) is None
    b = isolation.record_baseline(p)
    assert b.files[str(p.greetd_config)] == {"missing": True}
    isolation.save_baseline(p, b)
    assert isolation.load_baseline(p) == b
    p.baseline.write_text("[]")
    assert isolation.load_baseline(p) is None


def test_journal_half_released_by_a_live_owner(p, hypr) -> None:
    take(p, hypr)
    from aptus.lease import journal
    from aptus.lease.journal import State
    j = journal.load(p)
    j.state = State.RELEASING
    journal.save(p, j)
    c = by_name(p)["journal"]
    assert not c.ok and "the guard retries" in c.detail and "recover" not in c.detail
