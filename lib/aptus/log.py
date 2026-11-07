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


def setup(name: str) -> logging.Logger:
    """A logger writing "<name>: <level>: <message>" to stderr. In tests (APTUS_TEST=1) it also
    appends to $HOME/aptus-<name>.log."""
    raise NotImplementedError
