"""Logging for the session tools (07-architecture §11): Python logging to stderr; inside units
it reaches the journal with the unit name; aptus-session uses the tag aptus-session. Level from
APTUS_LOG (default info). Never log notification bodies, clipboard content, passwords, calendar
URLs or window titles above debug."""
from __future__ import annotations

import logging
import os
import socket
import struct
import sys
from collections.abc import Mapping


LEVELS = {"debug": logging.DEBUG, "info": logging.INFO, "warn": logging.WARNING,
          "error": logging.ERROR}


def level_from_env(env: Mapping[str, str] | None = None) -> int:
    """APTUS_LOG (debug|info|warn|error), default info; unknown names fall back to info."""
    env = os.environ if env is None else env
    return LEVELS.get(env.get("APTUS_LOG", "").strip().lower(), logging.INFO)


def under_unit(env: Mapping[str, str] | None = None) -> bool:
    """Running inside a systemd unit (INVOCATION_ID set): stderr already reaches the journal."""
    env = os.environ if env is None else env
    return bool(env.get("INVOCATION_ID"))


class JournalHandler(logging.Handler):
    """Sends records to journald's native socket (/run/systemd/journal/socket, one datagram per
    record: MESSAGE, PRIORITY, SYSLOG_IDENTIFIER) so tools exec'd by Hyprland, not by a unit
    (aptus-session, aptus-supervise), still log under their tag. Stdlib only; never raises."""

    def __init__(self, tag: str) -> None:
        super().__init__()
        self.tag = tag
        self.path = "/run/systemd/journal/socket"
        self.sock: socket.socket | None = None

    def emit(self, record: logging.LogRecord) -> None:
        try:
            priority = (7 if record.levelno < logging.INFO else 6 if record.levelno < logging.WARNING
                        else 4 if record.levelno < logging.ERROR else 3
                        if record.levelno < logging.CRITICAL else 2)
            payload = b""
            for key, value in (("MESSAGE", self.format(record)), ("PRIORITY", str(priority)),
                               ("SYSLOG_IDENTIFIER", self.tag)):
                data = value.encode("utf-8", "replace")
                if b"\n" in data:     # the binary form of the native protocol
                    payload += key.encode() + b"\n" + struct.pack("<Q", len(data)) + data + b"\n"
                else:
                    payload += key.encode() + b"=" + data + b"\n"
            if self.sock is None:
                self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
            self.sock.sendto(payload, self.path)
        except Exception:      # never raises: logging must not take a tool down
            pass


def setup(name: str, tag: str | None = None) -> logging.Logger:
    """A logger writing "<name>: <level>: <message>" to stderr, plus a JournalHandler with `tag`
    (default aptus-<name>) when not under a unit. In tests (APTUS_TEST=1) never the journal: it
    appends to $HOME/aptus-<name>.log instead."""
    from .paths import ENV_TEST, get

    logger = logging.getLogger(f"aptus.{name}")
    for old in list(logger.handlers):
        logger.removeHandler(old)
        old.close()
    logger.setLevel(level_from_env())
    logger.propagate = False
    names = {logging.DEBUG: "debug", logging.INFO: "info", logging.WARNING: "warn",
             logging.ERROR: "error", logging.CRITICAL: "critical"}

    def short_level(record: logging.LogRecord) -> bool:
        record.aptus_level = names.get(record.levelno, record.levelname.lower())
        return True

    formatter = logging.Formatter(f"{name}: %(aptus_level)s: %(message)s")
    handlers: list[logging.Handler] = [logging.StreamHandler(sys.stderr)]
    if os.environ.get(ENV_TEST) == "1":
        handlers.append(logging.FileHandler(get().home / f"aptus-{name}.log", encoding="utf-8"))
    elif not under_unit():
        handlers.append(JournalHandler(tag or f"aptus-{name}"))
    for handler in handlers:
        handler.addFilter(short_level)
        handler.setFormatter(formatter)
        logger.addHandler(handler)
    return logger
