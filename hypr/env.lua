-- aptus env (09-hyprland §3)
local home = os.getenv("HOME")
local st   = home .. "/.local/state/aptus"

hl.env("APTUS_SESSION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("KITTY_CONFIG_DIRECTORY", st .. "/scope/kitty")
hl.env("STARSHIP_CONFIG", st .. "/scope/starship.toml")
hl.env("YAZI_CONFIG_HOME", st .. "/scope/yazi")
hl.env("BAT_THEME", "aptus")
hl.env("BAT_CACHE_PATH", home .. "/.cache/aptus/bat")
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
