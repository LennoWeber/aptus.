-- aptus look (09-hyprland §4); the generated values (borders, gaps, shadow, background) in paint.lua
local gen = require("aptus.gen")

hl.config({
  general = {
    gaps_in  = 4,                                    -- 4 + 4 = 8 between windows
    border_size = 2,
    resize_on_border = true,
    extend_border_grab_area = 12,
    layout = "dwindle",
  },
  decoration = {
    rounding = 10,                                   -- window.radius
    rounding_power = 2,
    shadow = { enabled = true, range = 18, render_power = 3, offset = { 0, 4 } },
    blur   = { enabled = true, size = 6, passes = 2, popups = false, special = false },
    dim_special = 0.25,
  },
  misc = {
    disable_hyprland_logo   = true,
    force_default_wallpaper = 0,
    disable_splash_rendering = true,
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
require("aptus.paint")(gen)
