-- aptus motion (09-hyprland §6)
local gen = require("aptus.gen")

hl.curve("aptus_standard", { type = "bezier", points = { { 0.2, 0 },   { 0, 1 }    } })
hl.curve("aptus_enter",    { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 }  } })
hl.curve("aptus_exit",     { type = "bezier", points = { { 0.3, 0 },   { 0.8, 0.15 } } })
hl.curve("aptus_move",     { type = "spring", mass = 1, stiffness = 260, damping = 32.3 })  -- ζ ≈ 1.0

local A = function(t) t.enabled = true; hl.animation(t) end

if not gen.reduce_motion then
  A({ leaf = "windowsIn",        speed = 2.8, bezier = "aptus_enter",    style = "popin 92%" })
  A({ leaf = "windowsOut",       speed = 1.6, bezier = "aptus_exit",     style = "popin 95%" })
  A({ leaf = "windowsMove",      speed = 2.6, spring = "aptus_move" })
  A({ leaf = "fadeIn",           speed = 2.0, bezier = "aptus_standard" })
  A({ leaf = "fadeOut",          speed = 1.4, bezier = "aptus_standard" })
  A({ leaf = "border",           speed = 2.4, bezier = "aptus_standard" })
  A({ leaf = "workspaces",       speed = 2.6, bezier = "aptus_enter",    style = "slidefade 12%" })
  A({ leaf = "specialWorkspace", speed = 2.8, bezier = "aptus_enter",    style = "slidefadevert 14%" })
  A({ leaf = "layers",           speed = 2.0, bezier = "aptus_enter",    style = "fade" })
  A({ leaf = "zoomFactor",       speed = 3.0, bezier = "aptus_standard" })
else
  A({ leaf = "windowsIn",        speed = 1.2, bezier = "aptus_standard", style = "fade" })
  A({ leaf = "windowsOut",       speed = 1.2, bezier = "aptus_standard", style = "fade" })
  A({ leaf = "windowsMove",      speed = 1.2, bezier = "aptus_standard" })
  A({ leaf = "workspaces",       speed = 1.2, bezier = "aptus_standard", style = "fade" })
  A({ leaf = "specialWorkspace", speed = 1.2, bezier = "aptus_standard", style = "fade" })
  A({ leaf = "layers",           speed = 1.2, bezier = "aptus_standard", style = "fade" })
end
