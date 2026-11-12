-- aptus paint (09-hyprland §4): what Hyprland takes from generated.lua. look.lua applies it at
-- start; the theme's builtin:hyprland hook (lib/aptus/theme/hooks.py) again after each render,
-- through `hyprctl eval` with this file's path.
return function(gen)
  local side = gen.frame_edge + gen.window_gap      -- 6 + 8 = 14
  hl.config({
    general = {
      gaps_out = { top = gen.window_gap, right = side, bottom = side, left = side },
      col = { active_border = gen.accent, inactive_border = gen.line },
    },
    decoration = { shadow = { color = gen.shadow } },
    misc = { background_color = gen.ground },
  })
end
