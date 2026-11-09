"""The lease (02 §5): kinds, journal, take/update/release/recover, preflight. Everything runs in the
temporary HOME with fake tools in $HOME/.aptus-test/bin and a fake Hyprland owner."""
from __future__ import annotations

import fcntl
import hashlib
import json
import os
import random
from pathlib import Path

import pytest

import s2_fakes as fakes
from aptus import paths as paths_mod
from aptus.lease import journal, ops, preflight
from aptus.lease.journal import Journal, JournalError, Owner, SlotKind, SlotStatus, State
from aptus.lease.kinds import dconf, ini
from aptus.lease.slots import SlotSpec

KEY = dconf.KEY_DIR
KDE = """[General]
ColorScheme=Noctalia
font=Inter,11

[Colors:View]
BackgroundNormal=1,1,1
ForegroundNormal=2,2,2

[KDE]
widgetStyle=Breeze

[WM]
activeBackground=3,3,3
"""
RENDERED_KDE = "[Colors:View]\nBackgroundNormal=9,9,9\n\n[Colors:Window]\nBackgroundNormal=8,8,8\n\n[WM]\nactiveBackground=7,7,7\n"


@pytest.fixture
def p(test_home: Path, monkeypatch: pytest.MonkeyPatch) -> paths_mod.Paths:
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(test_home / "r"))
    (test_home / "r").mkdir()
    return paths_mod.get()


@pytest.fixture
def hypr(p, test_home, tmp_path):
    h = fakes.hyprland(test_home, tmp_path)
    yield h
    h.kill()


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def slot_files(p) -> dict[str, Path]:
    """Noctalia's artifacts in the temporary HOME, as Noctalia left them."""
    f = {
        "gtk": p.config_home / "gtk-3.0/noctalia.css",
        "ghostty": p.config_home / "ghostty/themes/noctalia",
        "kde": p.config_home / "kdeglobals",
    }
    f["gtk"].parent.mkdir(parents=True)
    f["gtk"].write_text("@define-color accent_color #ff0000;\n")
    f["gtk"].chmod(0o640)
    f["ghostty"].parent.mkdir(parents=True)
    f["ghostty"].write_text("background = 101010\n")
    f["kde"].write_text(KDE)
    (p.config_home / "btop/themes").mkdir(parents=True)      # a slot aptus creates
    return f


def specs(p) -> list[SlotSpec]:
    return [
        SlotSpec(id="gtk3.artifact", kind=SlotKind.FILE, target="gtk3", reload="none",
                 path=p.config_home / "gtk-3.0/noctalia.css", content=b"@define-color accent_color #00ff00;\n"),
        SlotSpec(id="ghostty.artifact", kind=SlotKind.FILE, target="ghostty",
                 reload="signal:ghostty:SIGUSR2", path=p.config_home / "ghostty/themes/noctalia",
                 content=b"background = 202020\n"),
        SlotSpec(id="btop.artifact", kind=SlotKind.FILE, target="btop",
                 path=p.config_home / "btop/themes/noctalia.theme", content=b"theme[main_bg]=\"#000\"\n"),
        SlotSpec(id="missing.artifact", kind=SlotKind.FILE, target="missing",
                 path=p.config_home / "nowhere/x.conf", content=b"x"),
        SlotSpec(id="kde.colors", kind=SlotKind.INI, target="kde", reload="builtin:kde",
                 path=p.config_home / "kdeglobals", content=RENDERED_KDE.encode(),
                 sections=("Colors:*", "ColorEffects:*", "WM")),
        SlotSpec(id="dconf.color-scheme", kind=SlotKind.DCONF, target="dconf",
                 key=KEY + "color-scheme", value="'prefer-dark'"),
        SlotSpec(id="dconf.accent-color", kind=SlotKind.DCONF, target="dconf",
                 key=KEY + "accent-color", value="'teal'"),
        SlotSpec(id="dconf.gtk-theme", kind=SlotKind.DCONF, target="dconf", key=KEY + "gtk-theme"),
    ]


def baseline(p, files) -> dict:
    return {"files": {k: sha(v) for k, v in files.items()},
            "btop": (p.config_home / "btop/themes/noctalia.theme").exists(),
            "dconf": fakes.dconf_db(p.home)}


