"""The two crash endings of 02 §7's exit matrix that need a real crash: the process holding the
lease dies (SIGKILL) in the middle of a take or a release. The journal says `taking` or
`releasing` with a dead owner; `aptus-lease recover` gives every byte back. The take and the
release run in a child process that kills itself on the second slot write (or restore)."""
from __future__ import annotations

import os
import signal
import subprocess
import sys
from pathlib import Path

import pytest

import test_s2_lease as lease_tests
from aptus import paths as paths_mod
from aptus.lease import journal, ops
from aptus.lease.journal import State

REPO = Path(__file__).resolve().parents[2]
CHILD = """\
import os, signal, sys
sys.path[:0] = [{lib!r}, {unit!r}]
from aptus import paths as paths_mod
from aptus.lease import ops
from aptus.lease.kinds import file as file_kind
import test_s2_lease as t

p = paths_mod.get()
calls = [0]
real = getattr(file_kind, {fn!r})

def die_on_second(*args):
    calls[0] += 1
    if calls[0] == 2:
        os.kill(os.getpid(), signal.SIGKILL)
    return real(*args)

setattr(file_kind, {fn!r}, die_on_second)
if {fn!r} == "write":
    ops.take(p, dict(os.environ), t.specs(p), ops.owner(p, dict(os.environ)), 1)
else:
    ops.release(p)
"""


@pytest.fixture
def p(test_home: Path, monkeypatch: pytest.MonkeyPatch) -> paths_mod.Paths:
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(test_home / "r"))
    (test_home / "r").mkdir()
    return paths_mod.get()


@pytest.fixture
def hypr(p, test_home, tmp_path):
    import s2_fakes as fakes
    h = fakes.hyprland(test_home, tmp_path)
    yield h
    h.kill()


def crash_in(tmp_path: Path, hypr, fn: str) -> None:
    """Run a take (fn "write") or a release (fn "restore") in a child that SIGKILLs itself on the
    second call of the file kind's `fn`."""
    script = tmp_path / f"crash-{fn}.py"
    script.write_text(CHILD.format(lib=str(REPO / "lib"), unit=str(REPO / "tests/unit"), fn=fn))
    env = dict(os.environ, HYPRLAND_INSTANCE_SIGNATURE=hypr.signature, XDG_SESSION_ID="2")
    r = subprocess.run([sys.executable, str(script)], env=env, capture_output=True, text=True,
                       timeout=60)
    assert r.returncode == -signal.SIGKILL, (r.returncode, r.stderr)


def test_crash_mid_take(p, test_home, hypr, tmp_path) -> None:
    files = lease_tests.setup_world(p, test_home)
    base = lease_tests.baseline(p, files)
    crash_in(tmp_path, hypr, "write")
    j = journal.load(p)
    assert j is not None and j.state == State.TAKING              # died before it held
    assert lease_tests.baseline(p, files) != base                 # the first slot is painted
    assert not ops.recover(p).acted                               # the owner (Hyprland) lives
    hypr.kill()
    rel = ops.recover(p)
    assert rel.acted and not rel.failed
    assert lease_tests.baseline(p, files) == base
    assert journal.load(p) is None


def test_crash_mid_release(p, test_home, hypr, tmp_path) -> None:
    files = lease_tests.setup_world(p, test_home)
    base = lease_tests.baseline(p, files)
    assert lease_tests.take(p, hypr).held
    crash_in(tmp_path, hypr, "restore")
    j = journal.load(p)
    assert j is not None and j.state == State.RELEASING           # died half-way through
    hypr.kill()
    rel = ops.recover(p)
    assert rel.acted and not rel.failed
    assert lease_tests.baseline(p, files) == base
    assert journal.load(p) is None
