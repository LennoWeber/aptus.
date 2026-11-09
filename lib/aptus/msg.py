"""`aptus msg <target> <function> [args…]`: wraps `qs -p <repo>/shell ipc call …` (07 §7)."""
from __future__ import annotations

import re
import subprocess
import sys
import time
from collections.abc import Sequence

from .paths import Paths, get


# Function names that are reserved in JavaScript and therefore spelled differently in the
# shell's IpcHandlers (07 §7).
ALIASES = {("dnd", "for"): "forDuration"}


def parse_show(text: str) -> dict[str, dict[str, int]]:
    """`qs ipc show` output → {target: {function: number of arguments}}."""
    table: dict[str, dict[str, int]] = {}
    current: dict[str, int] | None = None
    for line in text.splitlines():
        if m := re.match(r"^\s*target\s+(\S+)\s*$", line):
            current = table.setdefault(m.group(1), {})
        elif (m := re.match(r"^\s*function\s+(\w+)\s*\((.*?)\)", line)) and current is not None:
            params = [p for p in m.group(2).split(",") if p.strip()]
            current[m.group(1)] = len(params)
    return table


def build(paths: Paths, target: str, function: str, args: Sequence[str],
          arity: int | None) -> list[str]:
    """The `qs -p <shell> ipc call` argv; missing optional arguments are padded with ""."""
    function = ALIASES.get((target, function), function)
    args = list(args)
    if arity is not None and len(args) < arity:
        args += [""] * (arity - len(args))
    return ["qs", "-p", str(paths.shell), "ipc", "call", target, function, *args]


# Exit codes of `aptus msg` (the Super+L chain relies on a non-zero exit for every failure).
EXIT_OK = 0
EXIT_ERROR = 1          # the shell answered "error: …", an empty answer, or a qs ipc error text
EXIT_USAGE = 2          # unknown target/function, wrong number of arguments
EXIT_NO_SHELL = 3       # no shell instance (qs ipc exits 255)
EXIT_TIMEOUT = 4        # the shell did not answer in time (frozen)
TIMEOUT = 2.0           # seconds

# qs ipc call reports these on stdout with exit code 0 (phase-5 probe, S1).
QS_ERRORS = ("Too few arguments", "Too many arguments", "Function not found",
             "Unable to parse argument", "No running instances", "Target not found")
# The ones `qs ipc show` explains (or, for too few, fixes by padding optional arguments).
USAGE_ERRORS = ("Too few arguments", "Too many arguments", "Function not found", "Target not found")


def classify(returncode: int, output: str) -> int:
    """Map qs's exit code and output to an EXIT_* code (qs reports most errors with exit 0)."""
    out = output.strip()
    if returncode == 255 or "No running instances" in out:
        return EXIT_NO_SHELL
    if returncode != 0 or not out:
        return EXIT_ERROR
    if out.startswith(QS_ERRORS) or out.startswith("error:"):
        return EXIT_ERROR
    return EXIT_OK


class _Failed(Exception):
    """A qs run that ended without an answer: (EXIT_* code, message)."""


def _qs(argv: list[str], deadline: float, timeout: float) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(argv, capture_output=True, text=True, stdin=subprocess.DEVNULL,
                              timeout=max(0.05, deadline - time.monotonic()))
    except FileNotFoundError:
        raise _Failed(EXIT_NO_SHELL, "qs is not installed") from None
    except subprocess.TimeoutExpired:
        raise _Failed(EXIT_TIMEOUT, f"the shell did not answer within {timeout:g} s") from None


def call(paths: Paths, target: str, function: str, args: Sequence[str],
         timeout: float = TIMEOUT) -> tuple[int, str]:
    """Run the call. → (EXIT_* code, answer). The call goes first (Super+L waits on it); only when
    qs reports a wrong function or argument count does `qs ipc show` explain it, or give the
    arity to pad optional arguments with "" and call again."""
    deadline = time.monotonic() + timeout
    try:
        done = _qs(build(paths, target, function, args, None), deadline, timeout)
        answer = done.stdout.strip() or done.stderr.strip()
        if done.returncode == 0 and answer.startswith(USAGE_ERRORS):
            shown = _qs(["qs", "-p", str(paths.shell), "ipc", "show"], deadline, timeout)
            table = parse_show(shown.stdout)
            name = ALIASES.get((target, function), function)
            if target not in table:
                return EXIT_USAGE, f"unknown target {target!r} (targets: {', '.join(sorted(table))})"
            if name not in table[target]:
                return EXIT_USAGE, (f"unknown function {target} {function!r} "
                                    f"(functions: {', '.join(sorted(table[target]))})")
            arity = table[target][name]
            if len(args) > arity:
                return EXIT_USAGE, f"{target} {function} takes at most {arity} argument(s), got {len(args)}"
            done = _qs(build(paths, target, function, args, arity), deadline, timeout)
            answer = done.stdout.strip() or done.stderr.strip()
    except _Failed as e:
        return e.args[0], e.args[1]
    code = classify(done.returncode, answer)
    if code == EXIT_ERROR and not answer:
        answer = "empty answer from the shell"
    elif code == EXIT_NO_SHELL:
        answer = "no aptus shell is running"
    return code, answer


def main(argv: Sequence[str]) -> int:
    if len(argv) < 2 or argv[0] in ("-h", "--help"):
        print("usage: aptus msg <target> <function> [args…]", file=sys.stderr)
        return EXIT_USAGE
    code, answer = call(get(), argv[0], argv[1], list(argv[2:]))
    if code == EXIT_OK:
        print(answer)
    else:
        print(f"aptus msg: {answer}", file=sys.stderr)
    return code
