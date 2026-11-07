"""`aptus doctor deps`: the packages of 11-roadmap §5 and the forbidden ones of 02 §9."""
from __future__ import annotations


# 11-roadmap §5: (command or package, why).
REQUIRED: tuple[tuple[str, str], ...] = (
    ("qs", "Quickshell 0.3.2"), ("Hyprland", "Hyprland 0.57.1"), ("hyprctl", "Hyprland IPC"),
    ("hyprlock", "lock fallback"), ("wl-copy", "clipboard"), ("cliphist", "clipboard history"),
    ("wtype", "paste-back"), ("plocate", "file search"), ("fd", "file search"),
    ("brightnessctl", "backlight"), ("satty", "screenshot editing"), ("wf-recorder", "recording"),
    ("ffmpeg", "recording"), ("qt6ct", "Qt apps outside KDE"), ("hyprsunset", "night light"),
    ("fprintd-verify", "fingerprint (optional)"),
)
OPTIONAL: tuple[str, ...] = ("ddcutil", "fprintd-verify")
# 02 §9 / 11 §5: never installed for aptus (their presence is reported).
FORBIDDEN_PACKAGES: tuple[str, ...] = ("adw-gtk3-theme", "mako", "dunst", "swaync", "hyprpaper",
                                       "swww", "hyprpolkitagent")
FONTS: tuple[str, ...] = ("Inter", "Inter Display", "JetBrains Mono")


def check() -> list[Check]:
    raise NotImplementedError
