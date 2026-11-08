"""The hyprland.lua edit of 09 §1, against a copy of Lenno's file shape."""
from __future__ import annotations

import re

from aptus.install import hyprlua

BEGIN, END = hyprlua.BLOCK_BEGIN, hyprlua.BLOCK_END

HEAD = '''-- Lenno's hyprland.lua
local function first_installed(names)
    return names[#names]
end

-- Set programs that you use
local terminal    = first_installed({ "ghostty", "kitty" })
local fileManager = first_installed({ "nemo", "dolphin" })
local browser     = "zen-browser"
'''
LOCALS = '''-- IPC an Noctalia v5 (Befehle: noctalia msg --help)
local noctalia    = "noctalia msg"
local menu        = noctalia .. " panel-toggle launcher"
-- Sperren darf nie ausfallen: läuft Noctalia nicht, sperrt hyprlock
local lock        = noctalia .. " session lock || hyprlock"
'''
START_COMMENTED = '''-- hl.on("hyprland.start", function ()
--   hl.exec_cmd("noctalia")
-- end)
'''
START = '''hl.on("hyprland.start", function()
    hl.exec_cmd("noctalia")
end)
'''
MIDDLE = '''hl.env("XCURSOR_SIZE", "24")
local mainMod = "SUPER"
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
'''
EXIT = 'hl.bind(mainMod .. " + M", hl.dsp.exit())\n'
KEPT_BINDS = '''hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
'''
NOCT_BINDS = '''hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(noctalia .. " screenshot-region"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(noctalia .. " volume-mute"), { locked = true, repeating = true })
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(lock))
'''
MULTI = '''hl.bind(
    "XF86KbdBrightnessDown",
    hl.dsp.exec_cmd(noctalia .. " keyboard-backlight-down"),
    { locked = true, repeating = true }
)
'''
TAIL = '''hl.window_rule({ name = "x", match = { class = "pavucontrol" }, float = true })
'''
FILE = HEAD + LOCALS + "\n" + START_COMMENTED + "\n" + START + "\n" + MIDDLE + EXIT + KEPT_BINDS \
    + NOCT_BINDS + MULTI + TAIL


def removed(plan: hyprlua.Plan) -> str:
    return "\n".join(r.text for r in plan.removals)


def test_removes_noctalia_locals() -> None:
    plan = hyprlua.plan_install(FILE)
    kept = [l for l in plan.new_text.splitlines() if l.startswith("local ")]
    assert not any(re.match(r"local (noctalia|menu|lock)\b", l) for l in kept)
    assert 'local noctalia    = "noctalia msg"' in removed(plan)
    assert "local menu" in removed(plan) and "local lock" in removed(plan)
    assert "local terminal" in plan.new_text and "local browser" in plan.new_text
    # The comments above the locals are not statements: they stay.
    assert "-- IPC an Noctalia v5" in plan.new_text


def test_removes_noctalia_start() -> None:
    plan = hyprlua.plan_install(FILE)
    assert 'hl.on("hyprland.start", function()\n    hl.exec_cmd("noctalia")' not in plan.new_text
    assert any(r.reason.startswith("the Noctalia autostart") for r in plan.removals)


def test_removes_noctalia_binds() -> None:
    plan = hyprlua.plan_install(FILE)
    body = plan.new_text.split(BEGIN)[0]
    assert "screenshot-region" not in body and "volume-mute" not in body
    assert "exec_cmd(menu)" not in body and "exec_cmd(lock)" not in body
    assert 'SHIFT + S' not in body


def test_removes_exit_bind() -> None:
    plan = hyprlua.plan_install(FILE)
    assert "hl.dsp.exit()" not in plan.new_text
    assert any("exit" in r.reason for r in plan.removals)