def setup_world(p, test_home):
    files = slot_files(p)
    fakes.dconf(test_home, {KEY + "color-scheme": "'prefer-light'", KEY + "gtk-theme": "'Adwaita'"})
    fakes.one_session(test_home)
    return files


def take(p, hypr, gen=1, sp=None):
    who = ops.owner(p, hypr.env)
    return ops.take(p, hypr.env, sp if sp is not None else specs(p), who, gen)


# --- the round trip -------------------------------------------------------------------------

def test_take_then_release_gives_every_byte_back(p, test_home, hypr) -> None:
    files = setup_world(p, test_home)
    base = baseline(p, files)
    r = take(p, hypr)
    assert r.held and not r.error, r
    assert r.skipped == ["missing.artifact"]
    assert files["gtk"].read_bytes() == b"@define-color accent_color #00ff00;\n"
    assert oct(files["gtk"].stat().st_mode & 0o777) == "0o640"
    assert "BackgroundNormal=9,9,9" in files["kde"].read_text()
    assert "widgetStyle=Breeze" in files["kde"].read_text()
    assert (p.config_home / "btop/themes/noctalia.theme").exists()
    db = fakes.dconf_db(test_home)
    assert db[KEY + "color-scheme"] == "'prefer-dark'" and db[KEY + "gtk-theme"] == "'Adwaita'"
    assert journal.load(p).state == State.HELD
    assert ops.held_by(p, hypr.signature, hypr.pid)

    rel = ops.release(p, expect=(hypr.signature, hypr.pid))
    assert rel.acted and not rel.failed and not rel.conflicts
    assert baseline(p, files) == base
    assert journal.load(p) is None
    assert rel.reloads == {"ghostty": "signal:ghostty:SIGUSR2", "kde": "builtin:kde"}
    hist = journal.last_released(p)
    assert hist.state == State.RELEASED and hist.released_at
    assert not list(p.lease_slots.glob("*.before"))


def test_release_of_another_owner_does_nothing(p, test_home, hypr) -> None:
    setup_world(p, test_home)
    take(p, hypr)
    assert not ops.release(p, expect=("other", hypr.pid)).acted
    assert not ops.release(p, expect=(hypr.signature, 1)).acted
    assert journal.load(p).state == State.HELD


def test_update_keeps_before_and_release_restores_it(p, test_home, hypr) -> None:
    files = setup_world(p, test_home)
    base = baseline(p, files)
    take(p, hypr)
    new = [SlotSpec(id="gtk3.artifact", kind=SlotKind.FILE, target="gtk3",
                    path=files["gtk"], content=b"gen 2\n"),
           SlotSpec(id="dconf.gtk-theme", kind=SlotKind.DCONF, target="dconf", key=KEY + "gtk-theme")]
    u = ops.update(p, new, 2)
    assert u.written == ["gtk3.artifact"] and not u.failed
    assert files["gtk"].read_bytes() == b"gen 2\n"
    j = journal.load(p)
    assert j.theme_generation == 2 and journal.slot(j, "gtk3.artifact").after_prev is None
    ops.release(p)
    assert baseline(p, files) == base


def test_crash_mid_update_is_still_aptus_paint(p, test_home, hypr) -> None:
    """A crash after the write but before the journal knew: after_prev/after both count as ours,
    so release restores without a conflict."""
    files = setup_world(p, test_home)
    base = baseline(p, files)
    take(p, hypr)
    j = journal.load(p)
    rec = journal.slot(j, "gtk3.artifact")
    rec.after_prev, rec.after = rec.after, {"sha256": hashlib.sha256(b"gen 2\n").hexdigest()}
    journal.save(p, j)
    files["gtk"].write_bytes(b"gen 2\n")
    rel = ops.release(p)
    assert not rel.conflicts and baseline(p, files) == base


def test_conflict_is_saved_and_before_restored(p, test_home, hypr) -> None:
    files = setup_world(p, test_home)
    base = baseline(p, files)
    take(p, hypr)
    files["ghostty"].write_text("someone else\n")
    rel = ops.release(p)
    assert rel.conflicts == ["ghostty.artifact"]
    saved = list(p.lease_conflicts.glob("*/ghostty.artifact"))
    assert len(saved) == 1 and saved[0].read_text() == "someone else\n"
    assert baseline(p, files) == base


