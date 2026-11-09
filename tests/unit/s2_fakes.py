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
    (d / "hyprland.lock").write_text(f"{proc.pid}\nwayland-test\n")
    full = dict(os.environ, HYPRLAND_INSTANCE_SIGNATURE=signature, XDG_SESSION_ID="2")
    return FakeHyprland(proc, s, signature, full)
