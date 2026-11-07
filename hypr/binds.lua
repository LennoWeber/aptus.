-- aptus binds (09-hyprland §7, §8). Every aptus bind unbinds its chord first; descriptions are
-- "aptus:<id> | <Group> | <Description>[ | hidden]" for the Keys service.
local home = os.getenv("HOME")

local function G(name) error("binds.G: not implemented") end

-- Super+L / XF86ScreenSaver: the only aptus bind that forks, so locking works with the shell
-- down. The last fallback (plain hyprlock) covers the time before the first theme render.
local LOCK = home .. "/.local/bin/aptus msg session lock || hyprlock -c "
          .. home .. "/.local/state/aptus/hyprlock.conf || hyprlock"

-- Overrides from Settings › Keys: { [id] = "SUPER + J" | false }
local overrides = {}

-- Chords already unbound in this load (SUPER + Super_L carries two aptus binds, probe P-03).
local unbound = {}

local function bind(id, chord, action, group, desc, opts) error("binds.bind: not implemented") end

local L, R = { locked = true }, { locked = true, repeating = true }