def test_keeps_everything_else() -> None:
    plan = hyprlua.plan_install(FILE)
    for kept in (HEAD, MIDDLE, KEPT_BINDS, TAIL, START_COMMENTED):
        assert kept in plan.new_text
    gone = {r.line_no for r in plan.removals}
    kept_lines = [l for n, l in enumerate(FILE.splitlines(), 1) if n not in gone]
    assert plan.new_text.split(BEGIN)[0].rstrip("\n").splitlines() == \
        "\n".join(kept_lines).rstrip("\n").splitlines()
    # A file without Noctalia lines only gains the block.
    clean = HEAD + MIDDLE + KEPT_BINDS + TAIL
    plan = hyprlua.plan_install(clean)
    assert plan.removals == [] and plan.new_text.startswith(clean)


def test_appends_block_once() -> None:
    plan = hyprlua.plan_install(FILE)
    assert plan.new_text.endswith(hyprlua.BLOCK) and not plan.block_present
    assert plan.new_text.count(BEGIN) == 1 and plan.new_text.count(END) == 1
    assert 'require("aptus.init")' in plan.new_text
    assert hyprlua.plan_install("").new_text == hyprlua.BLOCK
    no_newline = hyprlua.plan_install("local a = 1")
    assert no_newline.new_text == "local a = 1\n\n" + hyprlua.BLOCK


def test_idempotent() -> None:
    once = hyprlua.plan_install(FILE)
    twice = hyprlua.plan_install(once.new_text)
    assert twice.block_present and twice.removals == []
    assert twice.new_text == once.new_text
    # Lines inside the block that look like Noctalia lines are never removed.
    tricky = hyprlua.plan_install(HEAD).new_text.replace(
        'require("aptus.init")', 'require("aptus.init")\nlocal lock = "x"')
    assert hyprlua.plan_install(tricky).new_text == tricky


def test_uninstall_restores() -> None:
    installed = hyprlua.plan_install(FILE)
    # Without restore: back to plain Hyprland, the Noctalia lines stay out.
    plain = hyprlua.plan_uninstall(installed.new_text, installed.removals, restore=False)
    assert BEGIN not in plain.new_text and plain.new_text.rstrip("\n") == \
        installed.new_text.split("\n" + BEGIN)[0].rstrip("\n")
    # With restore: the original file, byte for byte.
    restored = hyprlua.plan_uninstall(installed.new_text, installed.removals, restore=True)
    assert restored.new_text == FILE
    # The stored file round-trips.
    back = hyprlua.parse_removed(hyprlua.removed_lua(installed.removals))
    assert back == installed.removals
    assert hyprlua.plan_uninstall(installed.new_text, back, restore=True).new_text == FILE
    assert hyprlua.parse_removed("-- nothing\n") == []
    assert "aptus (after)" not in hyprlua.diff(installed) and "+require" in hyprlua.diff(installed)


def test_multiline_statement() -> None:
    text = HEAD + LOCALS + MULTI + KEPT_BINDS
    plan = hyprlua.plan_install(text)
    assert "XF86KbdBrightnessDown" not in plan.new_text
    assert "{ locked = true, repeating = true }\n)" not in plan.new_text
    assert KEPT_BINDS in plan.new_text
    first, last, code = [s for s in hyprlua.statements(text) if "XF86Kbd" in s[2]][0]
    assert last - first == 4 and code.endswith(")")
    # A multi-line bind that does not touch Noctalia stays whole.
    safe = 'hl.bind(\n    "XF86Foo",\n    hl.dsp.exec_cmd("true")\n)\n'
    assert safe in hyprlua.plan_install(safe).new_text


def test_three_line_autostart_removed() -> None:
    plan = hyprlua.plan_install(HEAD + START + MIDDLE)
    assert [r.line_no for r in plan.removals] == [len(HEAD.splitlines()) + n for n in (1, 2, 3)]
    assert "hyprland.start" not in plan.new_text
    assert plan.new_text.startswith(HEAD + MIDDLE)


def test_commented_autostart_kept() -> None:
    text = HEAD + START_COMMENTED + MIDDLE
    plan = hyprlua.plan_install(text)
    assert plan.removals == []
    assert START_COMMENTED in plan.new_text
    block_comment = '--[[\nhl.on("hyprland.start", function() hl.exec_cmd("noctalia") end)\n]]\n'
    assert hyprlua.plan_install(block_comment).removals == []
