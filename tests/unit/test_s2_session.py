"""The round trip of 02 §10 through aptus-session, the real aptus-guard and aptus-lease, with
every ending of the 02 §7 exit matrix: logout (aptus-session stop → the guard on SIGTERM), a
Hyprland crash (SIGKILL: the guard's pidfd), a hard power-off (guard and Hyprland gone: recover at
the next login, or aptus-recover.service running `aptus-lease recover`), Umbriel already open
(scope-only and the notch message) and Umbriel logging in mid-session (the guard releases).
All in the temporary HOME: systemd-run, systemctl, loginctl and dconf are fakes, Hyprland is a
process named Hyprland with a socket that answers "ok"."""
from __future__ import annotations

import dataclasses
import json
import os
import shutil
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path

import pytest

import s2_fakes as fakes
from aptus import paths as paths_mod
from aptus import session
from aptus.lease import journal, preflight
from aptus.lease.journal import State
from aptus.lease.kinds import dconf
from aptus.theme import apply, inputs

KEY = dconf.KEY_DIR
REPO = Path(__file__).resolve().parents[2]
ENV_LUA = {"APTUS_SESSION": "1", "QT_QPA_PLATFORMTHEME": "qt6ct", "XCURSOR_THEME": "Adwaita",
           "XCURSOR_SIZE": "24", "HYPRCURSOR_SIZE": "24"}     # what hypr/env.lua sets


@pytest.fixture
def p(test_home: Path, monkeypatch: pytest.MonkeyPatch) -> paths_mod.Paths:
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(test_home / "r"))
    (test_home / "r").mkdir()
    for k, v in ENV_LUA.items():
        monkeypatch.setenv(k, v)
    return paths_mod.get()


@pytest.fixture
def world(p, test_home, tmp_path, monkeypatch):
    """Noctalia's artifacts as Noctalia left them, the fakes, a fake Hyprland; yields
    (hyprland, snapshot()) and stops whatever guard is left at the end."""
    cfg = p.config_home
    files = {cfg / "gtk-3.0/noctalia.css": "@define-color accent_color #ff0000;\n",
             cfg / "ghostty/themes/noctalia": "background = 101010\n",
             cfg / "kdeglobals": "[General]\nColorScheme=Noctalia\n\n[Colors:View]\nBackgroundNormal=1,1,1\n\n[KDE]\nwidgetStyle=Breeze\n"}
    for f, text in files.items():
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(text)
    (cfg / "kitty/themes").mkdir(parents=True)
    (cfg / "kitty/kitty.conf").write_text("include themes/noctalia.conf\n")
    (cfg / "btop/themes").mkdir(parents=True)                     # a slot aptus creates
    fakes.dconf(test_home, {KEY + "color-scheme": "'prefer-light'", KEY + "gtk-theme": "'adw-gtk3'"})
    fakes.one_session(test_home)
    fakes.logind_dir(test_home)
    fakes.systemd_run(test_home)
    fakes.systemctl(test_home)
    h = fakes.hyprland(test_home, tmp_path)
    monkeypatch.setenv("HYPRLAND_INSTANCE_SIGNATURE", h.signature)
    monkeypatch.setenv("XDG_SESSION_ID", "2")

    def snapshot() -> dict:
        out = {str(f): f.read_bytes() for f in files}
        out["btop"] = (cfg / "btop/themes/noctalia.theme").exists()
        out["dconf"] = fakes.dconf_db(test_home)
        return out
    yield h, snapshot
    pid = fakes.unit_pid(test_home)
    if pid and fakes.alive(pid):
        os.kill(pid, signal.SIGKILL)
    h.kill()


def guard_pid(p) -> int:
    pid = fakes.unit_pid(p.home)
    assert pid and fakes.alive(pid), "the guard is not running"
    return pid


def guard_state(p) -> str:
    return p.guard_state.read_text().split("\n")[0] if p.guard_state.exists() else ""


def started(p, h) -> session.StartReport:
    report = session.start(p, h.env)
    assert report.mode is session.Mode.LEASE, report
    assert report.guard and report.generation == 1 and report.warnings == []
    fakes.wait_for(lambda: guard_state(p) == "ok", what="guard.state ok")
    return report


