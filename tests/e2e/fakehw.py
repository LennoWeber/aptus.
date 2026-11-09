"""Fake hardware for the S3 e2e tests (brief: never the real backlight or keyboard LED).

A sysfs-like tree (`class/backlight/<dev>/{brightness,max_brightness,actual_brightness}`,
`class/leds/<dev>/{brightness,max_brightness}`) in the test's temporary folder, and a
`brightnessctl` on PATH that writes only into that tree. The shell finds the tree through
`APTUS_SYSFS`; nothing here ever opens /sys.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass
class FakeHardware:
    root: Path                      # the folder holding sysfs/ and bin/
    backlight: str = "intel_backlight"
    backlight_max: int = 400
    backlight_now: int = 200
    kbd: str = "tpacpi::kbd_backlight"
    kbd_max: int = 2
    kbd_now: int = 0
