"""End-to-end S2 checks in a nested Hyprland (02 §10, 07 §13): the round trip with each ending of
02 §7's exit matrix (logout, SIGKILL to Hyprland, hard power-off then the next login), scope-only
mode with Umbriel open, the builtin:hyprland reload after a theme change, and an empty
`configerrors`.

Each test starts its own nested Hyprland (tests/e2e/nested.py) whose HOME is temporary. The slot
fixtures are copies of the real slot files, read only (never from ~/.config/umbriel,
~/.config/noctalia or ~/.local/state/noctalia); the dconf fake starts with the real values (read
with `dconf read`). systemd-run, systemctl, loginctl and dconf are the fakes of
tests/unit/s2_fakes.py in $HOME/.aptus-test/bin, so the guard runs as a real process and nothing
reaches the real user manager. Screenshots go to the test's directory, and also to
$APTUS_E2E_SHOTS when that is set.
"""
from __future__ import annotations

import hashlib
import json
import os
import pwd
import re
import shutil
import signal
import subprocess
import sys
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tests" / "unit"))

import s2_fakes as fakes  # noqa: E402
from nested import Nested, real_signature  # noqa: E402

from aptus import hypr  # noqa: E402
from aptus import paths as paths_mod  # noqa: E402
from aptus.lease import journal, preflight  # noqa: E402
from aptus.lease.journal import State  # noqa: E402
from aptus.lease.kinds import dconf as dconf_kind  # noqa: E402
from aptus.theme import targets  # noqa: E402
from aptus.theme.targets import Mechanism  # noqa: E402

REAL_HOME = Path(pwd.getpwuid(os.getuid()).pw_dir)
NEVER_READ = (".config/umbriel", ".config/noctalia", ".local/state/noctalia")
MAX_COPY = 2 << 20                     # bytes; a bigger slot file is left out of the fixtures
OWN_SESSION = os.environ.get("XDG_SESSION_ID", "2")   # the nested session inherits it
UMBRIEL = {"Id": "umbriel-vt", "Class": "user", "Type": "wayland", "State": "online", "Desktop": "Umbriel"}


def _never(rel: Path) -> bool:
    s = str(rel)
    return any(s == n or s.startswith(n + "/") for n in NEVER_READ)


def _real_dir(real: paths_mod.Paths, value: str) -> Path | None:
    """The real directory of a `when: exists:` path below HOME, None otherwise."""
    try:
        p = targets.expand(real, value)
    except targets.ManifestError:
        return None
    rel = p.relative_to(REAL_HOME)
    return None if _never(rel) else p


def copy_real_slots(home: Path) -> list[str]:
    """Copy every lease and bake slot that exists in the real HOME into `home` (read only, symlinks
    followed), and create the directories a target's `when: exists:` and a created slot need.
    Returns the slot paths relative to HOME: the set `snapshot` hashes."""
    real = paths_mod.resolve({"HOME": str(REAL_HOME)})
    manifest = targets.load(REPO / "theme" / "targets.toml")
    rels: set[str] = set()
    for t in manifest.targets:
        if t.when.startswith("exists:"):
            d = _real_dir(real, t.when.partition(":")[2])
            if d is not None and d.is_dir():
                (home / d.relative_to(REAL_HOME)).mkdir(parents=True, exist_ok=True)
        if t.mechanism not in (Mechanism.LEASE, Mechanism.BAKE):
            continue
        for _f, slot in targets.slots(real, t):
            rel = slot.relative_to(REAL_HOME)
            if _never(rel):
                continue
            rels.add(str(rel))
            dst = home / rel
            if slot.parent.is_dir():
                dst.parent.mkdir(parents=True, exist_ok=True)
            if slot.is_file() and slot.stat().st_size <= MAX_COPY:
                shutil.copyfile(slot, dst)
    return sorted(rels)


def real_dconf() -> dict[str, str]:
    """The real values of every dconf key the manifest leases (`dconf read`, read only)."""
    manifest = targets.load(REPO / "theme" / "targets.toml")
    keys = {dconf_kind.KEY_DIR + k for t in manifest.targets for k, _ in t.dconf}
    out = {}
    for key in sorted(keys):
        try:
            value = subprocess.run(["dconf", "read", key], capture_output=True, text=True,
                                   timeout=5).stdout.strip()
        except (OSError, subprocess.TimeoutExpired):
            value = ""
        if value:
            out[key] = value
    return out