def assert_painted(p) -> None:
    assert "#ff0000" not in (p.config_home / "gtk-3.0/noctalia.css").read_text()
    assert (p.config_home / "btop/themes/noctalia.theme").exists()
    assert fakes.dconf_db(p.home)[KEY + "color-scheme"] == "'prefer-dark'"
    assert fakes.user_env(p.home) == ENV_LUA                      # imported while held


def assert_restored(p, before: dict) -> None:
    assert journal.load(p) is None
    last = journal.last_released(p)
    assert last is not None and last.state == State.RELEASED
    assert all(s.status.value == "restored" for s in last.slots)


def test_logout(p, world) -> None:
    h, snapshot = world
    before = snapshot()
    report = started(p, h)
    assert report.notice == ""
    assert_painted(p)
    assert (p.scope / "kitty/themes/noctalia.conf").is_file()      # scope targets too
    assert session.stop(p) == 0                                   # systemctl stop → SIGTERM
    assert snapshot() == before
    assert_restored(p, before)
    assert guard_state(p) == "released"
    assert fakes.user_env(p.home) == {"XCURSOR_SIZE": "24"}        # only aptus's values unset
    assert not fakes.alive(fakes.unit_pid(p.home))


def test_hyprland_crash(p, world) -> None:
    h, snapshot = world
    before = snapshot()
    started(p, h)
    pid = guard_pid(p)
    h.proc.kill()                                                 # SIGKILL: the pidfd fires
    fakes.wait_for(lambda: not fakes.alive(pid), what="the guard to finish")
    assert snapshot() == before
    assert_restored(p, before)
    assert guard_state(p) == "released"
    assert "Traceback" not in (p.home / ".aptus-test/aptus-guard.log").read_text()


def test_power_loss_then_next_login(p, world, tmp_path, monkeypatch) -> None:
    h, snapshot = world
    before = snapshot()
    started(p, h)
    os.kill(guard_pid(p), signal.SIGKILL)                         # nobody releases
    h.kill()
    assert journal.load(p).state == State.HELD
    assert snapshot() != before
    # the next login: the session's recover step gives everything back before it takes again
    h2 = fakes.hyprland(p.home, tmp_path, "aptus-test-sig-2")
    monkeypatch.setenv("HYPRLAND_INSTANCE_SIGNATURE", h2.signature)
    try:
        report = session.start(p, h2.env)
        assert report.mode is session.Mode.LEASE and report.warnings == []
        history = sorted(p.lease_history.glob("*.json"))
        assert len(history) == 1                                  # the dead session's lease
        assert json.loads(history[0].read_text())["owner"]["hyprland_signature"] == h.signature
        assert session.stop(p) == 0
        assert snapshot() == before
    finally:
        h2.kill()


def test_power_loss_then_recover_unit(p, world) -> None:
    """aptus-recover.service runs `aptus-lease recover` as the user manager starts."""
    h, snapshot = world
    before = snapshot()
    started(p, h)
    os.kill(guard_pid(p), signal.SIGKILL)
    h.kill()
    env = dict(os.environ)
    env.pop("HYPRLAND_INSTANCE_SIGNATURE")                        # the unit has no session
    r = subprocess.run([sys.executable, "-I", str(REPO / "bin/aptus-lease"), "recover"], env=env,
                       capture_output=True, text=True, timeout=60)
    assert r.returncode == 0, r.stderr
    assert snapshot() == before
    assert fakes.user_env(p.home) == {"XCURSOR_SIZE": "24"}
    r = subprocess.run([sys.executable, "-I", str(REPO / "bin/aptus-lease"), "recover"], env=env,
                       capture_output=True, text=True, timeout=60)
    assert r.returncode == 0                                      # nothing to do is fine too


