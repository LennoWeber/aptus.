"""install plan in a temporary HOME (11 §4)."""
from __future__ import annotations



def test_plan_lists_links() -> None:
    raise NotImplementedError


def test_v1_leftovers_found() -> None:
    raise NotImplementedError


def test_moves_not_deletes() -> None:
    raise NotImplementedError


def test_nothing_without_approval() -> None:
    raise NotImplementedError


def test_uninstall_plan() -> None:
    raise NotImplementedError


# TODO(phase): install.sh wrapper: APTUS_TEST=1, temp HOME, answer "n" → nothing changed; with the
#   passwd home under APTUS_TEST → refuses.


def test_check_action_refuses() -> None:
    """The install invariant: nothing outside HOME, nothing in the repo (also not through a link),
    nothing of Umbriel or Noctalia, moves only into the backups, links only into the repo."""
    import os
    from pathlib import Path
    import pytest
    from aptus import install
    from aptus.install import Action, check_action
    from aptus.paths import get
    p = get()
    p.local_bin.mkdir(parents=True, exist_ok=True)
    os.symlink(p.bin, p.local_bin / "into-repo")
    ok = [Action("mkdir", p.state), Action("link", p.local_bin / "aptus", p.bin / "aptus"),
          Action("link", p.local_bin / "aptus", None), Action("move", p.config / "old", p.v1_backup / "old"),
          Action("edit-hyprland", p.hyprland_lua, p.install_state / "removed.lua")]
    for a in ok:
        check_action(p, a)
    bad = [Action("rm", p.state), Action("mkdir", Path("/tmp/elsewhere")),
           Action("mkdir", p.local_bin / "into-repo" / "x"),
           Action("move", p.home / ".config" / "umbriel" / "x", p.v1_backup / "x"),
           Action("move", p.home / ".local" / "state" / "noctalia", p.v1_backup / "n"),
           Action("move", p.config / "old", p.home / "old"),
           Action("link", p.local_bin / "aptus", Path("/usr/bin/true")),
           Action("edit-hyprland", p.config_home / "hypr" / "other.lua")]
    for a in bad:
        with pytest.raises(RuntimeError, match="install invariant"):
            check_action(p, a)
    assert install.KINDS == ("mkdir", "link", "move", "edit-hyprland")

