"""install plan in a temporary HOME (11 §4)."""
from __future__ import annotations

import builtins
import json
import os
from pathlib import Path

import pytest

from aptus import install
from aptus.install import hyprlua
from aptus.paths import get

NOCT_LUA = 'local noctalia = "noctalia msg"\nhl.on("hyprland.start", function()\n' \
           '    hl.exec_cmd("noctalia")\nend)\nhl.bind("SUPER + M", hl.dsp.exit())\n'


def snapshot(home: Path) -> dict[str, str]:
    out = {}
    for p in sorted(home.rglob("*")):
        out[str(p.relative_to(home))] = (os.readlink(p) if p.is_symlink()
                                         else "" if p.is_dir() else p.read_text())
    return out


def make_v1(home: Path) -> None:
    p = get()
    p.config.mkdir(parents=True)
    (p.config / "config").write_text("v1 config")
    p.settings.write_text(json.dumps({"theme": "dark"}))          # v1: no "v"
    p.state.mkdir(parents=True)
    (p.state / "color-mode").write_text("dark")
    (p.state / "hyprland-colors.lua").write_text("-- v1")
    p.local_bin.mkdir(parents=True)
    os.symlink("/nonexistent/old-repo/aptus-packages", p.local_bin / "aptus-packages")  # dangling


def test_plan_lists_links() -> None:
    p = get()
    actions = install.plan(p)
    links = {a.path: a.target for a in actions if a.kind == "link"}
    assert links[p.hypr_aptus_link] == p.hypr_repo
    for name in ("aptus", "aptus-session", "aptus-supervise"):
        assert links[p.local_bin / name] == p.bin / name
    mkdirs = {a.path for a in actions if a.kind == "mkdir"}
    assert {p.state, p.install_state, p.hypr_state, p.scope, p.local_bin} <= mkdirs
    assert all(str(a.path).startswith(str(p.home)) for a in actions)    # nothing outside HOME
    assert not any(a.kind == "edit-hyprland" for a in actions)         # no hyprland.lua yet
    text = install.describe(actions)
    assert "~/.local/bin/aptus-session" in text and "→" in text
    assert snapshot(p.home) == {".aptus-run": ""} or snapshot(p.home) == {}   # planning writes nothing
    # After applying the base install, planning again finds nothing left to link.
    install.apply(p, actions)
    assert (p.local_bin / "aptus").is_symlink()
    assert os.readlink(p.hypr_aptus_link) == str(p.hypr_repo)
    assert [a for a in install.plan(p) if a.kind != "mkdir"] == []


def test_v1_leftovers_found() -> None:
    p = get()
    assert install.v1_leftovers(p) == []
    make_v1(p.home)
    found = set(install.v1_leftovers(p))
    assert {p.config / "config", p.settings, p.state / "color-mode",
            p.state / "hyprland-colors.lua", p.local_bin / "aptus-packages"} <= found
    p.settings.write_text(json.dumps({"v": 2}))                # a v2 file stays
    assert p.settings not in install.v1_leftovers(p)
    p.settings.write_text("{ not json")
    assert p.settings not in install.v1_leftovers(p)


def test_moves_not_deletes() -> None:
    p = get()
    make_v1(p.home)
    actions = install.plan(p)
    moves = [a for a in actions if a.kind == "move"]
    assert moves and all(a.approval == "v1" for a in moves)
    assert all(str(a.target).startswith(str(p.v1_backup)) for a in moves)
    install.apply(p, actions)
    assert not (p.config / "config").exists()
    (moved,) = list(p.v1_backup.rglob("config"))
    assert moved.read_text() == "v1 config"
    assert os.readlink(next(p.v1_backup.rglob("aptus-packages"))) == "/nonexistent/old-repo/aptus-packages"
    # A move never overwrites: an existing backup target aborts.
    (p.config).mkdir(exist_ok=True)
    (p.config / "config").write_text("again")
    clash = install.Action("move", p.config / "config", moved)
    with pytest.raises(FileExistsError):
        install.apply(p, [clash])
    assert (p.config / "config").read_text() == "again" and moved.read_text() == "v1 config"
    # A real file in the way of a link is moved aside first, not replaced.
    (p.local_bin / "aptus").unlink()          # a symlink into the repo: never write through it
    (p.local_bin / "aptus").write_text("old script")
    plan = [a for a in install.plan(p) if a.path == p.local_bin / "aptus"]
    assert [a.kind for a in plan] == ["move", "link"]
    with pytest.raises(FileExistsError, match="nothing changed"):
        install.apply(p, plan[1:])
    assert (p.local_bin / "aptus").read_text() == "old script"
    # given link first (as the groups are approved), the move still runs before the link
    install.apply(p, [plan[1], plan[0]])
    assert (p.local_bin / "aptus").is_symlink()
    assert next(f for f in p.v1_backup.rglob("aptus") if f.is_file()).read_text() == "old script"


