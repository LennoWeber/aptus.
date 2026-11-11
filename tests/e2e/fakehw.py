"""Fake hardware for the S3 e2e tests (brief: never the real backlight or keyboard LED).

A sysfs-like tree (`class/backlight/<dev>/{brightness,max_brightness,actual_brightness}`,
`class/leds/<dev>/{brightness,max_brightness}`) in the test's temporary folder, and a
`brightnessctl` on PATH that writes only into that tree. The shell finds the tree through
`APTUS_SYSFS`; nothing here ever opens /sys.
"""
from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path


def brightnessctl_script() -> str:
    """The fake `brightnessctl` (a shell script): understands `-d <device> set <n>` (and `-m`/`info`
    for a read), writes only below $APTUS_SYSFS and refuses to run without it."""
    return r'''#!/bin/sh
# Fake brightnessctl for the aptus e2e tests: writes only below $APTUS_SYSFS (never /sys).
case "${APTUS_SYSFS:-}" in
    ""|/sys|/sys/*) echo "fake brightnessctl: no test sysfs" >&2; exit 2 ;;
esac
dev="" value="" read=0
while [ $# -gt 0 ]; do
    case "$1" in
        -d) dev="$2"; shift 2 ;;
        -q|-m) shift ;;
        set) value="$2"; shift 2 ;;
        info|get) read=1; shift ;;
        *) shift ;;
    esac
done
dir=""
for d in "$APTUS_SYSFS/class/backlight/$dev" "$APTUS_SYSFS/class/leds/$dev"; do
    [ -n "$dev" ] && [ -d "$d" ] && dir="$d"
done
[ -n "$dir" ] || { echo "fake brightnessctl: no device $dev" >&2; exit 1; }
max=$(cat "$dir/max_brightness")
if [ -n "$value" ]; then
    case "$value" in *[!0-9]*) echo "fake brightnessctl: only absolute values" >&2; exit 1 ;; esac
    [ "$value" -gt "$max" ] && value="$max"
    printf '%s\n' "$value" > "$dir/brightness"
    [ -f "$dir/actual_brightness" ] && printf '%s\n' "$value" > "$dir/actual_brightness"
    printf '%s %s\n' "$dev" "$value" >> "$APTUS_SYSFS/brightnessctl.log"
fi
[ "$read" = 1 ] && printf '%s,%s,%s,%s%%,%s\n' "$dev" "class" "$(cat "$dir/brightness")" \
    "$(( $(cat "$dir/brightness") * 100 / max ))" "$max"
exit 0
'''


@dataclass
class FakeHardware:
    root: Path                      # the folder holding sysfs/ and bin/
    # Test device names only (Brightness refuses any other under APTUS_TEST): a real
    # brightnessctl that slipped onto PATH finds no such device.
    backlight: str = "aptus_test_backlight"
    backlight_max: int = 400
    backlight_now: int = 200
    kbd: str = "aptus_test::kbd_backlight"
    kbd_max: int = 2
    kbd_now: int = 0

    @property
    def sysfs(self) -> Path:
        return self.root / "sysfs"

    def build(self) -> dict[str, str]:
        """Write the tree and the fake tool; return the environment additions for the session
        (APTUS_SYSFS and a PATH with the fake bin first)."""
        bl = self.sysfs / "class" / "backlight" / self.backlight
        led = self.sysfs / "class" / "leds" / self.kbd
        for d in (bl, led):
            d.mkdir(parents=True, exist_ok=True)
        (bl / "max_brightness").write_text(f"{self.backlight_max}\n")
        (bl / "brightness").write_text(f"{self.backlight_now}\n")
        (bl / "actual_brightness").write_text(f"{self.backlight_now}\n")
        (led / "max_brightness").write_text(f"{self.kbd_max}\n")
        (led / "brightness").write_text(f"{self.kbd_now}\n")
        bin_dir = self.root / "bin"
        bin_dir.mkdir(parents=True, exist_ok=True)
        tool = bin_dir / "brightnessctl"
        tool.write_text(brightnessctl_script())
        tool.chmod(0o755)
        self.battery(present=True, percentage=80, charging=False, on_battery=False)
        return {"APTUS_SYSFS": str(self.sysfs), "PATH": f"{bin_dir}:{os.environ.get('PATH', '/usr/bin')}"}

    def battery(self, present: bool = True, percentage: float = 80, charging: bool = False,
                on_battery: bool = False) -> None:
        """The Power service's battery double under APTUS_TEST (the shell watches the file)."""
        (self.sysfs / "aptus-test-battery.json").write_text(json.dumps(
            {"present": present, "percentage": percentage, "charging": charging, "onBattery": on_battery}) + "\n")

    def backlight_value(self) -> int:
        return int((self.sysfs / "class" / "backlight" / self.backlight / "brightness").read_text())

    def kbd_value(self) -> int:
        return int((self.sysfs / "class" / "leds" / self.kbd / "brightness").read_text())

    def writes(self) -> list[str]:
        """The fake tool's log: one "<device> <value>" line per write."""
        log = self.sysfs / "brightnessctl.log"
        return log.read_text().splitlines() if log.exists() else []
