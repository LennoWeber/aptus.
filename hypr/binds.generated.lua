-- aptus: key binds that only aptus answers (the user's own binds already send `shell-switch msg <command>`).
-- Loaded from the user's hyprland.lua; harmless when aptus is not the running shell.
-- TODO(phase 7, later): generated from config/hotkeys.json (Hotkeys.generateHyprlandLua), plus the lid switch.
local switch = (os.getenv("HOME") or "") .. "/.local/bin/shell-switch msg launcher-open "

hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd(switch .. "web"))
hl.bind("SUPER + A", hl.dsp.exec_cmd(switch .. "ai"))
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd(switch .. "clipboard"))

return {}