def test_umbriel_open_means_scope_only(p, world) -> None:
    h, snapshot = world
    before = snapshot()
    fakes.one_session(p.home, "2", {"Id": "3", "Class": "user", "Type": "wayland", "State": "online",
                                    "Desktop": "Umbriel"})
    report = session.start(p, h.env)
    assert report.mode is session.Mode.SCOPE_ONLY
    assert report.reasons == [preflight.REASON_OTHER_SESSION]
    assert report.notice == preflight.NOTICE_OTHER_SESSION
    assert snapshot() == before                                   # no leased slot touched
    assert journal.load(p) is None
    assert fakes.user_env(p.home) == {}                           # nothing reached the manager
    assert (p.scope / "kitty/themes/noctalia.conf").is_file()     # scope targets still themed
    session.write_status(p, report)
    status = json.loads(p.session_status.read_text())
    assert status["notice"] == preflight.NOTICE_OTHER_SESSION and status["mode"] == "scope-only"
    assert session.stop(p) == 0
    assert snapshot() == before


def test_umbriel_logs_in_mid_session(p, world) -> None:
    h, snapshot = world
    before = snapshot()
    started(p, h)
    assert_painted(p)
    fakes.one_session(p.home, "2", {"Id": "3", "Class": "user", "Type": "wayland", "State": "online"})
    record = p.logind_user
    record.parent.mkdir(parents=True, exist_ok=True)
    record.write_text("SESSIONS=2 3\n")                            # logind rewrites the user record
    fakes.wait_for(lambda: guard_state(p) == "scope-only", what="the guard to release")
    assert snapshot() == before
    assert p.guard_state.read_text().split("\n")[1] == preflight.NOTICE_OTHER_SESSION
    assert fakes.user_env(p.home) == {"XCURSOR_SIZE": "24"}
    assert fakes.alive(guard_pid(p))                              # it keeps watching
    report = apply.apply(p, inputs.Inputs(mode="light", accent="sky", contrast="normal", glass=True),
                         h.signature)
    assert report.mode == "scope-only" and "gtk3" in report.stays_noctalia
    assert snapshot() == before                                   # a later render leases nothing
    assert session.stop(p) == 0
    assert guard_state(p) == "released"


def slow_guard(monkeypatch: pytest.MonkeyPatch) -> None:
    """The session starts the real guard with POLL an hour: only an inotify event can make it
    look at logind's record (the systemd-run fake runs this instead of bin/aptus-guard)."""
    code = (f"import sys; sys.path.insert(0, {str(REPO / 'lib')!r}); "
            "from aptus.lease import guard; guard.POLL = 3600.0; sys.exit(guard.main(sys.argv[1:]))")
    real_run = session.system.run

    def run(paths, argv, **kw):
        if argv[0] == "systemd-run":
            *flags, _launcher, pid, sig = argv
            argv = [*flags, sys.executable, "-I", "-c", code, pid, sig]
        return real_run(paths, argv, **kw)
    monkeypatch.setattr(session.system, "run", run)


def test_umbriel_mid_session_wakes_the_guard_through_inotify(p, world, monkeypatch) -> None:
    """Wave-2 simplify E3: logind's rewrite of the user record (a rename) wakes the guard, not a
    timer (its POLL is an hour here); it releases and keeps watching."""
    h, snapshot = world
    before = snapshot()
    slow_guard(monkeypatch)
    started(p, h)
    assert_painted(p)
    fakes.one_session(p.home, "2", {"Id": "3", "Class": "user", "Type": "wayland", "State": "online"})
    fakes.logind_record(p.home, "SESSIONS=2 3\n")
    fakes.wait_for(lambda: guard_state(p) == "scope-only", what="the guard to release")
    assert snapshot() == before
    assert fakes.alive(guard_pid(p))
    assert session.stop(p) == 0
    assert guard_state(p) == "released"
    assert "each second" not in (p.home / "aptus-guard.log").read_text()


def test_without_inotify_the_guard_polls_logind(p, world) -> None:
    """The fallback: logind's directory cannot be watched when the guard starts (missing here),
    so the guard looks at the record each second, as before E3."""
    h, snapshot = world
    before = snapshot()
    shutil.rmtree(p.logind_user.parent)
    started(p, h)
    fakes.one_session(p.home, "2", {"Id": "3", "Class": "user", "Type": "wayland", "State": "online"})
    fakes.logind_record(p.home, "SESSIONS=2 3\n")             # the directory is back, unwatched
    fakes.wait_for(lambda: guard_state(p) == "scope-only", what="the guard to release")
    assert snapshot() == before
    assert session.stop(p) == 0
    assert "checking it each second" in (p.home / "aptus-guard.log").read_text()