def test_nothing_without_approval(monkeypatch: pytest.MonkeyPatch,
                                  capsys: pytest.CaptureFixture[str]) -> None:
    p = get()
    make_v1(p.home)
    p.hyprland_lua.parent.mkdir(parents=True)
    p.hyprland_lua.write_text(NOCT_LUA)
    before = snapshot(p.home)
    answers = iter(["n", ""])
    monkeypatch.setattr(builtins, "input", lambda prompt="": next(answers))
    assert install.main([]) == 0
    out = capsys.readouterr().out
    # without the aptus link the block would break hyprland.lua: not even offered
    assert "Nothing changed." in out and "skipped, the block requires" in out
    assert snapshot(p.home) == before
    answers = iter(["y", "n", "no"])
    monkeypatch.setattr(builtins, "input", lambda prompt="": next(answers))
    p.hyprland_lua.write_text(NOCT_LUA)
    before_lua = p.hyprland_lua.read_text()
    assert install.main([]) == 0
    out = capsys.readouterr().out
    assert "+require" in out and p.hyprland_lua.read_text() == before_lua    # the diff is shown first
    for leftover in (p.config / "config", p.state / "color-mode"):
        assert os.path.lexists(leftover)                                     # v1 declined: not moved
    before = snapshot(p.home)
    monkeypatch.setattr(builtins, "input", lambda prompt="": (_ for _ in ()).throw(EOFError))
    assert install.main([]) == 0 and snapshot(p.home) == before
    assert install.main(["--bogus"]) == 2
    # Only an explicit y applies; every group is asked on its own.
    asked: list[str] = []
    monkeypatch.setattr(builtins, "input", lambda prompt="": asked.append(prompt) or "y")
    assert install.main([]) == 0
    assert len(asked) == 2                                        # v1, hyprland (base done above)
    text = p.hyprland_lua.read_text()
    assert hyprlua.BLOCK_BEGIN in text and "noctalia" not in text.split(hyprlua.BLOCK_BEGIN)[0]
    assert len(list(p.install_state.glob("hyprland.lua.*"))) == 1          # backup first
    assert (p.install_state / "removed.lua").is_file()


def test_uninstall_plan(monkeypatch: pytest.MonkeyPatch) -> None:
    p = get()
    p.hyprland_lua.parent.mkdir(parents=True)
    p.hyprland_lua.write_text(NOCT_LUA)
    install.apply(p, install.plan(p))
    (p.scope / "kitty").mkdir(parents=True, exist_ok=True)
    (p.scope / "kitty" / "theme.conf").write_text("x")
    actions = install.plan_uninstall(p)
    kinds = {(a.kind, a.approval) for a in actions}
    assert ("link", "") in kinds and ("move", "") in kinds
    assert ("edit-hyprland", "hyprland") in kinds and ("edit-hyprland", "restore") in kinds
    assert all(a.target is None for a in actions if a.kind == "link")      # unlinks only
    assert any(a.kind == "move" and a.path == p.scope for a in actions)    # moved, not deleted
    # Without the restore group the Noctalia lines stay out.
    install.apply(p, [a for a in actions if a.approval != "restore"])
    assert not (p.local_bin / "aptus").exists() and not p.hypr_aptus_link.exists()
    assert hyprlua.BLOCK_BEGIN not in p.hyprland_lua.read_text()
    assert "noctalia" not in p.hyprland_lua.read_text()
    (moved,) = list(p.install_state.rglob("theme.conf"))
    assert moved.read_text() == "x"
    # Restore + block removal in one go gives back the original file.
    p.hyprland_lua.write_text(NOCT_LUA)
    install.apply(p, install.plan(p)[-1:])
    install.apply(p, [a for a in install.plan_uninstall(p) if a.kind == "edit-hyprland"])
    assert p.hyprland_lua.read_text() == NOCT_LUA
    # A link that does not point into the repo is not ours: left alone.
    foreign = p.local_bin / "aptus"
    p.local_bin.mkdir(parents=True, exist_ok=True)
    os.symlink("/usr/bin/true", foreign)
    assert not any(a.path == foreign for a in install.plan_uninstall(p))


