"""Fakes for the S2 tests, all inside the temporary HOME: tools in $HOME/.aptus-test/bin (the only
place lease.system takes tools from under APTUS_TEST=1) that record their calls, and a fake
Hyprland owner (a process whose comm is "Hyprland", a listening socket, hyprland.lock)."""
from __future__ import annotations

import json
import os
import shutil
import socket
import subprocess
import sys
import textwrap
import threading
import time
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

PY = sys.executable


def tool(home: Path, name: str, body: str) -> Path:
    """$HOME/.aptus-test/bin/<name>: a Python script that appends its argv to calls.jsonl and runs
    `body` (with `args`, `state` (a dict saved to <name>.json) and `out` available)."""
    bindir = home / ".aptus-test/bin"
    bindir.mkdir(parents=True, exist_ok=True)
    script = bindir / name
    script.write_text(f"#!{PY}\n" + textwrap.dedent(f"""\
        import json, os, sys
        base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        args = sys.argv[1:]
        with open(os.path.join(base, "calls.jsonl"), "a") as f:
            f.write(json.dumps([{name!r}] + args) + "\\n")
        sf = os.path.join(base, {name!r} + ".json")
        state = json.load(open(sf)) if os.path.exists(sf) else {{}}
        out = []
        code = 0
        """) + textwrap.dedent(body) + textwrap.dedent("""\
        json.dump(state, open(sf, "w"))
        sys.stdout.write("".join(out))
        sys.exit(code)
        """))
    script.chmod(0o755)
    return script


def calls(home: Path, name: str | None = None) -> list[list[str]]:
    f = home / ".aptus-test/calls.jsonl"
    if not f.exists():
        return []
    rows = [json.loads(line) for line in f.read_text().splitlines()]
    return [r for r in rows if name is None or r[0] == name]


def dconf(home: Path, initial: dict[str, str] | None = None) -> None:
    """A dconf with a JSON database: read prints the value (nothing when unset), write, reset."""
    if initial:
        (home / ".aptus-test").mkdir(parents=True, exist_ok=True)
        (home / ".aptus-test/dconf.json").write_text(json.dumps(initial))
    tool(home, "dconf", """\
        cmd, key = args[0], args[1]
        if cmd == "read":
            out.append(state.get(key, "") + "\\n")
        elif cmd == "write":
            state[key] = args[2]
        elif cmd == "reset":
            state.pop(key, None)
        else:
            code = 1
        """)


def dconf_db(home: Path) -> dict[str, str]:
    f = home / ".aptus-test/dconf.json"
    return json.loads(f.read_text()) if f.exists() else {}


def loginctl(home: Path, sessions: list[dict[str, str]]) -> None:
    """A loginctl that lists `sessions` ({Id, Class, Type, State, …}) for this uid."""
    (home / ".aptus-test").mkdir(parents=True, exist_ok=True)
    (home / ".aptus-test/loginctl.json").write_text(json.dumps({"sessions": sessions}))
    tool(home, "loginctl", f"""\
        rows = state.get("sessions", [])
        if args[0] == "list-sessions":
            for r in rows:
                out.append(f"{{r['Id']}} {os.getuid()} user seat0 1 {{r['Class']}} tty1 no -\\n")
        elif args[0] == "show-session":
            r = next(x for x in rows if x["Id"] == args[1])
            for k, v in r.items():
                out.append(f"{{k}}={{v}}\\n")
        """)


def one_session(home: Path, own: str = "2", *others: dict[str, str]) -> None:
    loginctl(home, [{"Id": own, "Class": "user", "Type": "wayland", "State": "active"}, *others])


@dataclass
class FakeHyprland:
    proc: subprocess.Popen
    sock: socket.socket
    signature: str
    env: dict[str, str]

    @property
    def pid(self) -> int:
        return self.proc.pid

    def kill(self) -> None:
        if self.proc.poll() is None:
            self.proc.kill()
            self.proc.wait(5)
        self.sock.close()


