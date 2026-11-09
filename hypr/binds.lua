-- aptus binds (09-hyprland §7, §8). Every aptus bind unbinds its chord first; descriptions are
-- "aptus:<id> | <Group> | <Description>[ | hidden]" for the Keys service.
local home = os.getenv("HOME")
local G = function(name) return hl.dsp.global("aptus:" .. name) end
-- Locking never fails open: `aptus msg` exits non-zero when the shell is down, frozen (2 s
-- timeout) or answers "error: …" (no lock screen yet); the aptus hyprlock.conf exists only after
-- the first theme render, so plain hyprlock is the last fallback.
local LOCK = home .. "/.local/bin/aptus msg session lock || hyprlock -c "
          .. home .. "/.local/state/aptus/hyprlock.conf || hyprlock"

-- Overrides from Settings › Keys: { [id] = "SUPER + J" | false }
local overrides = {}
do
  local p = home .. "/.local/state/aptus/hypr/binds.local.lua"
  local f = io.open(p, "r")
  if f then f:close(); local ok, t = pcall(dofile, p); if ok and type(t) == "table" then overrides = t end end
end

-- Description format read by the Binds service: "aptus:<id> | <Group> | <Description>[ | hidden]"
-- A chord is unbound only the first time aptus binds it in this load: `SUPER + Super_L` carries
-- two aptus binds (tap on release, hold on long press), and unbinding before the second would
-- delete the first (probe P-03).
local unbound = {}
local function bind(id, chord, action, group, desc, opts)
  local c = overrides[id]
  if c == false then return end
  c = c or chord
  if not unbound[c] then hl.unbind(c); unbound[c] = true end
  local o = {}
  for k, v in pairs(opts or {}) do o[k] = v end      -- L and R are shared; never mutate them
  o.description = "aptus:" .. id .. " | " .. group .. " | " .. desc
  hl.bind(c, action, o)
end

local L, R = { locked = true }, { locked = true, repeating = true }

-- Shell
bind("super-tap",     "SUPER + Super_L",     G("super-tap"),     "Shell", "Spotlight (tap Super) / keys while held", { release = true })
bind("keys-peek",     "SUPER + Super_L",     G("keys-peek"),     "Shell", "Keys while Super is held | hidden", { long_press = true })
bind("spotlight",     "SUPER + Space",       G("spotlight"),     "Shell", "Spotlight")
bind("spotlight-d",   "SUPER + D",           G("spotlight"),     "Shell", "Spotlight | hidden")
bind("spotlight-mx",  "XF86Dictate",         G("spotlight"),     "Shell", "Spotlight (MX Keys) | hidden")
bind("emoji",         "SUPER + period",      G("spotlight-emoji"), "Shell", "Emoji")
bind("emoji-key",     "XF86EmojiPicker",     G("spotlight-emoji"), "Shell", "Emoji | hidden")
bind("clipboard",     "SUPER + SHIFT + V",   G("spotlight-clipboard"), "Shell", "Clipboard history")
bind("overview",      "SUPER + Tab",         G("overview"),      "Shell", "Overview")
bind("switch-next",   "ALT + Tab",           G("switcher-next"), "Windows", "Switch windows")
bind("switch-prev",   "ALT + SHIFT + Tab",   G("switcher-prev"), "Windows", "Switch windows backwards")
bind("switch-commit", "ALT + Alt_L",         G("switcher-commit"), "Windows", "Commit the switcher | hidden", { release = true, transparent = true })
bind("deck",          "SUPER + C",           G("deck"),          "Shell", "Deck")
bind("today",         "SUPER + N",           G("today"),         "Shell", "Today and notifications")
bind("jot",           "SUPER + SHIFT + N",   G("jot"),           "Shell", "Jot a note")
bind("keys",          "SUPER + K",           G("keys"),          "Shell", "Keys")
bind("gallery",       "SUPER + W",           G("gallery"),       "Shell", "Wallpapers")
bind("theme",         "SUPER + T",           G("theme-toggle"),  "Shell", "Light / dark")
bind("settings",      "SUPER + S",           G("settings"),      "Shell", "Settings")
bind("settings-2",    "SUPER + comma",       G("settings"),      "Shell", "Settings | hidden")
bind("session",       "SUPER + X",           G("session"),       "Session", "Session menu")
bind("lock",          "SUPER + L",           hl.dsp.exec_cmd(LOCK), "Session", "Lock")
bind("lock-key",      "XF86ScreenSaver",     hl.dsp.exec_cmd(LOCK), "Session", "Lock | hidden", L)
bind("logout",        "SUPER + M",           G("logout"),        "Session", "Log out")
bind("focus",         "SUPER + SHIFT + F",   G("focus"),         "Focus", "Focus session")
bind("dnd",           "SUPER + SHIFT + D",   G("dnd"),           "Focus", "Do not disturb")
bind("quiet-bar",     "SUPER + SHIFT + B",   G("quiet-bar"),     "Focus", "Quiet bar")

