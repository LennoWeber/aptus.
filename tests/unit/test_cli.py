"""aptus CLI: logs queries, dev flag, version."""
from __future__ import annotations

import json
import os
from pathlib import Path

import pytest

from aptus import cli, msg
from aptus.paths import get


def test_logs_two_queries(tmp_path: Path, monkeypatch: pytest.MonkeyPatch,
                          capsys: pytest.CaptureFixture[str]) -> None:
    tags, unit = cli.journal_queries(None)
    assert tags[:5] == ["journalctl", "--user", "--no-pager", "-o", "json"]
    assert [tags[i + 1] for i, a in enumerate(tags) if a == "-t"] == \
        ["aptus-shell", "aptus-session", "aptus-supervise"]
    assert "-u" not in tags and "-t" not in unit and unit[-2:] == ["-u", "aptus-*"]
    assert cli.journal_queries("shell")[0][-2:] == ["-t", "aptus-shell"]
    assert cli.journal_queries("guard") == [unit[:-1] + ["aptus-guard"]]
    assert cli.journal_queries("aptus-guard") == cli.journal_queries("guard")

    # A fake journalctl answers each query with its own lines; one line matches both (same cursor).
    fake = tmp_path / "bin"
    fake.mkdir()
    shared = {"__CURSOR": "c-both", "__REALTIME_TIMESTAMP": "1500000", "MESSAGE": "both",
              "SYSLOG_IDENTIFIER": "x"}
    by_tag = {"__CURSOR": "c1", "__REALTIME_TIMESTAMP": "3000000", "MESSAGE": "from the shell",
              "SYSLOG_IDENTIFIER": "aptus-shell", "_PID": "42"}
    by_unit = {"__CURSOR": "c2", "__REALTIME_TIMESTAMP": "2000000", "MESSAGE": [104, 105],
               "_SYSTEMD_USER_UNIT": "aptus-guard.service"}
    tag_out, unit_out = ("\n".join(json.dumps(e) for e in lines) for lines in
                         ([shared, by_tag, ], [shared, by_unit]))
    script = fake / "journalctl"
    script.write_text(f"#!/bin/sh\ncase \"$*\" in *' -u '*) cat <<'EOF'\n{unit_out}\nEOF\n;; "
                      f"*) cat <<'EOF'\n{tag_out}\nEOF\n;; esac\n")
    script.chmod(0o755)
    monkeypatch.setenv("PATH", f"{fake}{os.pathsep}{os.environ['PATH']}")
    assert cli.main(["logs"]) == 0
    lines = capsys.readouterr().out.splitlines()
    assert len(lines) == 3                                   # the shared line prints once
    assert [l.split(": ", 1)[1] for l in lines] == ["both", "hi", "from the shell"]  # by time
    assert "aptus-shell[42]" in lines[2]


def test_logs_without_journalctl(monkeypatch: pytest.MonkeyPatch, tmp_path: Path,
                                 capsys: pytest.CaptureFixture[str]) -> None:
    monkeypatch.setenv("PATH", str(tmp_path))
    assert cli.cmd_logs(False, None) == 1
    assert "journalctl is not installed" in capsys.readouterr().err


def test_dev_flag(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    p = get()
    calls: list[tuple] = []
    monkeypatch.setattr(msg, "call", lambda paths, t, f, a, *x, **k: calls.append((t, f, a))
                        or (msg.EXIT_OK, "ok"))
    assert cli.main(["dev"]) == 0
    assert capsys.readouterr().out.strip() == "dev mode off"
    assert cli.main(["dev", "on"]) == 0
    assert p.dev_flag.exists() and p.restart_flag.exists()
    assert calls == [("shell", "restart", [])]
    assert cli.main(["dev"]) == 0 and "dev mode on" in capsys.readouterr().out.splitlines()[-1]
    assert cli.main(["dev", "off"]) == 0
    assert not p.dev_flag.exists()


def test_dev_flag_shell_down(monkeypatch: pytest.MonkeyPatch,
                             capsys: pytest.CaptureFixture[str]) -> None:
    p = get()
    monkeypatch.setattr(msg, "call", lambda *a, **k: (1, "no shell running"))
    assert cli.main(["dev", "on"]) == 0
    assert p.dev_flag.exists()
    assert not p.restart_flag.exists()          # a stale flag would restart a clean exit
    assert "not restarted" in capsys.readouterr().out


def test_version(capsys: pytest.CaptureFixture[str]) -> None:
    assert cli.main(["version"]) == 0
    assert capsys.readouterr().out.strip() == f"aptus {cli.VERSION}"
    assert cli.VERSION.startswith("2.")
    assert cli.main([]) == 2
    assert cli.main(["theme"]) == 2             # arrives with S2
