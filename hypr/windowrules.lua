-- aptus: window rules. Blur is requested by the shell itself (BackgroundEffect), so there are NO layer rules for blur.
-- Windows that stay fully opaque (video, games, anything where colour or text must be exact): window classes, matched as regex.
local opaqueClasses = { "^mpv$", "^vlc$", "^org.kde.haruna$", "^steam_app_.*$", "^com.obsproject.Studio$", "^org.gimp.GIMP$", "^krita$", "^Inkscape$" }
for _, class in ipairs(opaqueClasses) do
	assert(type(class) == "string" and class ~= "", "aptus windowrules: empty opaque class")
end

for _, class in ipairs(opaqueClasses) do
	hl.window_rule({ match = { class = class }, opaque = true })
end
hl.window_rule({ match = { fullscreen = true }, opaque = true })

-- The settings app is a normal window; it floats at a fixed size so it looks like a small app, not a tile.
hl.window_rule({ match = { title = "^aptus settings$" }, float = true, size = { 980, 680 }, center = true })

-- The shell animates its own surfaces.
hl.layer_rule({ match = { namespace = "^aptus-.*$" }, no_anim = true })

-- Note: idle inhibit for fullscreen windows is handled by Idle.fullscreenInhibit, not by a rule here.
return {}