def test_kde_writes_during_the_lease_survive(p, test_home, hypr) -> None:
    files = setup_world(p, test_home)
    take(p, hypr)
    files["kde"].write_text(files["kde"].read_text().replace("widgetStyle=Breeze", "widgetStyle=Fusion"))
    ops.release(p)
    text = files["kde"].read_text()
    assert "widgetStyle=Fusion" in text and "BackgroundNormal=1,1,1" in text
    assert "Colors:Window" not in text


def test_symlinked_slot_is_written_through(p, test_home, hypr) -> None:
    setup_world(p, test_home)
    real = p.home / "dotfiles/ghostty/noctalia"
    real.parent.mkdir(parents=True)
    real.write_text("background = 111111\n")
    link = p.config_home / "ghostty/themes/noctalia"
    link.unlink()
    link.symlink_to(real)
    take(p, hypr)
    assert link.is_symlink() and real.read_text() == "background = 202020\n"
    ops.release(p)
    assert link.is_symlink() and real.read_text() == "background = 111111\n"


def test_failure_mid_take_releases_what_was_taken(p, test_home, hypr, monkeypatch) -> None:
    files = setup_world(p, test_home)
    base = baseline(p, files)
    from aptus.lease.kinds import file as file_kind
    real_write = file_kind.write

    def boom(paths, rec, spec):
        if rec.id == "ghostty.artifact":
            raise OSError("disk full")
        return real_write(paths, rec, spec)
    monkeypatch.setattr(file_kind, "write", boom)
    r = take(p, hypr)
    assert not r.held and "disk full" in r.error
    assert journal.load(p) is None
    assert baseline(p, files) == base


# --- preflight ---------------------------------------------------------------------------------

def test_other_session_open_takes_nothing(p, test_home, hypr) -> None:
    files = setup_world(p, test_home)
    base = baseline(p, files)
    fakes.one_session(test_home, "2", {"Id": "5", "Class": "user", "Type": "wayland",
                                       "State": "online", "Desktop": "Umbriel"})
    r = take(p, hypr)
    assert not r.held and not r.preflight.ok
    assert r.preflight.reasons == [preflight.REASON_OTHER_SESSION]
    assert r.preflight.notice == preflight.NOTICE_OTHER_SESSION
    assert journal.load(p) is None and baseline(p, files) == base


def test_greeter_tty_and_manager_sessions_do_not_count(p, test_home, hypr) -> None:
    setup_world(p, test_home)
    fakes.one_session(test_home, "2",
                      {"Id": "1", "Class": "greeter", "Type": "wayland", "State": "online"},
                      {"Id": "3", "Class": "manager", "Type": "unspecified", "State": "active"},
                      {"Id": "4", "Class": "user", "Type": "tty", "State": "online"},
                      {"Id": "6", "Class": "user", "Type": "wayland", "State": "closing"})
    assert take(p, hypr).held


def test_no_loginctl_fails_closed(p, test_home, hypr) -> None:
    setup_world(p, test_home)
    (test_home / ".aptus-test/bin/loginctl").unlink()
    r = take(p, hypr)
    assert not r.held and r.preflight.reasons == [preflight.REASON_UNKNOWN]


def test_running_noctalia_takes_nothing(p, test_home, hypr, tmp_path) -> None:
    import shutil
    import subprocess
    setup_world(p, test_home)
    exe = tmp_path / "fakebin/noctalia"
    shutil.copy(shutil.which("sleep"), exe)
    proc = subprocess.Popen([str(exe), "60"], env={"HOME": str(test_home)})
    try:
        r = take(p, hypr)
        assert not r.held and r.preflight.reasons == [preflight.REASON_NOCTALIA]
        assert r.preflight.noctalia == [proc.pid]
    finally:
        proc.kill()
        proc.wait()


# --- recover ---------------------------------------------------------------------------------

def test_recover_after_the_owner_died(p, test_home, hypr) -> None:
    files = setup_world(p, test_home)
    base = baseline(p, files)
    take(p, hypr)
    assert not ops.recover(p).acted                     # alive: nothing
    hypr.kill()                                         # SIGKILL: no guard ran
    rel = ops.recover(p)
    assert rel.acted and not rel.failed
    assert baseline(p, files) == base and journal.load(p) is None


