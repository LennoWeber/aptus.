-- aptus: window rules. Blur is requested by the shell itself (BackgroundEffect), so there are NO layer rules for blur.
-- Windows that stay fully opaque (video, games, anything where colour or text must be exact): window classes, matched as regex.
local opaqueClasses = { "^mpv$", "^vlc$", "^org.kde.haruna$", "^steam_app_.*$", "^com.obsproject.Studio$", "^org.gimp.GIMP$", "^krita$", "^Inkscape$" }

-- The settings app is a normal window; it floats at a fixed size so it looks like a small app, not a tile.
hl.window_rule({ match = { title = "^aptus settings$" }, float = true, size = { 980, 680 }, center = true })

-- TODO(phase 7, later): optional: layer rule no_anim for namespaces 'aptus-*' (the shell animates itself).
-- Note: idle inhibit for fullscreen windows is handled by Idle.fullscreenInhibit, not by a rule here.
return {}