-- Capture
bind("cap-region",    "SUPER + SHIFT + S",   G("capture-region"), "Capture", "Screenshot")
bind("cap-print",     "Print",               G("capture-region"), "Capture", "Screenshot | hidden")
bind("cap-screen",    "SHIFT + Print",       G("capture-screen"), "Capture", "Screenshot of this monitor")
bind("record",        "SUPER + SHIFT + R",   G("record"),         "Capture", "Record / stop")
bind("colour",        "SUPER + SHIFT + C",   G("colour"),         "Capture", "Colour picker")

-- Windows and workspaces (new ones; Lenno's own stay in hyprland.lua)
bind("scratch",       "SUPER + minus",       hl.dsp.workspace.toggle_special("scratch"), "Windows", "Scratch terminal")
bind("to-scratch",    "SUPER + SHIFT + minus", hl.dsp.window.move({ workspace = "special:scratch", follow = false }), "Windows", "Move to scratch")
for dir, key in pairs({ left = "left", right = "right", up = "up", down = "down" }) do
  bind("move-" .. dir, "SUPER + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }), "Windows", "Move window " .. dir)
end
bind("ws-prev",       "SUPER + CTRL + left",  hl.dsp.focus({ workspace = "m-1" }), "Workspaces", "Previous on this monitor")
bind("ws-next",       "SUPER + CTRL + right", hl.dsp.focus({ workspace = "m+1" }), "Workspaces", "Next on this monitor")

-- Hardware (locked: they work on the lock screen; the shell is the locker)
bind("vol-up",        "XF86AudioRaiseVolume",         G("vol-up"),        "Media and hardware", "Volume up", R)
bind("vol-down",      "XF86AudioLowerVolume",         G("vol-down"),      "Media and hardware", "Volume down", R)
bind("vol-up-fine",   "SHIFT + XF86AudioRaiseVolume", G("vol-up-fine"),   "Media and hardware", "Volume up 1 %", R)
bind("vol-down-fine", "SHIFT + XF86AudioLowerVolume", G("vol-down-fine"), "Media and hardware", "Volume down 1 %", R)
bind("mute",          "XF86AudioMute",                G("mute"),          "Media and hardware", "Mute", L)
bind("mic-mute",      "XF86AudioMicMute",             G("mic-mute"),      "Media and hardware", "Microphone mute", L)
bind("bright-up",     "XF86MonBrightnessUp",          G("bright-up"),     "Media and hardware", "Brightness up", R)
bind("bright-down",   "XF86MonBrightnessDown",        G("bright-down"),   "Media and hardware", "Brightness down", R)
bind("bright-up-f",   "SHIFT + XF86MonBrightnessUp",  G("bright-up-fine"),   "Media and hardware", "Brightness up 1 %", R)
bind("bright-down-f", "SHIFT + XF86MonBrightnessDown", G("bright-down-fine"), "Media and hardware", "Brightness down 1 %", R)
bind("kbd-up",        "XF86KbdBrightnessUp",          G("kbd-up"),        "Media and hardware", "Keyboard light up", R)
bind("kbd-down",      "XF86KbdBrightnessDown",        G("kbd-down"),      "Media and hardware", "Keyboard light down", R)
bind("kbd-toggle",    "XF86KbdLightOnOff",            G("kbd-toggle"),    "Media and hardware", "Keyboard light on/off", L)
bind("media-play",    "XF86AudioPlay",                G("media-toggle"),  "Media and hardware", "Play / pause", L)
bind("media-pause",   "XF86AudioPause",               G("media-toggle"),  "Media and hardware", "Play / pause | hidden", L)
bind("media-next",    "XF86AudioNext",                G("media-next"),    "Media and hardware", "Next track", L)
bind("media-prev",    "XF86AudioPrev",                G("media-prev"),    "Media and hardware", "Previous track", L)

-- Gestures (09 §8)
-- 3-finger horizontal swipe = workspaces stays in hyprland.lua (Lenno's line)
hl.gesture({ fingers = 3, direction = "down", action = function() hl.dispatch(G("overview-open")) end })
hl.gesture({ fingers = 3, direction = "up",   action = function() hl.dispatch(G("overview-close")) end })
