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
-- TODO(phase): G returns hl.dsp.global("aptus:" .. name); bind() as in 09 §7 (override, unbind
--   once per chord, copy opts, description) — body of the helper above.
-- TODO(phase): load binds.local.lua into `overrides` (pcall(dofile), table only).
-- TODO(phase): every bind of 09 §7 and the two gestures of 09 §8.
