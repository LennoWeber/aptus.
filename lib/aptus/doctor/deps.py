"""`aptus doctor deps`: the packages of 11-roadmap §5 and the forbidden ones of 02 §9."""
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from . import Check


# 11-roadmap §5: (command or package, why).
REQUIRED: tuple[tuple[str, str], ...] = (
    ("qs", "Quickshell 0.3.2"), ("Hyprland", "Hyprland 0.57.1"), ("hyprctl", "Hyprland IPC"),
    ("hyprlock", "lock fallback"), ("wl-copy", "clipboard"), ("cliphist", "clipboard history"),
    ("wtype", "paste-back"), ("plocate", "file search"), ("fd", "file search"),
    ("brightnessctl", "backlight"), ("satty", "screenshot editing"), ("wf-recorder", "recording"),
    ("ffmpeg", "recording"), ("qt6ct", "Qt apps outside KDE"), ("hyprsunset", "night light"),
    ("systemd-cat", "shell log to the journal"), ("journalctl", "aptus logs"), ("grim", "screenshots, e2e tests"),
)
OPTIONAL: tuple[str, ...] = ("ddcutil", "fprintd-verify")
# 02 §9 / 11 §5: never installed for aptus (their presence is reported).
FORBIDDEN_PACKAGES: tuple[str, ...] = ("adw-gtk3-theme", "mako", "dunst", "swaync", "hyprpaper",
                                       "swww", "hyprpolkitagent")
FONTS: tuple[str, ...] = ("Inter", "Inter Display", "JetBrains Mono")
ICON_THEMES: tuple[str, ...] = ("Papirus", "Papirus-Dark")


def check() -> list[Check]:
    from . import Check
    from ..paths import get

    checks: list[Check] = []
    for command, why in REQUIRED:
        found = shutil.which(command)
        checks.append(Check(f"deps: {command}", bool(found), "" if found else f"missing ({why})"))
    for command in OPTIONAL:
        if not shutil.which(command):
            checks.append(Check(f"deps: {command}", True, "not installed (optional)", warn=True))
        else:
            checks.append(Check(f"deps: {command}", True))
    if shutil.which("rpm"):
        for package in FORBIDDEN_PACKAGES:
            done = subprocess.run(["rpm", "-q", "--quiet", package], capture_output=True)
            checks.append(Check(f"deps: no {package}", done.returncode != 0,
                                "" if done.returncode else "installed, but never for aptus (02 §9)"))
    else:
        checks.append(Check("deps: forbidden packages", True, "rpm not found, not checked",
                            warn=True))
    families: set[str] = set()
    try:
        done = subprocess.run(["fc-list", ":", "family"], capture_output=True, text=True)
        for line in done.stdout.splitlines():
            families.update(name.strip() for name in line.split(",") if name.strip())
    except FileNotFoundError:
        pass
    for font in FONTS:
        checks.append(Check(f"deps: font {font}", font in families,
                            "" if font in families else "missing (a system font, see 11 §5)"))
    roots = [Path("/usr/share/icons"), get().data_home / "icons"]
    for theme in ICON_THEMES:
        found = any((root / theme / "index.theme").is_file() for root in roots)
        checks.append(Check(f"deps: icon theme {theme}", found,
                            "" if found else "missing (papirus-icon-theme)"))
    return checks
