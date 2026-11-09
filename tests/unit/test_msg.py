"""aptus msg: show parsing, padding, aliases, exit codes."""
from __future__ import annotations

import subprocess
import time
from pathlib import Path

import pytest

from aptus import msg, paths

# `qs ipc show` as Quickshell 0.3.2 prints it (phase-5 probe, PHASES.md).
SHOW = """target shell
  function state(): string
  function log(level: string): string
target surface
  function open(name: string, args: string): string
  function back(): string
target spotlight
  function open(query: string, scope: string): string
  property count: int
  signal countChanged()
target dnd
  function forDuration(duration: string): string
target session
  function lock(): string
"""


def test_parse_show() -> None:
    assert msg.parse_show(SHOW) == {
        "shell": {"state": 0, "log": 1},
        "surface": {"open": 2, "back": 0},
        "spotlight": {"open": 2},
        "dnd": {"forDuration": 1},
        "session": {"lock": 0},
    }
    assert msg.parse_show("") == {}


class FakeQs:
    """Emulates real qs for `qs ipc show|call` from the SHOW table; records every argv."""

    def __init__(self) -> None:
        self.table = msg.parse_show(SHOW)
        self.calls: list[list[str]] = []
        self.answer = "ok"          # what a well-formed call answers

    @property
    def verbs(self) -> list[str]:
        return [c[-1] if c[-1] == "show" else "call" for c in self.calls]

    def __call__(self, argv: list[str], **kw: object) -> subprocess.CompletedProcess:
        self.calls.append(argv)
        if argv[-1] == "show":
            return subprocess.CompletedProcess(argv, 0, SHOW, "")
        target, function, *args = argv[argv.index("call") + 1:]
        if target not in self.table:
            out = "Target not found."
        elif function not in self.table[target]:
            out = "Function not found."
        else:
            arity = self.table[target][function]
            if len(args) < arity:
                out = f"Too few arguments provided ({arity} required but {len(args)} were provided.)"
            elif len(args) > arity:
                out = f"Too many arguments provided ({arity} required but {len(args)} were provided.)"
            else:
                out = self.answer
        return subprocess.CompletedProcess(argv, 0, out, "")


@pytest.fixture
def fake_qs(monkeypatch: pytest.MonkeyPatch) -> FakeQs:
    qs = FakeQs()
    monkeypatch.setattr(msg.subprocess, "run", qs)
    return qs


def test_full_call_skips_show(fake_qs: FakeQs) -> None:
    p = paths.get()
    assert msg.call(p, "spotlight", "open", ["fire", "apps"]) == (msg.EXIT_OK, "ok")
    assert fake_qs.calls == [["qs", "-p", str(p.shell), "ipc", "call", "spotlight", "open",
                              "fire", "apps"]]


def test_pads_optional_args(fake_qs: FakeQs) -> None:
    p = paths.get()
    assert msg.call(p, "spotlight", "open", []) == (msg.EXIT_OK, "ok")
    base = ["qs", "-p", str(p.shell), "ipc"]
    assert fake_qs.verbs == ["call", "show", "call"]
    assert fake_qs.calls[0] == [*base, "call", "spotlight", "open"]
    assert fake_qs.calls[1] == [*base, "show"]
    assert fake_qs.calls[2] == [*base, "call", "spotlight", "open", "", ""]
    msg.call(p, "spotlight", "open", ["fire"])
    assert fake_qs.calls[-1][-2:] == ["fire", ""]
    assert msg.build(p, "surface", "open", ["deck"], 2)[-3:] == ["open", "deck", ""]
    assert msg.build(p, "surface", "open", ["deck"], None)[-2:] == ["open", "deck"]


def test_alias_for(fake_qs: FakeQs) -> None:
    assert msg.call(paths.get(), "dnd", "for", ["90m"]) == (msg.EXIT_OK, "ok")
    assert fake_qs.calls[-1][-3:] == ["dnd", "forDuration", "90m"]
    assert msg.ALIASES[("dnd", "for")] == "forDuration"


def test_usage_errors(fake_qs: FakeQs, capsys: pytest.CaptureFixture) -> None:
    code, answer = msg.call(paths.get(), "shell", "state", ["extra"])
    assert code == msg.EXIT_USAGE and "at most 0" in answer
    assert fake_qs.verbs == ["call", "show"]                     # no padded call
    assert msg.call(paths.get(), "nope", "x", [])[0] == msg.EXIT_USAGE
    assert msg.call(paths.get(), "shell", "nope", [])[0] == msg.EXIT_USAGE
    assert msg.main(["shell"]) == msg.EXIT_USAGE
    assert msg.main(["shell", "state", "x"]) == msg.EXIT_USAGE
    assert "at most 0" in capsys.readouterr().err


def test_no_instance_exit_code(monkeypatch: pytest.MonkeyPatch) -> None:
    real_run = subprocess.run

    def run(argv: list[str], **kw: object) -> subprocess.CompletedProcess:
        return subprocess.CompletedProcess(argv, 255, "No running instances for \"…\"\n", "")

    monkeypatch.setattr(msg.subprocess, "run", run)
    assert msg.call(paths.get(), "session", "lock", [])[0] == msg.EXIT_NO_SHELL
    assert msg.main(["session", "lock"]) == msg.EXIT_NO_SHELL
    assert msg.classify(255, "") == msg.EXIT_NO_SHELL
    # The fixture's guard stub on PATH (exit 99) stands in for a broken qs: never exit 0.
    monkeypatch.setattr(msg.subprocess, "run", real_run)
    assert msg.call(paths.get(), "session", "lock", [])[0] == msg.EXIT_ERROR


def test_error_answer_exits_nonzero(fake_qs: FakeQs, capsys: pytest.CaptureFixture) -> None:
    fake_qs.answer = "error: no lock screen yet\n"
    assert msg.call(paths.get(), "session", "lock", []) == (msg.EXIT_ERROR,
                                                             "error: no lock screen yet")
    assert msg.main(["session", "lock"]) == msg.EXIT_ERROR
    assert "no lock screen yet" in capsys.readouterr().err
    for text in ("Too few arguments provided (1 required but 0 were provided.)",
                 "Too many arguments provided (1 required but 2 were provided.)",
                 "Function not found.", "Target not found.", "Unable to parse argument x"):
        assert msg.classify(0, text) == msg.EXIT_ERROR, text
    assert msg.classify(0, '{"monitors": []}') == msg.EXIT_OK
    assert msg.classify(1, "ok") == msg.EXIT_ERROR


def test_empty_answer_exits_nonzero(fake_qs: FakeQs) -> None:
    fake_qs.answer = "\n"
    code, answer = msg.call(paths.get(), "surface", "back", [])
    assert code == msg.EXIT_ERROR and answer
    assert msg.classify(0, "  \n") == msg.EXIT_ERROR


def test_timeout(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, stub_bin) -> None:
    # A real (fake) qs that hangs, like a frozen shell.
    bin_dir = tmp_path / "fake-bin"
    stub_bin(bin_dir, "qs", "#!/usr/bin/python3\nimport time\ntime.sleep(30)\n")
    monkeypatch.setenv("PATH", f"{bin_dir}:/usr/bin")
    start = time.monotonic()
    code, answer = msg.call(paths.get(), "session", "lock", [], timeout=0.8)
    assert code == msg.EXIT_TIMEOUT and "did not answer" in answer
    assert time.monotonic() - start < 3
    assert msg.TIMEOUT == 2.0