def test_recover_other_boot(p, test_home, hypr) -> None:
    files = setup_world(p, test_home)
    base = baseline(p, files)
    take(p, hypr)
    j = journal.load(p)
    j.owner.boot_id = "an-earlier-boot"                 # a power loss: the next boot recovers
    journal.save(p, j)
    assert ops.recover(p).acted
    assert baseline(p, files) == base


def test_take_recovers_a_dead_lease_first(p, test_home, hypr, tmp_path) -> None:
    files = setup_world(p, test_home)
    base = baseline(p, files)
    take(p, hypr)
    hypr.kill()
    h2 = fakes.hyprland(test_home, tmp_path, "second-sig")
    try:
        r = take(p, h2)
        assert r.held
        j = journal.load(p)
        assert j.owner.hyprland_signature == "second-sig"
        # the before recorded now is Noctalia's original, not aptus's paint
        assert journal.slot(j, "gtk3.artifact").before["sha256"] == base["files"]["gtk"]
    finally:
        h2.kill()


def test_take_refuses_while_a_live_owner_holds(p, test_home, hypr, tmp_path) -> None:
    setup_world(p, test_home)
    take(p, hypr)
    h2 = fakes.hyprland(test_home, tmp_path, "second-sig")
    try:
        with pytest.raises(ops.LeaseError, match="still there"):
            take(p, h2)
    finally:
        h2.kill()


def test_unparsable_journal_is_left_for_a_human(p, test_home, hypr) -> None:
    setup_world(p, test_home)
    p.lease.mkdir(parents=True)
    p.lease_journal.write_text("{ not json")
    with pytest.raises(JournalError):
        ops.recover(p)
    with pytest.raises(ops.LeaseError, match="does not parse"):
        take(p, hypr)
    assert p.lease_journal.read_text() == "{ not json"


def test_failed_restore_stays_releasing_and_recover_retries(p, test_home, hypr, monkeypatch) -> None:
    files = setup_world(p, test_home)
    base = baseline(p, files)
    take(p, hypr)
    hypr.kill()
    from aptus.lease.kinds import file as file_kind
    real = file_kind.restore
    monkeypatch.setattr(file_kind, "restore", lambda *a: (_ for _ in ()).throw(OSError("busy")))
    rel = ops.recover(p)
    assert set(rel.failed) == {"gtk3.artifact", "ghostty.artifact", "btop.artifact"}
    j = journal.load(p)
    assert j.state == State.RELEASING
    assert ops.status(p).failed == sorted(rel.failed) or set(ops.status(p).failed) == set(rel.failed)
    monkeypatch.setattr(file_kind, "restore", real)
    rel = ops.recover(p)
    assert not rel.failed and baseline(p, files) == base and journal.load(p) is None


def test_corrupt_before_copy_is_never_written(p, test_home, hypr) -> None:
    files = setup_world(p, test_home)
    take(p, hypr)
    journal.before_file(p, "gtk3.artifact").write_bytes(b"garbage")
    rel = ops.release(p)
    assert "gtk3.artifact" in rel.failed
    assert files["gtk"].read_bytes() == b"@define-color accent_color #00ff00;\n"


# --- journal, lock ----------------------------------------------------------------------------

def test_journal_round_trip(p) -> None:
    j = Journal(state=State.HELD, owner=Owner("b", 1, "s", "2", "t"), theme_generation=3)
    assert journal.from_dict(json.loads(json.dumps(journal.to_dict(j)))) == j
    with pytest.raises(JournalError):
        journal.from_dict({"version": 2})
    with pytest.raises(JournalError):
        journal.from_dict({"version": 1, "state": "weird"})


def test_history_keeps_ten(p) -> None:
    for _ in range(13):
        j = Journal(state=State.RELEASED, released_at="t")
        journal.archive(p, j)
    assert len(list(p.lease_history.glob("*.json"))) == journal.HISTORY_KEEP


def test_lock_is_reentrant_and_times_out(p) -> None:
    with ops.lock(p):
        with ops.lock(p):
            pass
    p.lease.mkdir(parents=True, exist_ok=True)
    fd = os.open(p.lease_lock, os.O_RDWR | os.O_CREAT)
    fcntl.flock(fd, fcntl.LOCK_EX)
    try:
        with pytest.raises(ops.LeaseError, match="busy"):
            with ops.lock(p, timeout=0.2):
                pass
    finally:
        os.close(fd)