def test_check_action_refuses() -> None:
    """The install invariant (02 §2, CLAUDE.md): each refusal for its own reason."""
    from aptus.install import Action, check_action
    p = get()
    p.local_bin.mkdir(parents=True, exist_ok=True)
    os.symlink(p.bin, p.local_bin / "into-repo")
    ok = [Action("mkdir", p.state), Action("link", p.local_bin / "aptus", p.bin / "aptus"),
          Action("link", p.local_bin / "aptus", None), Action("move", p.config / "old", p.v1_backup / "old"),
          Action("move", p.scope, p.install_state / "uninstalled" / "scope"),
          Action("edit-hyprland", p.hyprland_lua, p.install_state / "removed.lua"),
          Action("mkdir", p.systemd_user / "aptus-recover.service")]
    for a in ok:
        check_action(p, a)
    bad = [(Action("rm", p.state), "unknown kind"),
           (Action("mkdir", Path("/tmp/elsewhere")), "outside HOME"),
           (Action("mkdir", p.home.parent / (p.home.name + "x")), "outside HOME"),     # a prefix sibling
           (Action("mkdir", p.home / ".."), "not an absolute, normalised"),
           (Action("mkdir", Path("relative/dir")), "not an absolute, normalised"),
           (Action("mkdir", p.local_bin / "into-repo" / "x"), "inside the repository"),
           (Action("move", p.config_home / "umbriel" / "x", p.v1_backup / "x"), "Umbriel or Noctalia"),
           (Action("mkdir", p.config_home / "noctalia"), "Umbriel or Noctalia"),
           (Action("move", p.state_home / "noctalia", p.v1_backup / "n"), "Umbriel or Noctalia"),
           (Action("mkdir", p.config_home / "autostart"), "autostart entry or a font"),
           (Action("mkdir", p.data_home / "fonts" / "x"), "autostart entry or a font"),
           (Action("link", p.systemd_user / "aptus-shell.service", p.bin / "aptus"), "user unit"),
           (Action("move", p.config / "old", p.home / "old"), "a move outside"),
           (Action("move", p.config / "old", None), "a move outside"),
           (Action("link", p.local_bin / "aptus", Path("/usr/bin/true")), "does not point into"),
           (Action("link", p.local_bin / "aptus", Path("bin/aptus")), "not an absolute, normalised"),
           (Action("edit-hyprland", p.config_home / "hypr" / "other.lua"), "not hyprland.lua"),
           (Action("edit-hyprland", p.hyprland_lua, p.home / "removed.lua"), "not hyprland.lua")]
    for a, why in bad:
        with pytest.raises(RuntimeError, match="install invariant: .*" + why):
            check_action(p, a)
    # an edit follows a hyprland.lua that is a link into the repo, and refuses to write through it
    p.hypr_config_dir.mkdir(parents=True, exist_ok=True)
    os.symlink(p.repo / "hypr" / "init.lua", p.hyprland_lua)
    with pytest.raises(RuntimeError, match="inside the repository"):
        check_action(p, Action("edit-hyprland", p.hyprland_lua, p.install_state / "removed.lua"))
    assert install.KINDS == ("mkdir", "link", "move", "edit-hyprland")
    with pytest.raises(RuntimeError, match="install invariant"):
        install.apply(p, [Action("mkdir", p.state), Action("mkdir", Path("/tmp/elsewhere"))])
    assert not p.state.exists()                 # nothing ran: the whole plan is checked first


def test_declined_v1_leaves_the_blocked_link_out(monkeypatch: pytest.MonkeyPatch,
                                                 capsys: pytest.CaptureFixture[str]) -> None:
    """A real file in the way of a link: approving everything moves it and links; declining the
    v1 group leaves only that link out, the rest of the install happens."""
    p = get()
    p.local_bin.mkdir(parents=True)
    (p.local_bin / "aptus").write_text("old script")
    p.hyprland_lua.parent.mkdir(parents=True)
    p.hyprland_lua.write_text(NOCT_LUA)
    answers = iter(["y", "n", "y"])
    monkeypatch.setattr(builtins, "input", lambda prompt="": next(answers))
    assert install.main([]) == 0
    out = capsys.readouterr().out
    assert "Left out: the link" in out and "Done." in out
    assert (p.local_bin / "aptus").read_text() == "old script"
    assert p.hypr_aptus_link.is_symlink() and hyprlua.BLOCK_BEGIN in p.hyprland_lua.read_text()
    monkeypatch.setattr(builtins, "input", lambda prompt="": "y")
    assert install.main([]) == 0
    assert (p.local_bin / "aptus").is_symlink()
    assert next(f for f in p.v1_backup.rglob("aptus") if f.is_file()).read_text() == "old script"


def test_restore_happens_once() -> None:
    p = get()
    p.hyprland_lua.parent.mkdir(parents=True)
    p.hyprland_lua.write_text(NOCT_LUA)
    install.apply(p, install.plan(p))
    install.apply(p, install.plan_uninstall(p))
    assert p.hyprland_lua.read_text() == NOCT_LUA
    assert not (p.install_state / "removed.lua").exists()
    assert list(p.install_state.glob("removed.lua.restored-*"))
    # a second uninstall has nothing to put back (no duplicate Noctalia lines)
    assert not any(a.approval == "restore" for a in install.plan_uninstall(p))