def test_no_guard_no_lease(p, world) -> None:
    h, snapshot = world
    before = snapshot()
    (p.home / ".aptus-test/bin/systemd-run").unlink()
    report = session.start(p, h.env)
    assert report.mode is session.Mode.SCOPE_ONLY and not report.guard
    assert report.reasons == ["the guard did not start"]
    assert snapshot() == before


def test_lease_cli_refuses_the_real_home(tmp_path) -> None:
    """Under APTUS_TEST=1 aptus-lease (and the other writers) refuse a HOME that is not a
    temporary directory, and write nothing (not even a log) before refusing."""
    import pwd
    real = Path(pwd.getpwuid(os.getuid()).pw_dir)
    link = tmp_path / "linked-home"
    link.symlink_to(real)
    log_before = {n: (real / n).exists() for n in ("aptus-lease.log", "aptus-theme.log",
                                                     "aptus-guard.log", "aptus-session.log")}
    for home in (real, link):
        env = {"HOME": str(home), "APTUS_TEST": "1", "PATH": "/usr/bin",
               "APTUS_REAL_HYPRLAND_SIGNATURE": "unit-tests"}
        for tool, args in (("aptus-lease", ["recover"]), ("aptus-lease", ["release"]),
                           ("aptus-theme", ["apply"]), ("aptus-guard", ["1", "x"]),
                           ("aptus-session", ["stop"])):
            r = subprocess.run([sys.executable, "-I", str(REPO / "bin" / tool), *args], env=env,
                               capture_output=True, text=True, timeout=60)
            assert r.returncode == 3, (tool, home, r.stdout, r.stderr)
            assert "APTUS_TEST=1 but HOME" in r.stderr, r.stderr
    assert {n: (real / n).exists() for n in log_before} == log_before


# --- the phase-7 review fixes ------------------------------------------------------------------

def test_a_guard_that_never_reports_ok_means_no_lease(p, world, monkeypatch) -> None:
    """The guard's process runs but never watches (it hangs in its imports, say): no READY=1, so
    systemd-run fails after TimeoutStartSec and systemd stops it; no lease."""
    h, snapshot = world
    before = snapshot()
    real_run = session.system.run

    def run(paths, argv, **kw):
        if argv[0] == "systemd-run":                       # the unit runs `sleep 30` instead
            argv = [a for a in argv if a.startswith("--") or a == "systemd-run"] + ["sleep", "30"]
        return real_run(paths, argv, **kw)
    monkeypatch.setattr(session.system, "run", run)
    monkeypatch.setattr(session.guard, "READY_TIMEOUT", 0.5)
    report = session.start(p, h.env)
    assert report.mode is session.Mode.SCOPE_ONLY and not report.guard
    assert report.reasons == ["the guard did not start"]
    assert snapshot() == before
    assert not fakes.alive(fakes.unit_pid(p.home))         # stopped after the start timeout


def test_the_guard_watches_when_systemd_run_returns(p, world) -> None:
    """Wave-2 simplify A11/E4: Type=notify, so no wait after systemd-run: guard.state is `ok`
    when it returns. A guard that exits before READY=1 (its Hyprland is gone) fails the start at
    once, not after READY_TIMEOUT."""
    h, _ = world
    assert session.start_guard(p, h.env)
    assert p.guard_state.read_text() == "ok\n\n"
    (call,) = fakes.calls(p.home, "systemd-run")
    assert "--property=Type=notify" in call and "--property=TimeoutStartSec=5000ms" in call
    assert session.stop(p) == 0
    gone = subprocess.Popen(["true"])
    gone.wait()
    real_owner = session.ops.owner
    t = time.monotonic()
    with pytest.MonkeyPatch.context() as m:
        m.setattr(session.ops, "owner", lambda *a: dataclasses.replace(real_owner(*a),
                                                                       hyprland_pid=gone.pid))
        assert not session.start_guard(p, h.env)
    assert time.monotonic() - t < session.guard.READY_TIMEOUT
    assert p.guard_state.read_text() == "released\n\n"