def test_owner_refuses_a_non_hyprland_pid(p, test_home, hypr) -> None:
    (p.hypr_runtime / hypr.signature / "hyprland.lock").write_text(f"{os.getpid()}\n")
    with pytest.raises(ops.LeaseError, match="not Hyprland"):
        ops.owner(p, hypr.env)


def test_owner_refuses_the_real_session(p, hypr) -> None:
    env = dict(hypr.env, HYPRLAND_INSTANCE_SIGNATURE=os.environ["APTUS_REAL_HYPRLAND_SIGNATURE"])
    with pytest.raises(ops.LeaseError):
        ops.owner(p, env)


# --- kinds ------------------------------------------------------------------------------------

def test_dconf_restore_resets_an_unset_key(p, test_home, hypr) -> None:
    setup_world(p, test_home)
    take(p, hypr)
    assert fakes.dconf_db(test_home)[KEY + "accent-color"] == "'teal'"
    ops.release(p)
    assert KEY + "accent-color" not in fakes.dconf_db(test_home)
    assert ["dconf", "reset", KEY + "accent-color"] in fakes.calls(test_home, "dconf")
    assert not [c for c in fakes.calls(test_home, "dconf") if c[1] in ("write", "reset")
                and c[2] == KEY + "gtk-theme"]


def _random_ini(rng: random.Random) -> str:
    names = ["General", "KDE", "Icons", "Colors:View", "Colors:Window", "ColorEffects:Disabled",
             "WM", "Colors:Header][Inactive", "Other"]
    out = ["# preamble\n"] if rng.random() < 0.5 else []
    for n in rng.sample(names, rng.randint(0, len(names))):
        out.append(f"[{n}]\n" + "".join(f"k{i}={rng.randint(0, 9)}\n" for i in range(rng.randint(0, 3))))
        if rng.random() < 0.2:
            out.append("\n")
    t = "".join(out)
    return t.rstrip("\n") if t and rng.random() < 0.3 else t


def test_ini_round_trip_on_random_files(p) -> None:
    """Take then restore gives the original bytes; planned equals the digest after write."""
    rng = random.Random(7)
    target = p.config_home / "kdeglobals"
    target.parent.mkdir(parents=True)
    globs = ("Colors:*", "ColorEffects:*", "WM")
    for i in range(400):
        original, rendered = _random_ini(rng), _random_ini(rng) or "[WM]\nx=1\n"
        target.write_text(original)
        rec = journal.SlotRecord(id="kde.colors", kind=SlotKind.INI, target="kde",
                                 path=str(target), write_path=str(target), sections=list(globs))
        spec = SlotSpec(id="kde.colors", kind=SlotKind.INI, target="kde", path=target,
                        content=rendered.encode(), sections=globs)
        rec.before = ini.read(p, rec).record
        assert ini.write(p, rec, spec) == ini.planned(spec), i
        ini.restore(p, rec, None)
        assert target.read_text() == original, i
        assert ini.digest(p, rec) == ini.before_digest(rec.before)


def test_ini_created_file_removed_again(p) -> None:
    target = p.config_home / "kdeglobals"
    target.parent.mkdir(parents=True)
    rec = journal.SlotRecord(id="kde.colors", kind=SlotKind.INI, target="kde", path=str(target),
                             write_path=str(target), sections=["WM"])
    rec.before = ini.read(p, rec).record
    assert rec.before == {"exists": False, "link": "", "sections": []}
    spec = SlotSpec(id="kde.colors", kind=SlotKind.INI, target="kde", path=target,
                    content=b"[WM]\na=1\n", sections=("WM",))
    ini.write(p, rec, spec)
    ini.restore(p, rec, None)
    assert not target.exists()
    ini.write(p, rec, spec)
    target.write_text(target.read_text() + "[General]\nb=2\n")      # KDE wrote meanwhile
    ini.restore(p, rec, None)
    assert target.read_text() == "[General]\nb=2\n"
    assert ini.digest(p, rec) == ini.before_digest(rec.before)


def test_status(p, test_home, hypr) -> None:
    assert ops.status(p).state is None
    setup_world(p, test_home)
    take(p, hypr, gen=4)
    s = ops.status(p)
    assert (s.state, s.owner_alive, s.generation, s.slots, s.failed) == (State.HELD, True, 4, 7, [])
    assert s.owner.hyprland_pid == hypr.pid
    assert SlotStatus.HELD
