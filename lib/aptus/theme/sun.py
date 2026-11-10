"""Sunrise and sunset (NOAA, no network) for appearance.mode = auto at session start, a port of
shell/core/js/sun.js (same local-time arithmetic, including its day-of-year across DST).
Without a location: 07:00 and 19:00 local time. Datetimes are naive local time."""
from __future__ import annotations

import calendar
import math
import time
from datetime import datetime
from typing import Any

FALLBACK_SUNRISE = (7, 0)
FALLBACK_SUNSET = (19, 0)
RAD = math.pi / 180


def _local_ts(y: int, mo: int, d: int, h: int = 0) -> float:
    return time.mktime((y, mo, d, h, 0, 0, 0, 0, -1))


def _event_minutes(day: datetime, lat: float, lon: float, rising: bool) -> float | str:
    """Minutes after local midnight, or "day"/"night" when the sun does not cross the horizon."""
    start = _local_ts(day.year, 1, 1)
    day_of_year = math.floor((_local_ts(day.year, day.month, day.day) - start) / 86400) + 1
    gamma = 2 * math.pi / 365 * (day_of_year - 1)
    eqtime = 229.18 * (0.000075 + 0.001868 * math.cos(gamma) - 0.032077 * math.sin(gamma)
                       - 0.014615 * math.cos(2 * gamma) - 0.040849 * math.sin(2 * gamma))
    decl = (0.006918 - 0.399912 * math.cos(gamma) + 0.070257 * math.sin(gamma)
            - 0.006758 * math.cos(2 * gamma) + 0.000907 * math.sin(2 * gamma)
            - 0.002697 * math.cos(3 * gamma) + 0.00148 * math.sin(3 * gamma))
    cos_h = (math.cos(90.833 * RAD) / (math.cos(lat * RAD) * math.cos(decl))
             - math.tan(lat * RAD) * math.tan(decl))
    if cos_h > 1 or cos_h < -1:
        return "night" if cos_h > 1 else "day"
    ha = math.acos(cos_h) / RAD
    utc_minutes = 720 - 4 * (lon + (ha if rising else -ha)) - eqtime
    noon = _local_ts(day.year, day.month, day.day, 12)
    offset = (calendar.timegm(time.localtime(noon)) - noon) / 60
    return utc_minutes + offset


def _at(day: datetime, minutes: float) -> datetime:
    midnight = _local_ts(day.year, day.month, day.day)
    return datetime.fromtimestamp(midnight + math.floor(minutes * 60 + 0.5))


def times(day: datetime, location: dict[str, Any] | None) -> tuple[datetime, datetime]:
    """(sunrise, sunset) of `day`'s local calendar date; polar day 00:00–24:00, polar night empty
    (both 12:00)."""
    lat = location.get("lat") if isinstance(location, dict) else None
    lon = location.get("lon") if isinstance(location, dict) else None
    if not isinstance(lat, (int, float)) or not isinstance(lon, (int, float)) \
            or isinstance(lat, bool) or isinstance(lon, bool):
        return (_at(day, FALLBACK_SUNRISE[0] * 60 + FALLBACK_SUNRISE[1]),
                _at(day, FALLBACK_SUNSET[0] * 60 + FALLBACK_SUNSET[1]))
    r = _event_minutes(day, lat, lon, True)
    s = _event_minutes(day, lat, lon, False)
    if isinstance(r, str) or isinstance(s, str):
        polar = r if isinstance(r, str) else s
        if polar == "day":
            return _at(day, 0), _at(day, 24 * 60)
        return _at(day, 12 * 60), _at(day, 12 * 60)
    return _at(day, r), _at(day, s)


def mode_at(now: datetime, location: dict[str, Any] | None) -> str:
    """"light" between sunrise and sunset, else "dark"."""
    sunrise, sunset = times(now, location)
    return "light" if sunrise <= now < sunset else "dark"