def test_the_guard_starts_alongside_recover_and_render(p, world, monkeypatch) -> None:
    """E4: start_guard runs in a thread from the top of start() (recover waits here until it
    began: a guard started after recover would time this out); take comes only after it."""
    h, _ = world
    began, done = threading.Event(), []
    real_guard, real_recover, real_lease = session.start_guard, session.recover_step, session.lease_step

    def start_guard(*a):
        began.set()
        try:
            return real_guard(*a)
        finally:
            done.append("guard")

    def recover_step(*a):
        assert began.wait(10), "the guard was not started before recover"
        return real_recover(*a)

    def lease_step(*a):
        done.append("lease")
        return real_lease(*a)
    monkeypatch.setattr(session, "start_guard", start_guard)
    monkeypatch.setattr(session, "recover_step", recover_step)
    monkeypatch.setattr(session, "lease_step", lease_step)
    report = session.start(p, h.env)
    assert report.mode is session.Mode.LEASE and report.guard
    assert done == ["guard", "lease"]
    assert session.stop(p) == 0


def test_an_import_after_the_guard_released_is_taken_back(p, world) -> None:
    h, _ = world
    report = session.StartReport(mode=session.Mode.LEASE)
    session.environment_step(p, h.env, report)                 # nothing is held (any more)
    assert fakes.user_env(p.home) == {"XCURSOR_SIZE": "24"}
    assert report.mode is session.Mode.SCOPE_ONLY
    assert report.reasons == ["the guard released the lease"]


def test_a_failing_recover_does_not_stop_the_session(p, world, monkeypatch) -> None:
    h, _ = world
    def boom(*a, **k):
        raise OSError("disk full")
    monkeypatch.setattr(session.ops, "recover", boom)
    report = session.start(p, h.env)
    assert "recover: OSError: disk full" in report.warnings
    assert report.mode is session.Mode.SCOPE_ONLY            # take's own recover fails closed
    assert report.reasons == ["the lease failed"] and report.generation == 1
    assert session.stop(p) == 0


def test_main_starts_the_shell_whatever_start_did(p, monkeypatch) -> None:
    monkeypatch.setenv("XDG_CURRENT_DESKTOP", "Hyprland")
    monkeypatch.setenv("HYPRLAND_INSTANCE_SIGNATURE", "aptus-test-sig")
    monkeypatch.setattr(session, "start", lambda *a: (_ for _ in ()).throw(RuntimeError("bug")))
    execs = []
    monkeypatch.setattr(session, "exec_supervisor", lambda paths: execs.append(paths))
    assert session.main(["start"]) == 1                     # exec_supervisor returned (stub)
    assert execs
    status = json.loads(p.session_status.read_text())
    assert status["reasons"] == ["start failed"] and status["mode"] == "scope-only"


# --- the wave-2 review fixes -------------------------------------------------------------------

BAT_BUILDS = "open(os.path.join(args[5], 'themes.bin'), 'w').write('x')\n"


def papirus(p) -> None:
    """A Papirus with the folder icons own.icons links to (in the test sysroot)."""
    from aptus.theme import own
    for size in own.ICON_SIZES:
        d = p.papirus / size / "places"
        d.mkdir(parents=True)
        for colour in ("teal", "green", "blue", "orange", "pink", "yellow", "red", "violet"):
            (d / f"folder-{colour}.svg").write_text(f"<svg>{colour}</svg>")


def test_the_icon_theme_key_names_only_a_built_theme(p, world) -> None:
    """Wave-2 review 2: at the first login the icon themes are built before the take, so
    icon-theme selects one at once; when they cannot be built the key is only recorded and
    GTK keeps Noctalia's icon theme (never a theme that is not there)."""
    h, _ = world
    papirus(p)
    p.icons.parent.mkdir(parents=True)
    p.icons.write_text("")                                        # ~/.local/share/icons: unusable
    report = session.start(p, h.env)
    assert report.mode is session.Mode.LEASE
    assert any(w.startswith("apply icons:") for w in report.warnings)
    assert KEY + "icon-theme" not in fakes.dconf_db(p.home)
    assert session.stop(p) == 0
    p.icons.unlink()
    started(p, h)
    assert (p.icons / "aptus-icons-dark/index.theme").is_file()
    assert fakes.dconf_db(p.home)[KEY + "icon-theme"] == "'aptus-icons-dark'"
    assert session.stop(p) == 0
    assert KEY + "icon-theme" not in fakes.dconf_db(p.home)       # restored: it was not set