@dataclass
class World:
    root: Path
    home: Path
    slots: list[str]
    nested: Nested

    @property
    def paths(self) -> paths_mod.Paths:
        return self.nested.paths

    def snapshot(self) -> dict:
        """sha256 of every slot (None when missing) and the dconf database."""
        out: dict = {}
        for rel in self.slots:
            f = self.home / rel
            out[rel] = hashlib.sha256(f.read_bytes()).hexdigest() if f.is_file() else None
        out["dconf"] = fakes.dconf_db(self.home)
        return out

    def start(self, others: tuple[dict[str, str], ...] = ()) -> dict:
        """A nested login: loginctl lists this session (and `others`); Hyprland's start runs
        aptus-session start. Returns session.json once it is written."""
        fakes.one_session(self.home, OWN_SESSION, *others)
        status = self.paths.session_status
        status.unlink(missing_ok=True)
        self.nested.start(timeout=15)
        self.nested.wait_for(status.is_file, timeout=60)
        return json.loads(status.read_text())

    def relogin(self, name: str) -> None:
        """The next login on the same HOME: a new nested Hyprland."""
        self.nested = Nested(root=self.root / name, home=self.home)

    def guard_state(self) -> str:
        f = self.paths.guard_state
        return f.read_text().split("\n")[0] if f.exists() else ""

    def guard_pid(self) -> int | None:
        """The guard the systemd-run fake started, while it runs (and is this HOME's)."""
        pid = fakes.unit_pid(self.home)
        return pid if pid and fakes.alive(pid) and self.ours(pid) else None

    def ours(self, pid: int) -> bool:
        """The process runs with APTUS_TEST=1 and this HOME (never one of the real session's)."""
        try:
            with open(f"/proc/{pid}/environ", "rb") as f:
                env = f.read().split(b"\0")
        except OSError:
            return False
        return b"APTUS_TEST=1" in env and b"HOME=" + str(self.home).encode() in env

    def hyprland_pid(self) -> int:
        """The nested Hyprland's pid, checked: comm Hyprland, this HOME, never the real one."""
        n = self.nested
        insts = {i.get("instance"): i.get("pid") for i in n.hyprctl("instances", as_json=True) or []}
        pid = insts.get(n.signature)
        assert pid and pid != insts.get(real_signature()), "no nested Hyprland pid"
        with open(f"/proc/{pid}/comm") as f:
            assert f.read().strip() == "Hyprland"
        assert self.ours(int(pid)), "the Hyprland is not the nested one"
        return int(pid)

    def border(self) -> str:
        """general:col.active_border as Hyprland reports it ("aarrggbb …")."""
        opt = self.nested.hyprctl("getoption", "general:col.active_border", as_json=True) or {}
        return str(opt.get("gradient", "")).split(" ")[0].lower()

    def shot(self, name: str) -> Path:
        path = self.nested.screenshot(self.root / f"{name}.png")
        dest = os.environ.get("APTUS_E2E_SHOTS")
        if dest:
            Path(dest).mkdir(parents=True, exist_ok=True)
            shutil.copy(path, Path(dest) / path.name)
        return path

    def wait_released(self) -> None:
        """Hyprland is gone; wait for the guard to finish its release."""
        self.nested.wait_for(lambda: self.guard_pid() is None, timeout=30)


def generated_border(p: paths_mod.Paths) -> str:
    """generated.lua's accent ("rgb(rrggbb)" / "rgba(rrggbbaa)") as Hyprland prints it."""
    value = re.search(r'^\s*accent = "([^"]+)"', p.generated_lua.read_text(), re.M).group(1)
    hexpart = value[value.index("(") + 1:value.index(")")].lower()
    return "ff" + hexpart if len(hexpart) == 6 else hexpart[6:] + hexpart[:6]


@pytest.fixture
def world(tmp_path: Path) -> Iterator[World]:
    if not os.environ.get("APTUS_REAL_HYPRLAND_SIGNATURE"):
        pytest.skip("not inside a Hyprland session")
    real_signature()
    home = tmp_path / "home"
    home.mkdir()
    slots = copy_real_slots(home)
    fakes.dconf(home, real_dconf() or {dconf_kind.KEY_DIR + "color-scheme": "'prefer-light'"})
    fakes.systemd_run(home)
    fakes.systemctl(home)
    w = World(tmp_path, home, slots, Nested(root=tmp_path / "first", home=home))
    try:
        yield w
    finally:
        w.nested.stop()
        pid = w.guard_pid()
        if pid:
            os.kill(pid, signal.SIGKILL)
        (tmp_path / "harness.log").write_text("\n".join(w.nested.log))


def assert_leased(w: World, status: dict, before: dict) -> None:
    assert status["mode"] == "lease" and status["guard"] and status["generation"] >= 1, status
    assert status["test"] is True and status["notice"] == ""
    w.nested.wait_for(lambda: w.guard_state() == "ok", timeout=20)
    j = journal.load(w.paths)
    assert j is not None and j.state == State.HELD
    assert j.owner.hyprland_signature == w.nested.signature
    assert w.snapshot() != before                              # the slots carry aptus's paint
    assert hypr.config_errors(sig=w.nested.signature) == []
    assert "APTUS_SESSION" in fakes.user_env(w.home)            # imported while the lease is held


