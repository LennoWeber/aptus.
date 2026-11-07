-- aptus: entry point, loaded from the marked block at the end of hyprland.lua (09-hyprland §2)
local home  = os.getenv("HOME")
local state = home .. "/.local/state/aptus/hypr/"

-- Generated values (colours, gaps, flags). Defaults keep Hyprland usable before the first render.
local gen = {
  ground = "rgb(191613)", line = "rgb(332d27)", accent = "rgb(9acfae)", shadow = "rgba(00000061)",
  frame_edge = 6, window_gap = 8, glass = false, reduce_motion = false,
}
local path = state .. "generated.lua"
-- TODO(phase): load generated.lua over the defaults (pcall(dofile); a broken file → notification,
--   defaults stay); package.loaded["aptus.gen"] = gen.
-- TODO(phase): require aptus.env, aptus.look, aptus.motion, aptus.rules, aptus.binds (09 §2).
-- TODO(phase): hl.on("hyprland.start") → ~/.local/bin/aptus-session start.
