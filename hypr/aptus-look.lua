-- aptus: window look. Loaded by the user's hyprland.lua only while aptus is the chosen shell
-- (same pattern as the L-Shell design file). Installed to ~/.local/state/aptus/hyprland-look.lua,
-- so a settings change can rewrite and reload it.
-- Monitor, input and touch settings stay in the user's own file.

-- Window transparency and blur: apps stay easy to read (88 % / 80 %), the blur is strong enough to calm the wallpaper behind them.
local windowLook = {
	activeOpacity = 0.88,
	inactiveOpacity = 0.80,
	blurSize = 10,
	blurPasses = 4,
	blurBrightness = 0.9,
	blurContrast = 0.9,
	blurVibrancy = 0.2,
	blurNoise = 0.02,
}

-- Invariants: text must stay readable (no window below 70 % opaque) and the blur must be a real blur.
assert(windowLook.activeOpacity >= 0.7 and windowLook.activeOpacity <= 1, "aptus-look: activeOpacity outside 0.7 to 1")
assert(windowLook.inactiveOpacity >= 0.7 and windowLook.inactiveOpacity <= windowLook.activeOpacity, "aptus-look: inactiveOpacity must be 0.7 to activeOpacity")
assert(windowLook.blurSize >= 1 and windowLook.blurPasses >= 1, "aptus-look: blur needs size and passes of at least 1")

-- Border and shadow colours come from aptus-theme-apps (ink with alpha, so they follow light and dark mode); the literals below are the fallback.
local appColors = {}
do
	local home = os.getenv("HOME") or ""
	local ok, loaded = pcall(dofile, (os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")) .. "/aptus/hyprland-colors.lua")
	if ok and type(loaded) == "table" then appColors = loaded end
end

hl.config({
	general = {
		gaps_in = 4,
		gaps_out = 8,
		-- one hairline, the ink with alpha (dark on light, light on dark), no colour accent
		border_size = 1,
		col = {
			-- TODO(phase 7, Bild-Theming): borders and shadow use the Standard ink. Decide whether they follow the style ink (generated) or stay.
			active_border = appColors.activeBorder or "rgba(1c212740)",
			inactive_border = appColors.inactiveBorder or "rgba(1c212718)",
		},
	},

	decoration = {
		rounding = 10,
		rounding_power = 2,
		active_opacity = windowLook.activeOpacity,
		inactive_opacity = windowLook.inactiveOpacity,
		-- soft, short shadow, barely there
		shadow = {
			enabled = true,
			range = 18,
			render_power = 3,
			offset = "0 4",
			color = appColors.shadow or "rgba(1c212721)",
		},
		-- blur stays on globally and blurs what shows through a transparent window; the shell asks for its own surfaces itself
		blur = {
			enabled = true,
			size = windowLook.blurSize,
			passes = windowLook.blurPasses,
			brightness = windowLook.blurBrightness,
			contrast = windowLook.blurContrast,
			vibrancy = windowLook.blurVibrancy,
			noise = windowLook.blurNoise,
			popups = true,
		},
	},
})

-- the one easing curve: [0.2, 0, 0, 1]; speeds are in units of 100 ms (2.6 = 260 ms, 1.4 = 140 ms)
hl.curve("aptus", { type = "bezier", points = { { 0.2, 0 }, { 0, 1 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 2.6, bezier = "aptus" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.4, bezier = "aptus", style = "popin 94%" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.4, bezier = "aptus" })
hl.animation({ leaf = "layers", enabled = true, speed = 1.4, bezier = "aptus", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.6, bezier = "aptus", style = "fade" })