def assert_given_back(w: World, before: dict) -> None:
    assert w.snapshot() == before                              # every slot hash as before
    assert journal.load(w.paths) is None
    last = journal.last_released(w.paths)
    assert last is not None and last.state == State.RELEASED
    assert "APTUS_SESSION" not in fakes.user_env(w.home)


def test_logout(world: World) -> None:
    """Log in, see the paint, change the accent through the shell (aptus-theme apply, the lease
    update, the builtin:hyprland eval), log out through the shell: the guard releases."""
    w = world
    before = w.snapshot()
    status = w.start()
    assert_leased(w, status, before)
    w.nested.start_shell(timeout=30)
    assert w.border() == generated_border(w.paths)
    lease = w.nested.state()["services"]["lease"]
    assert lease["mode"] == "lease" and lease["state"] == "held" and lease["notice"] == ""
    w.shot("s2-lease")

    accent = w.nested.state()["services"]["tokens"]["accent"]
    other = "rose" if accent == "sky" else "sky"
    old_border = w.border()
    assert w.nested.msg("theme", "accent", other) == "ok"
    w.nested.wait_for(lambda: journal.load(w.paths).theme_generation >= 2, timeout=30)
    w.nested.wait_for(lambda: w.border() != old_border, timeout=10)
    assert w.border() == generated_border(w.paths)          # the eval reached Hyprland
    assert hypr.config_errors(sig=w.nested.signature) == []
    w.shot("s2-accent")

    w.nested.msg("session", "logout")                       # Session.logout: Hyprland exits
    w.nested.wait_for(lambda: w.nested.proc.poll() is not None, timeout=20)
    w.wait_released()
    assert_given_back(w, before)
    assert w.guard_state() == "released"


def test_sigkill_to_hyprland(world: World) -> None:
    w = world
    before = w.snapshot()
    assert_leased(w, w.start(), before)
    guard = w.guard_pid()
    assert guard
    os.kill(w.hyprland_pid(), signal.SIGKILL)               # the guard's pidfd fires
    w.wait_released()
    assert_given_back(w, before)
    assert w.guard_state() == "released"
    assert "Traceback" not in (w.home / ".aptus-test/aptus-guard.log").read_text()


def test_power_off_then_next_login(world: World) -> None:
    """A hard power-off: guard and Hyprland die at once, the journal stays `held`. The next login
    recovers before it takes again; its logout gives everything back."""
    w = world
    before = w.snapshot()
    assert_leased(w, w.start(), before)
    guard = w.guard_pid()
    assert guard
    os.kill(guard, signal.SIGKILL)
    os.kill(w.hyprland_pid(), signal.SIGKILL)
    w.nested.stop()
    j = journal.load(w.paths)
    assert j is not None and j.state == State.HELD           # nobody released
    assert w.snapshot() != before

    w.relogin("second")
    status = w.start()
    assert status["mode"] == "lease" and status["warnings"] == [], status
    history = sorted(w.paths.lease_history.glob("*.json"))
    assert len(history) == 1                                # the dead session's lease
    w.nested.wait_for(lambda: w.guard_state() == "ok", timeout=20)
    w.nested.start_shell(timeout=30)
    w.nested.msg("session", "logout")
    w.nested.wait_for(lambda: w.nested.proc.poll() is not None, timeout=20)
    w.wait_released()
    assert_given_back(w, before)


def test_umbriel_open_means_scope_only(world: World) -> None:
    w = world
    before = w.snapshot()
    status = w.start(others=(UMBRIEL,))
    assert status["mode"] == "scope-only", status
    assert status["reasons"] == [preflight.REASON_OTHER_SESSION]
    assert status["notice"] == preflight.NOTICE_OTHER_SESSION
    w.nested.start_shell(timeout=30)
    lease = w.nested.state()["services"]["lease"]
    assert lease["mode"] == "scope-only" and lease["notice"] == preflight.NOTICE_OTHER_SESSION
    assert lease["warning"] is True
    assert w.snapshot() == before                           # no leased slot touched
    assert journal.load(w.paths) is None
    assert "APTUS_SESSION" not in fakes.user_env(w.home)    # nothing reached the user manager
    assert hypr.config_errors(sig=w.nested.signature) == []
    assert w.border() == generated_border(w.paths)          # Own targets still themed
    w.shot("s2-scope-only")
    w.nested.msg("session", "logout")
    w.nested.wait_for(lambda: w.nested.proc.poll() is not None, timeout=20)
    w.wait_released()
    assert w.snapshot() == before
