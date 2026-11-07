"""Logging for the session tools (07-architecture §11): Python logging to stderr; inside units
it reaches the journal with the unit name; aptus-session uses the tag aptus-session. Level from
APTUS_LOG (default info). Never log notification bodies, clipboard content, passwords, calendar
URLs or window titles above debug."""
from __future__ import annotations

import logging
from collections.abc import Mapping


LEVELS = {"debug": logging.DEBUG, "info": logging.INFO, "warn": logging.WARNING,
          "error": logging.ERROR}


def level_from_env(env: Mapping[str, str] | None = None) -> int:
    """APTUS_LOG (debug|info|warn|error), default info; unknown names fall back to info."""
    raise NotImplementedError


def under_unit(env: Mapping[str, str] | None = None) -> bool:
    """Running inside a systemd unit (INVOCATION_ID set): stderr already reaches the journal."""
    raise NotImplementedError


class JournalHandler(logging.Handler):
    """Sends records to journald's native socket (/run/systemd/journal/socket, one datagram per
    record: MESSAGE, PRIORITY, SYSLOG_IDENTIFIER) so tools exec'd by Hyprland, not by a unit
    (aptus-session, aptus-supervise), still log under their tag. Stdlib only; never raises."""

    def __init__(self, tag: str) -> None:
        raise NotImplementedError

    def emit(self, record: logging.LogRecord) -> None:
        raise NotImplementedError


def setup(name: str, tag: str | None = None) -> logging.Logger:
    """A logger writing "<name>: <level>: <message>" to stderr, plus a JournalHandler with `tag`
    (default aptus-<name>) when not under a unit. In tests (APTUS_TEST=1) never the journal: it
    appends to $HOME/aptus-<name>.log instead."""
    raise NotImplementedError