def hyprland(home: Path, tmp: Path, signature: str = "aptus-test-sig") -> FakeHyprland:
    """A process named Hyprland (a copy of sleep) with this HOME, a listening .socket.sock and
    hyprland.lock under $XDG_RUNTIME_DIR/hypr/<signature> (XDG_RUNTIME_DIR must be <home>/r)."""
    exe = tmp / "fakebin/Hyprland"
    exe.parent.mkdir(parents=True, exist_ok=True)
    if not exe.exists():
        shutil.copy(shutil.which("sleep") or "/usr/bin/sleep", exe)
    env = {"HOME": str(home), "HYPRLAND_INSTANCE_SIGNATURE": signature, "PATH": "/usr/bin"}
    proc = subprocess.Popen([str(exe), "600"], env=env)
    d = home / "r/hypr" / signature
    d.mkdir(parents=True, exist_ok=True)
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.bind(str(d / ".socket.sock"))
    s.listen(64)
    threading.Thread(target=_answer_ok, args=(s, d / "requests.log"), daemon=True).start()
    (d / "hyprland.lock").write_text(f"{proc.pid}\nwayland-test\n")
    full = dict(os.environ, HYPRLAND_INSTANCE_SIGNATURE=signature, XDG_SESSION_ID="2")
    return FakeHyprland(proc, s, signature, full)


def _answer_ok(server: socket.socket, log: Path) -> None:
    """Answer every request with "ok" (eval, dispatch) and log it, until the socket closes."""
    while True:
        try:
            conn, _ = server.accept()
        except OSError:
            return
        with conn:
            conn.settimeout(1)
            try:
                data = conn.recv(65536)
                if data:
                    with open(log, "ab") as f:
                        f.write(data + b"\n")
                    conn.sendall(b"ok")
            except OSError:
                pass


def wait_for(cond: Callable[[], bool], timeout: float = 10.0, what: str = "") -> None:
    end = time.monotonic() + timeout
    while not cond():
        if time.monotonic() > end:
            raise AssertionError(f"timed out waiting for {what or cond}")
        time.sleep(0.05)


def alive(pid: int) -> bool:
    """The process exists and is not a zombie."""
    try:
        with open(f"/proc/{pid}/stat") as f:
            return f.read().rsplit(")", 1)[1].split()[0] != "Z"
    except OSError:
        return False


def systemd_run(home: Path) -> None:
    """A systemd-run that starts the unit's command detached (in a new session, its output in
    $HOME/.aptus-test/<unit>.log) with the caller's environment, and records the pid."""
    tool(home, "systemd-run", """\
        import subprocess
        unit = next(a.split("=", 1)[1] for a in args if a.startswith("--unit="))
        cmd = [a for a in args if not a.startswith("--")]
        units = state.setdefault("units", {})
        if unit in units and os.path.exists(f"/proc/{units[unit]}"):
            code = 1
        else:
            log = open(os.path.join(base, unit + ".log"), "ab")
            proc = subprocess.Popen(cmd, stdout=log, stderr=log, start_new_session=True)
            units[unit] = proc.pid
        """)


def unit_pid(home: Path, unit: str = "aptus-guard") -> int | None:
    f = home / ".aptus-test/systemd-run.json"
    return json.loads(f.read_text()).get("units", {}).get(unit) if f.exists() else None


def systemctl(home: Path) -> None:
    """A systemctl --user: is-active and stop for the units systemd-run started (stop sends SIGTERM
    and waits), show-/import-/unset-environment on a recorded environment, the rest succeeds."""
    tool(home, "systemctl", """\
        import signal, time
        def alive(pid):
            try:
                with open(f"/proc/{pid}/stat") as f:
                    return f.read().rsplit(")", 1)[1].split()[0] != "Z"
            except OSError:
                return False
        runs = os.path.join(base, "systemd-run.json")
        units = json.load(open(runs)).get("units", {}) if os.path.exists(runs) else {}
        env = state.setdefault("env", {})
        verb, rest = args[1], args[2:]
        names = [a for a in rest if not a.startswith("--")]
        if verb == "is-active":
            code = 0 if alive(units.get(names[0].removesuffix(".service"), -1)) else 3
        elif verb == "stop":
            pid = units.get(names[0].removesuffix(".service"), -1)
            if not alive(pid):
                code = 5
            else:
                os.kill(pid, signal.SIGTERM)
                end = time.monotonic() + 20
                while alive(pid) and time.monotonic() < end:
                    time.sleep(0.05)
            # the stopped unit may have changed the environment meanwhile: keep its changes
            state = json.load(open(sf)) if os.path.exists(sf) else {}
        elif verb == "show-environment":
            out.extend(f"{k}={v}\\n" for k, v in sorted(env.items()))
        elif verb == "import-environment":
            env.update({n: os.environ[n] for n in names if n in os.environ})
        elif verb == "unset-environment":
            for n in names:
                env.pop(n, None)
        elif verb == "list-units":
            out.extend(f"{u}.service loaded active running x\\n" for u, pid in units.items() if alive(pid))
        """)


def user_env(home: Path) -> dict[str, str]:
    f = home / ".aptus-test/systemctl.json"
    return json.loads(f.read_text()).get("env", {}) if f.exists() else {}
