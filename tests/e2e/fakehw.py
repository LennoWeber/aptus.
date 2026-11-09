"""Fake hardware for the S3 e2e tests (brief: never the real backlight or keyboard LED).

A sysfs-like tree (`class/backlight/<dev>/{brightness,max_brightness,actual_brightness}`,
`class/leds/<dev>/{brightness,max_brightness}`) in the test's temporary folder, and a
`brightnessctl` on PATH that writes only into that tree. The shell finds the tree through
`APTUS_SYSFS`; nothing here ever opens /sys.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

# The fake `brightnessctl`: understands `-d <device> set <n>` (and `-m`/`info` for a read) and
# writes only below $APTUS_SYSFS; refuses to run without it.
BRIGHTNESSCTL = ""


@dataclass
class FakeHardware:
    root: Path                      # the folder holding sysfs/ and bin/
    backlight: str = "intel_backlight"
    backlight_max: int = 400
    backlight_now: int = 200
    kbd: str = "tpacpi::kbd_backlight"
    kbd_max: int = 2
    kbd_now: int = 0

    def build(self) -> dict[str, str]:
        """Write the tree and the fake tool; return the environment additions for the session
        (APTUS_SYSFS and a PATH with the fake bin first)."""
        raise NotImplementedError

    def backlight_value(self) -> int:
        raise NotImplementedError

    def kbd_value(self) -> int:
        raise NotImplementedError