def test_a_login_writes_each_slot_once(p, world, monkeypatch) -> None:
    """Wave-2 review 7: at login the take writes every slot and apply_generation does not write
    them again; a later login with the same theme does not rebuild the bat cache."""
    from collections import Counter

    from aptus.lease.kinds import file as file_kind
    from aptus.lease.kinds import ini
    h, snapshot = world
    before = snapshot()
    fakes.tool(p.home, "bat", BAT_BUILDS)
    writes: Counter = Counter()
    for mod in (file_kind, ini, dconf):
        real = mod.write
        monkeypatch.setattr(mod, "write", lambda paths, rec, spec, real=real:
                            writes.update([rec.id]) or real(paths, rec, spec))
    started(p, h)
    assert writes and set(writes.values()) == {1}, writes
    assert session.stop(p) == 0
    writes.clear()
    started(p, h)                                                 # same settings: generation 1 again
    assert set(writes.values()) == {1}
    assert len(fakes.calls(p.home, "bat")) == 1                   # built at the first login only
    assert session.stop(p) == 0
    assert snapshot() == before


def test_an_apply_writes_only_what_changed(p, world, monkeypatch) -> None:
    """Wave-2 review 7: an apply during the session writes only the slots whose paint changed;
    a target that carries the paint already gets no write and no hook."""
    from collections import Counter

    from aptus.lease.kinds import file as file_kind
    from aptus.lease.kinds import ini
    from aptus.theme import hooks
    h, snapshot = world
    before = snapshot()
    started(p, h)
    writes: Counter = Counter()
    for mod in (file_kind, ini, dconf):
        real = mod.write
        monkeypatch.setattr(mod, "write", lambda paths, rec, spec, real=real:
                            writes.update([rec.id]) or real(paths, rec, spec))
    reloads: list = []
    real_reloads = hooks.run_reloads
    monkeypatch.setattr(hooks, "run_reloads", lambda paths, r, sig:
                        reloads.append(dict(r)) or real_reloads(paths, r, sig))
    report = apply.apply(p, inputs.Inputs(mode="dark", accent="sky", contrast="normal", glass=False),
                         h.signature)
    assert report.mode == "lease" and report.generation == 2 and not report.failed, report
    assert "dconf.accent-color" in writes and "gtk3.artifact" in writes
    assert "cursor.cursor-theme" not in writes and "dconf.color-scheme" not in writes
    assert "cursor" in report.applied and "cursor" not in reloads[0]
    assert journal.load(p).theme_generation == 2
    assert session.stop(p) == 0
    assert snapshot() == before


# --- the wave-2 simplify -----------------------------------------------------------------------

def test_a_login_builds_the_slot_specs_once(p, world, monkeypatch) -> None:
    """Wave-2 simplify E10: apply_generation reuses the take's slot specs (apply.Taken) instead
    of reading every rendered file again; the targets are reported as before."""
    h, snapshot = world
    before = snapshot()
    builds = []
    real = apply.slot_specs
    monkeypatch.setattr(apply, "slot_specs", lambda *a, **kw: builds.append(a[3:]) or real(*a, **kw))
    reports = []
    real_apply = apply.apply_generation
    monkeypatch.setattr(apply, "apply_generation",
                        lambda *a, **kw: reports.append(real_apply(*a, **kw)) or reports[-1])
    started(p, h)
    r = reports[0]                                                # as before this change
    assert (sorted(r.applied), sorted(r.next_start), r.failed) == (
        ["cursor", "dconf", "hyprland"],
        ["btop", "ghostty", "gtk3", "hyprlock", "kde", "kitty"], {})
    assert builds == [()]                                         # lease_step's, for the take
    assert session.stop(p) == 0
    assert snapshot() == before
