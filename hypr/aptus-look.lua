-- aptus: window look. Loaded by the user's hyprland.lua only while aptus is the chosen shell
-- (same pattern as the L-Shell design file). Installed to ~/.local/state/aptus/hyprland-look.lua,
-- so a settings change can rewrite and reload it.
-- Monitor, input and touch settings stay in the user's own file.

hl.config({
	general = {
		gaps_in = 4,
		gaps_out = 8,
		-- one hairline, dark on light, no colour accent
		border_size = 1,
		col = {
			-- TODO(phase 7, Bild-Theming): borders and shadow use the Standard ink. Decide whether they follow the style ink (generated) or stay.
			active_border = "rgba(1c212740)",
			inactive_border = "rgba(1c212718)",
		},
	},

	decoration = {
		rounding = 10,
		rounding_power = 2,
		-- soft, short shadow, barely there
		shadow = {
			enabled = true,
			range = 18,
			render_power = 3,
			offset = "0 4",
			color = "rgba(1c212721)",
		},
		-- blur stays on globally; windows have none of their own, the shell asks for it per surface
		blur = {
			enabled = true,
			size = 8,
			passes = 3,
			brightness = 1.0,
			vibrancy = 0.1,
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
