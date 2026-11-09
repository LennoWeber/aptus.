"""Sunrise and sunset (NOAA, no network) for appearance.mode = auto at session start, a port of
shell/core/js/sun.js. Without a location: 07:00 and 19:00 local time."""
from __future__ import annotations

from datetime import datetime
from typing import Any

FALLBACK_SUNRISE = (7, 0)
FALLBACK_SUNSET = (19, 0)


def times(day: datetime, location: dict[str, Any] | None) -> tuple[datetime, datetime]:
    """(sunrise, sunset) of `day`'s local calendar date; polar day 00:00–24:00, polar night empty
    (both 12:00)."""
    raise NotImplementedError


def mode_at(now: datetime, location: dict[str, Any] | None) -> str:
    """"light" between sunrise and sunset, else "dark"."""
    raise NotImplementedError
