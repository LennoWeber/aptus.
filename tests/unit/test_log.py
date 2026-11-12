"""Logging setup (07 §11)."""
from __future__ import annotations

import logging
import os
import pwd
import socket
import struct
from pathlib import Path

import pytest

from aptus import log


def test_level_from_env() -> None:
    assert log.level_from_env({}) == logging.INFO
    assert log.level_from_env({"APTUS_LOG": "debug"}) == logging.DEBUG
    assert log.level_from_env({"APTUS_LOG": "warn"}) == logging.WARNING
    assert log.level_from_env({"APTUS_LOG": "ERROR"}) == logging.ERROR


def test_unknown_level_is_info() -> None:
    assert log.level_from_env({"APTUS_LOG": "verbose"}) == logging.INFO
    assert log.level_from_env({"APTUS_LOG": ""}) == logging.INFO


def test_test_mode_log_file(test_home: Path) -> None:
    logger = log.setup("unittest")
    logger.info("hello %s", "there")
    logger.debug("not at info level")
    logger.warning("careful")
    for h in logger.handlers:
        h.flush()
    text = (test_home / "aptus-unittest.log").read_text()
    assert "unittest: info: hello there\n" in text
    assert "unittest: warn: careful\n" in text
    assert "not at info level" not in text


def test_journal_handler_outside_units(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    server = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    path = tmp_path / "journal.sock"
    server.bind(str(path))
    server.settimeout(2)
    handler = log.JournalHandler("aptus-session")
    handler.path = str(path)
    handler.setFormatter(logging.Formatter("%(message)s"))
    handler.emit(logging.LogRecord("x", logging.WARNING, __file__, 1, "low battery", None, None))
    fields = dict(line.split("=", 1) for line in server.recv(4096).decode().splitlines())
    assert fields == {"MESSAGE": "low battery", "PRIORITY": "4",
                      "SYSLOG_IDENTIFIER": "aptus-session"}
    # A multi-line message uses the binary form: KEY\n<u64 length><value>\n.
    handler.emit(logging.LogRecord("x", logging.INFO, __file__, 1, "a\nb", None, None))
    data = server.recv(4096)
    assert data.startswith(b"MESSAGE\n" + struct.pack("<Q", 3) + b"a\nb\n")
    assert b"PRIORITY=6\n" in data
    server.close()
    # Never raises, even without a journal.
    handler.path = str(tmp_path / "missing.sock")
    handler.emit(logging.LogRecord("x", logging.ERROR, __file__, 1, "lost", None, None))
    # setup() adds it outside tests and outside units only.
    # (A logger name of its own: nothing else logs through it, so nothing reaches the journal.)
    monkeypatch.delenv("APTUS_TEST")
    logger = log.setup("journaltest", tag="aptus-session")
    assert any(isinstance(h, log.JournalHandler) and h.tag == "aptus-session"
               for h in logger.handlers)
    assert not log.under_unit()
    monkeypatch.setenv("INVOCATION_ID", "abc")
    assert log.under_unit()
    logger = log.setup("journaltest")
    assert not any(isinstance(h, log.JournalHandler) for h in logger.handlers)


def test_no_journal_in_tests() -> None:
    logger = log.setup("supervise")
    assert not any(isinstance(h, log.JournalHandler) for h in logger.handlers)
    assert any(isinstance(h, logging.FileHandler) for h in logger.handlers)
    assert not logger.propagate


def test_setup_tool_refuses_before_any_log(tmp_path: Path, monkeypatch: pytest.MonkeyPatch,
                                           capsys: pytest.CaptureFixture[str]) -> None:
    """The tools' prologue: an unsafe HOME under APTUS_TEST is refused on stderr with the tool's
    prefix, before a log file exists; a safe one gives the paths and the tool's logger, and the
    other modules' loggers log under the tool's tag."""
    monkeypatch.setenv("HOME", pwd.getpwuid(os.getuid()).pw_dir)
    assert log.setup_tool("guard", "lease", refusing="refusing: ") is None
    err = capsys.readouterr().err
    assert err.startswith("aptus-guard: refusing: APTUS_TEST=1 but HOME"), err
    home = tmp_path / "other-home"
    monkeypatch.setenv("HOME", str(home))
    assert log.setup_tool("lease") is None                       # not a directory
    assert capsys.readouterr().err.startswith("aptus-lease: APTUS_TEST=1 but HOME")
    assert not home.exists()
    home.mkdir()
    paths, logger = log.setup_tool("theme", "lease")
    assert paths.home == home and logger.name == "aptus.theme"
    logging.getLogger("aptus.lease").warning("from the lease")
    for h in logging.getLogger("aptus.lease").handlers:
        h.flush()
    assert "lease: warn: from the lease" in (home / "aptus-lease.log").read_text()
