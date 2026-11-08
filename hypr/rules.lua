-- aptus rules (09-hyprland §5)
local gen = require("aptus.gen")

-- Layers: the shell animates itself; Hyprland must not animate aptus layers.
hl.layer_rule({ name = "aptus-no-anim", match = { namespace = "^aptus-" }, no_anim = true })
hl.layer_rule({
  name = "aptus-glass", match = { namespace = "^aptus-shell$" },
  blur = true, ignore_alpha = 0.5, enabled = gen.glass,
})
hl.layer_rule({ name = "aptus-recframe", match = { namespace = "^aptus-recframe$" }, no_screen_share = true })

-- Windows
hl.window_rule({
  name = "aptus-settings", match = { class = "^aptus-settings$" },
  float = true, size = "920 640", center = true,
})
hl.window_rule({
  name = "aptus-scratch", match = { class = "^aptus\\.scratch$" },
  float = true, size = "monitor_w*0.7 monitor_h*0.6", move = "monitor_w*0.15 40",
})
hl.window_rule({
  name = "aptus-satty", match = { class = "^com\\.gabm\\.satty$" },
  float = true, size = "monitor_w*0.8 monitor_h*0.8", center = true,
})
hl.window_rule({
  name = "aptus-pip", match = { title = "^Picture-in-Picture$" },
  float = true, pin = true, keep_aspect_ratio = true,
  size = "480 270", move = "monitor_w-494 monitor_h-284",   -- 14 px inside the frame's corner
})
hl.window_rule({
  name = "aptus-portal-dialogs", match = { class = "^(xdg-desktop-portal-gtk|org\\.freedesktop\\.impl\\.portal\\..*)$" },
  float = true, center = true,
})
hl.window_rule({
  name = "aptus-idle-fullscreen", match = { class = ".*" },
  idle_inhibit = "fullscreen",
})

-- The scratch workspace starts its terminal on first use (a workspace.created handler: the
-- on_created_empty rule is deprecated in Hyprland 0.57)
hl.on("workspace.created", function(ws)
  if ws.name == "special:scratch" and ws.is_empty then hl.exec_cmd("ghostty --class=aptus.scratch") end
end)
