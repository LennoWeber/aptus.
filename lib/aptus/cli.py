"""The `aptus` command: msg, doctor, logs, theme, lease, dev, version (07-architecture §2)."""
from __future__ import annotations

import argparse
import json
import selectors
import subprocess
import sys
import time
from collections.abc import Sequence

from . import msg, paths


VERSION = "2.0.0-dev"


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="aptus", description="aptus v2 session tools")
    sub = p.add_subparsers(dest="command", metavar="command")
    m = sub.add_parser("msg", help="call the shell over IPC: aptus msg <target> <function> [args…]")
    m.add_argument("args", nargs=argparse.REMAINDER)
    d = sub.add_parser("doctor", help="check config, dependencies (and isolation from S2 on)")
    d.add_argument("groups", nargs="*", choices=("isolation", "config", "deps"), metavar="group")
    lg = sub.add_parser("logs", help="the journal of the shell, the session tools and units")
    lg.add_argument("-f", "--follow", action="store_true", help="keep printing new lines")
    lg.add_argument("component", nargs="?", help="one tag or unit, e.g. shell or aptus-guard")
    for name in ("theme", "lease"):
        x = sub.add_parser(name, help="arrives with S2")
        x.add_argument("args", nargs=argparse.REMAINDER)
    dv = sub.add_parser("dev", help="live reload of the shell: aptus dev [on|off]")
    dv.add_argument("state", nargs="?", choices=("on", "off"))
    sub.add_parser("version", help="print the version")
    return p


def journal_queries(component: str | None) -> list[list[str]]:
    """The journalctl argument lists for `aptus logs`: journalctl ANDs -t with -u, so the tags
    (aptus-shell, aptus-session, aptus-supervise) and the units (aptus-*) are two queries, merged
    by timestamp (-o json). `component` narrows to one tag or unit."""
    base = ["journalctl", "--user", "--no-pager", "-o", "json"]
    tags = ("aptus-shell", "aptus-session", "aptus-supervise")
    if component is None:
        return [base + [a for t in tags for a in ("-t", t)], base + ["-u", "aptus-*"]]
    name = component if component.startswith("aptus-") else f"aptus-{component}"
    return [base + ["-t", name]] if name in tags else [base + ["-u", name]]


def cmd_logs(follow: bool, component: str | None) -> int:
    """Print the merged journal (07 §11); with follow, both queries stream (-f) and lines are
    printed as they arrive."""
    def line(raw: str) -> tuple[int, str] | None:
        try:
            e = json.loads(raw)
        except ValueError:
            return None
        message = e.get("MESSAGE", "")
        if isinstance(message, list):           # journald sends non-UTF-8 messages as bytes
            message = bytes(message).decode("utf-8", "replace")
        ts = int(e.get("__REALTIME_TIMESTAMP", 0))
        who = e.get("SYSLOG_IDENTIFIER") or e.get("_SYSTEMD_USER_UNIT") or e.get("_COMM", "?")
        pid = f"[{e['_PID']}]" if e.get("_PID") else ""
        stamp = time.strftime("%b %d %H:%M:%S", time.localtime(ts / 1e6))
        return ts, f"{stamp} {who}{pid}: {message}"

    queries = journal_queries(component)
    backlog = 20 if follow else 300
    merged: dict[str, tuple[int, str]] = {}     # keyed by __CURSOR: a line matched twice prints once
    try:
        for q in queries:
            done = subprocess.run(q + ["-n", str(backlog)], capture_output=True, text=True)
            for raw in done.stdout.splitlines():
                entry = line(raw)
                if entry:
                    merged[json.loads(raw).get("__CURSOR", raw)] = entry
    except FileNotFoundError:
        print("aptus logs: journalctl is not installed", file=sys.stderr)
        return 1
    for _, text in sorted(merged.values())[-backlog:]:
        print(text)
    if not follow:
        return 0
    sys.stdout.flush()
    procs = [subprocess.Popen(q + ["-f", "-n", "0"], stdout=subprocess.PIPE, text=True)
             for q in queries]
    sel = selectors.DefaultSelector()
    for proc in procs:
        sel.register(proc.stdout, selectors.EVENT_READ)
    try:
        while sel.get_map():
            for key, _ in sel.select():
                raw = key.fileobj.readline()
                if not raw:
                    sel.unregister(key.fileobj)
                    continue
                entry = line(raw)
                if entry:
                    print(entry[1], flush=True)
    except KeyboardInterrupt:
        pass
    finally:
        for proc in procs:
            proc.terminate()
    return 0


def cmd_dev(on: bool) -> int:
    """`aptus dev [on|off]`: create/remove <runtime>/dev and restart the supervised shell; the
    supervisor starts qs with APTUS_DEV=1 while the flag exists (live reload, P-23)."""
    p = paths.get()
    p.runtime.mkdir(parents=True, exist_ok=True, mode=0o700)
    if on:
        p.dev_flag.touch()
    else:
        p.dev_flag.unlink(missing_ok=True)
    word = "on" if on else "off"
    p.restart_flag.touch()
    code, answer = msg.call(p, "shell", "restart", [])
    if code != msg.EXIT_OK:
        p.restart_flag.unlink(missing_ok=True)     # a stale flag would turn a clean exit into a restart
        print(f"dev mode {word}; the shell was not restarted ({answer}), the next start uses it")
        return 0
    print(f"dev mode {word}; the shell restarts" + (" with live reload" if on else ""))
    return 0


def main(argv: Sequence[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else list(argv)
    if argv and argv[0] == "msg":            # everything after "msg" belongs to the shell
        return msg.main(argv[1:])
    args = parser().parse_args(argv)
    if args.command is None:
        parser().print_help()
        return 2
    if args.command == "doctor":
        from . import doctor
        return doctor.main(args.groups)
    if args.command == "logs":
        return cmd_logs(args.follow, args.component)
    if args.command in ("theme", "lease"):
        print(f"aptus {args.command}: not available until S2", file=sys.stderr)
        return 2
    if args.command == "dev":
        if args.state is None:
            print("dev mode " + ("on" if paths.get().dev_flag.exists() else "off"))
            return 0
        return cmd_dev(args.state == "on")
    if args.command == "version":
        print(f"aptus {VERSION}")
        return 0
    return 2
