"""hypr/*.lua: binds.lua runs under luajit with a stub `hl` (no lua 5.4 is installed; 09's binds
use no 5.4-only syntax). Every global shortcut is bound (lock through exec, overview-open/-close
through the gestures), descriptions are well-formed, overrides apply, init.lua's gen defaults
equal tokens.json."""
from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
INIT = (REPO / "hypr" / "init.lua").read_text(encoding="utf-8")
TOKENS = json.loads((REPO / "theme" / "tokens.json").read_text(encoding="utf-8"))
SHORTCUTS = (REPO / "shell" / "registry" / "Shortcuts.qml").read_text(encoding="utf-8")
LUAJIT = shutil.which("luajit")

# The stub records every call as one JSON line: hl.dsp.* return descriptors, hl.bind/unbind/
# gesture/dispatch print them, and a gesture's action function runs once.
HARNESS = r"""
local function enc(v)
  local t = type(v)
  if t == "table" then
    local parts, n = {}, 0
    for k, x in pairs(v) do n = n + 1; parts[n] = string.format("%q", tostring(k)) .. ":" .. enc(x) end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif t == "string" then return (string.format("%q", v):gsub("\\\n", "\\n"))
  elseif t == "function" then return '"<function>"'
  else return tostring(v) end
end
local function emit(t) io.write(enc(t), "\n") end
local function dsp(path)
  return setmetatable({}, {
    __index = function(_, k) return dsp(path .. "." .. k) end,
    __call = function(_, arg) return { dsp = path, arg = arg } end })
end
hl = { dsp = dsp("hl.dsp"),
       bind = function(chord, action, opts)
         emit({ call = "bind", chord = chord, action = action, opts = opts })
         -- a function bind (Caps Lock) runs once per keyboard state; its dispatch is recorded
         if type(action) == "function" then action(); action() end
       end,
       unbind = function(chord) emit({ call = "unbind", chord = chord }) end,
       gesture = function(g)
         emit({ call = "gesture", g = g })
         if type(g.action) == "function" then g.action() end   -- records what it dispatches
       end,
       dispatch = function(a) emit({ call = "dispatch", action = a }) end,
       -- the main keyboard, Caps Lock flipping with every call
       get_devices = function() caps = not caps; return { { type = "keyboard", main = true, caps_lock = caps } } end }
dofile(arg[1])
"""


def run_binds(home: Path) -> list[dict]:
    if not LUAJIT:
        pytest.skip("luajit is not installed")
    harness = home / "harness.lua"
    harness.write_text(HARNESS, encoding="utf-8")
    out = subprocess.run([LUAJIT, str(harness), str(REPO / "hypr" / "binds.lua")], capture_output=True,
                         text=True, timeout=10, env={"HOME": str(home), "PATH": "/usr/bin"}, check=True).stdout
    return [json.loads(line) for line in out.splitlines()]


def routes() -> set[str]:
    return set(re.findall(r'^\s*"([a-z][\w-]*)": \(\) =>', SHORTCUTS, re.M))


def test_every_shortcut_bound(test_home: Path) -> None:
    calls = run_binds(test_home)
    binds = [c for c in calls if c["call"] == "bind"]
    binds = [b for b in binds if isinstance(b["action"], dict)]        # function binds dispatch below
    globals_ = {b["action"]["arg"] for b in binds if b["action"]["dsp"] == "hl.dsp.global"}
    gestures = [c for c in calls if c["call"] == "gesture"]
    assert len(gestures) == 2
    # a gesture's action is a Lua function; the stub ran it, so its dispatch is in the calls
    globals_ |= {c["action"]["arg"] for c in calls
                 if c["call"] == "dispatch" and c["action"]["dsp"] == "hl.dsp.global"}
    names = {g.removeprefix("aptus:") for g in globals_}
    assert names <= routes(), f"bound but not handled by Shortcuts.qml: {names - routes()}"
    assert routes() - names == {"lock"}, "every route is bound (lock goes through exec)"
    lock = [b for b in binds if b["action"]["dsp"] == "hl.dsp.exec_cmd"]
    assert len(lock) == 2
    for b in lock:
        assert b["action"]["arg"] == (f"{test_home}/.local/bin/aptus msg session lock || hyprlock -c "
                                      f"{test_home}/.local/state/aptus/hyprlock.conf || hyprlock")
    # hardware keys work on the lock screen (09 §7: the shell is the locker)
    for b in binds:
        if b["chord"].split(" + ")[-1].startswith("XF86") and "Dictate" not in b["chord"] and "Emoji" not in b["chord"]:
            assert b["opts"].get("locked") is True, b["chord"]


def test_descriptions_format(test_home: Path) -> None:
    calls = run_binds(test_home)
    binds = [c for c in calls if c["call"] == "bind"]
    pattern = re.compile(r"^aptus:([a-z][\w-]*) \| ([A-Z][\w ]*) \| (\S.*?)( \| hidden)?$")
    ids = []
    for b in binds:
        m = pattern.match(b["opts"]["description"])
        assert m, b["opts"]["description"]
        assert " | " not in m.group(3), b["opts"]["description"]
        ids.append(m.group(1))
    assert len(ids) == len(set(ids)), "bind ids are unique"
    # each chord is unbound once, before its first bind (two binds on SUPER + Super_L, probe P-03)
    seen: dict[str, int] = {}
    for c in calls:
        if c["call"] == "unbind":
            assert c["chord"] not in seen
            seen[c["chord"]] = 0
        elif c["call"] == "bind":
            assert c["chord"] in seen, f"{c['chord']} bound without unbind"
            seen[c["chord"]] += 1
    assert seen["SUPER + Super_L"] == 2


def test_overrides_apply(test_home: Path) -> None:
    local = test_home / ".local" / "state" / "aptus" / "hypr"
    local.mkdir(parents=True)
    (local / "binds.local.lua").write_text('return { spotlight = "SUPER + J", deck = false }\n', encoding="utf-8")
    binds = {b["opts"]["description"].split(" | ")[0]: b for b in run_binds(test_home) if b["call"] == "bind"}
    assert binds["aptus:spotlight"]["chord"] == "SUPER + J"
    assert "aptus:deck" not in binds
    assert binds["aptus:today"]["chord"] == "SUPER + N"


def test_gen_defaults_match_tokens() -> None:
    ember = TOKENS["palettes"]["ember"]
    block = INIT.split("local gen = {", 1)[1].split("\n}", 1)[0]

    def rgb(hexcolor: str) -> str:
        return f"rgb({hexcolor.lstrip('#')})"

    def value(name: str) -> str:
        return re.search(rf"\b{name}\s*=\s*([^,\n]+)", block).group(1).strip().strip('"')

    assert value("ground") == rgb(ember["ground"])
    assert value("line") == rgb(ember["line"])
    assert value("accent") == rgb(TOKENS["accents"]["jade"]["ember"])
    shadow = ember["shadow"]
    assert value("shadow") == f"rgba({shadow['color'].lstrip('#')}{round(shadow['alpha'] * 255):02x})"
    assert int(value("frame_edge")) == TOKENS["geometry"]["frameEdge"]
    assert int(value("window_gap")) == TOKENS["geometry"]["windowGap"]
    assert value("glass") == "false" and value("reduce_motion") == "false"
