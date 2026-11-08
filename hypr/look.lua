-- aptus look (09-hyprland §4)
local gen  = require("aptus.gen")
local side = gen.frame_edge + gen.window_gap        -- 6 + 8 = 14

hl.config({
  general = {
    gaps_in  = 4,                                    -- 4 + 4 = 8 between windows
    gaps_out = { top = gen.window_gap, right = side, bottom = side, left = side },
    border_size = 2,
    col = { active_border = gen.accent, inactive_border = gen.line },
    resize_on_border = true,
    extend_border_grab_area = 12,
    layout = "dwindle",
  },
  decoration = {
    rounding = 10,                                   -- window.radius
    rounding_power = 2,
    shadow = { enabled = true, range = 18, render_power = 3, offset = { 0, 4 }, color = gen.shadow },
    blur   = { enabled = true, size = 6, passes = 2, popups = false, special = false },
    dim_special = 0.25,
  },
  misc = {
    disable_hyprland_logo   = true,
    force_default_wallpaper = 0,
    disable_splash_rendering = true,
    background_color = gen.ground,
    allow_session_lock_restore = true,
    key_press_enables_dpms   = true,
    mouse_move_enables_dpms  = true,
    close_special_on_empty   = true,
    animate_manual_resizes   = false,
  },
  binds = {
    hide_special_on_workspace_change = true,
  },
  dwindle = { preserve_split = true },
})
