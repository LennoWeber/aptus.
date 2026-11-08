-- aptus: entry point, loaded from the marked block at the end of hyprland.lua
local home  = os.getenv("HOME")
local state = home .. "/.local/state/aptus/hypr/"

-- Generated values (colours, gaps, flags). Defaults keep Hyprland usable before the first render.
local gen = {
  ground = "rgb(191613)", line = "rgb(332d27)", accent = "rgb(9acfae)", shadow = "rgba(00000061)",
  frame_edge = 6, window_gap = 8, glass = false, reduce_motion = false,
}
local path = state .. "generated.lua"
local f = io.open(path, "r")
if f then
  f:close()
  local ok, t = pcall(dofile, path)
  if ok and type(t) == "table" then
    for k, v in pairs(t) do gen[k] = v end
  else
    hl.notification.create({ text = "aptus: generated.lua failed to load, using defaults", timeout = 8000 })
  end
end
package.loaded["aptus.gen"] = gen

require("aptus.env")
require("aptus.look")
require("aptus.motion")
require("aptus.rules")
require("aptus.binds")

hl.on("hyprland.start", function()
  hl.exec_cmd(home .. "/.local/bin/aptus-session start")
end)
