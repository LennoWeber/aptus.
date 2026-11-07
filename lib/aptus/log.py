"""Logging for the session tools (07-architecture §11): Python logging to stderr; inside units
it reaches the journal with the unit name; aptus-session uses the tag aptus-session. Level from
APTUS_LOG (default info). Never log notification bodies, clipboard content, passwords, calendar
URLs or window titles above debug."""
from __future__ import annotations
