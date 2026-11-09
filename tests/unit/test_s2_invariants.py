"""S2 invariants (02 §1 I-1…I-4): the run-time checks every isolation writer goes through, and the
refusal to run against a HOME that is not temporary."""
from __future__ import annotations

import dataclasses
import os
import pwd
import tempfile
from pathlib import Path

import pytest

from aptus import paths as paths_mod
from aptus.lease import invariants as inv
from aptus.lease.journal import Journal, Owner, SlotKind, SlotRecord, SlotStatus, State
from aptus.lease.kinds import dconf
from aptus.lease.slots import SlotSpec

KEY = dconf.KEY_DIR


@pytest.fixture(autouse=True)
def no_session_tools(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """Safety net on top of conftest: tools that would change the real session fail loudly."""
    block = tmp_path / "s2-block"
    block.mkdir()
    for tool in ("dconf", "gsettings", "loginctl", "kitty", "ghostty", "tmux", "nvim", "bat"):
        stub = block / tool
        stub.write_text(f"#!/bin/sh\necho 's2 unit tests: {tool} is blocked' >&2\nexit 99\n")
        stub.chmod(0o755)
    monkeypatch.setenv("PATH", f"{block}{os.pathsep}{os.environ['PATH']}")


@pytest.fixture
def p() -> paths_mod.Paths:
    return paths_mod.get()


def owner() -> Owner:
    return Owner(boot_id="b", hyprland_pid=1, hyprland_signature="s", logind_session="2",
                 taken_at="2026-11-09T10:00:00+01:00")


def file_spec(p: paths_mod.Paths, **kw) -> SlotSpec:
    base = dict(id="gtk3.artifact", kind=SlotKind.FILE, target="gtk3",
                path=p.config_home / "gtk-3.0/noctalia.css", content=b"x")
    base.update(kw)
    return SlotSpec(**base)


# --- journal transitions ---------------------------------------------------------------------

@pytest.mark.parametrize("old,new", [
    (None, State.TAKING), (State.RELEASED, State.TAKING), (State.TAKING, State.HELD),
    (State.TAKING, State.RELEASING), (State.HELD, State.RELEASING), (State.HELD, State.HELD),
    (State.RELEASING, State.RELEASED), (State.RELEASING, State.RELEASING)])
def test_transition_allowed(old, new) -> None:
    inv.transition(old, new)


@pytest.mark.parametrize("old,new", [
    (None, State.HELD), (None, State.RELEASED), (State.HELD, State.TAKING),
    (State.HELD, State.RELEASED), (State.RELEASING, State.HELD), (State.RELEASED, State.HELD),
    (State.TAKING, State.RELEASED)])
def test_transition_refused(old, new) -> None:
    with pytest.raises(inv.InvariantError, match="isolation invariant: journal"):
        inv.transition(old, new)


# --- writable --------------------------------------------------------------------------------

def test_lease_write_inside_home(p) -> None:
    inv.writable(p, p.config_home / "gtk-3.0/noctalia.css", kind="lease")


@pytest.mark.parametrize("where", [
    lambda p: Path("/etc/greetd/config.toml"),
    lambda p: Path(tempfile.gettempdir()) / "elsewhere",
    lambda p: p.umbriel_config / "config.toml",
    lambda p: p.noctalia_settings,
    lambda p: p.noctalia_config / "x.toml",
    lambda p: p.fonts / "a.ttf",
    lambda p: p.config_home / "autostart/x.desktop",
    lambda p: p.user_themes / "adw-gtk3/gtk.css",
    lambda p: p.repo / "theme/tokens.json",
    lambda p: p.state / "lease/journal.json",
    lambda p: p.config / "settings.json",
])
def test_lease_write_refused(p, where) -> None:
    with pytest.raises(inv.InvariantError):
        inv.writable(p, where(p), kind="lease")


def test_symlink_out_of_home_refused(p, tmp_path) -> None:
    """A slot linked outside the (temporary) HOME, e.g. a fixture linked into the real home,
    is refused: the check follows every link."""
    outside = tmp_path / "outside.css"
    outside.write_text("x")
    link = p.config_home / "gtk-3.0/noctalia.css"
    link.parent.mkdir(parents=True)
    link.symlink_to(outside)
    with pytest.raises(inv.InvariantError, match="outside HOME"):
        inv.writable(p, link, kind="lease")


def test_symlink_into_umbriel_refused(p) -> None:
    p.umbriel_config.mkdir(parents=True)
    (p.umbriel_config / "colors.css").write_text("x")
    link = p.config_home / "gtk-3.0/noctalia.css"
    link.parent.mkdir(parents=True)
    link.symlink_to(p.umbriel_config / "colors.css")
    with pytest.raises(inv.InvariantError, match="inside"):
        inv.writable(p, link, kind="lease")


def test_directory_link_inside_home_allowed(p) -> None:
    """A stow-style directory link that stays inside HOME (~/dotfiles) is a normal lease slot."""
    real = p.home / "dotfiles/gtk/.config/gtk-3.0"
    real.mkdir(parents=True)
    p.config_home.mkdir(parents=True)
    (p.config_home / "gtk-3.0").symlink_to(real)
    inv.writable(p, p.config_home / "gtk-3.0/noctalia.css", kind="lease")


def test_scope_kind(p) -> None:
    inv.writable(p, p.scope / "kitty", kind="scope")
    with pytest.raises(inv.InvariantError, match="scope write"):
        inv.writable(p, p.config_home / "kitty/kitty.conf", kind="scope")


@pytest.mark.parametrize("ok", [True, False])
def test_own_kind(p, ok) -> None:
    good = [p.qt6ct_conf, p.qt6ct_colors, p.icons / "aptus-icons-dark/index.theme",
            p.icons / "aptus-icons-light", p.cache / "bat-src/themes/aptus.tmTheme",
            p.state / "hypr/generated.lua"]
    bad = [p.config_home / "qt6ct/other.conf", p.icons / "Papirus-Dark/index.theme",
           p.icons / "aptus-icons-darker", p.config_home / "kdeglobals"]
    for where in (good if ok else bad):
        if ok:
            inv.writable(p, where, kind="own")
        else:
            with pytest.raises(inv.InvariantError):
                inv.writable(p, where, kind="own")


def test_state_kind(p) -> None:
    for where in (p.theme / "gen-1", p.cache / "bat", p.runtime / "guard.state"):
        inv.writable(p, where, kind="state")
    with pytest.raises(inv.InvariantError, match="state write"):
        inv.writable(p, p.config_home / "x", kind="state")
    with pytest.raises(inv.InvariantError, match="unknown write kind"):
        inv.writable(p, p.theme, kind="anything")


# --- slot specs --------------------------------------------------------------------------------

def test_good_specs(p) -> None:
    inv.check_specs(p, [
        file_spec(p),
        SlotSpec(id="kde.colors", kind=SlotKind.INI, target="kde", path=p.config_home / "kdeglobals",
                 content=b"[WM]\n", sections=("Colors:*", "WM")),
        SlotSpec(id="dconf.color-scheme", kind=SlotKind.DCONF, target="dconf",
                 key=KEY + "color-scheme", value="'prefer-dark'"),
        SlotSpec(id="dconf.gtk-theme", kind=SlotKind.DCONF, target="dconf", key=KEY + "gtk-theme"),
        SlotSpec(id="vscode.code.1a2b3c4d", kind=SlotKind.FILE, target="vscode",
                 path=p.home / ".vscode/x.json", content=b"{}"),
    ])


@pytest.mark.parametrize("bad", [
    lambda p: file_spec(p, id="gtk3"),
    lambda p: file_spec(p, id="kitty.artifact"),
    lambda p: file_spec(p, id="gtk3.a/b"),
    lambda p: file_spec(p, path=None),
    lambda p: file_spec(p, content=None),
    lambda p: file_spec(p, sections=("WM",)),
    lambda p: file_spec(p, key=KEY + "color-scheme"),
    lambda p: file_spec(p, path=p.umbriel_config / "style.css"),
    lambda p: file_spec(p, path=Path("/etc/gtk-3.0/settings.ini")),
    lambda p: SlotSpec(id="kde.colors", kind=SlotKind.INI, target="kde",
                       path=p.config_home / "kdeglobals", content=b""),
    lambda p: SlotSpec(id="dconf.gtk-theme", kind=SlotKind.DCONF, target="dconf",
                       key=KEY + "gtk-theme", value="'adw-gtk3-dark'"),
    lambda p: SlotSpec(id="dconf.x", kind=SlotKind.DCONF, target="dconf",
                       key="/org/gnome/desktop/wm/preferences/theme", value="'x'"),
    lambda p: SlotSpec(id="dconf.color-scheme", kind=SlotKind.DCONF, target="dconf",
                       key=KEY + "color-scheme", value="'x'", path=p.home / "x"),
])
def test_bad_spec_refused(p, bad) -> None:
    with pytest.raises(inv.InvariantError):
        inv.check_spec(p, bad(p))


def test_duplicate_spec_ids_refused(p) -> None:
    with pytest.raises(inv.InvariantError, match="duplicate"):
        inv.check_specs(p, [file_spec(p), file_spec(p)])


@pytest.mark.parametrize("name,ok", [("kitty", True), ("starship.toml", True), ("", False),
                                     ("..", False), ("a/b", False), (".kitty.3", False)])
def test_scope_name(name, ok) -> None:
    if ok:
        inv.check_scope_name(name)
    else:
        with pytest.raises(inv.InvariantError):
            inv.check_scope_name(name)


# --- journal -------------------------------------------------------------------------------------

def held_journal(p, **slot_kw) -> Journal:
    rec = dict(id="gtk3.artifact", kind=SlotKind.FILE, target="gtk3",
               path=str(p.config_home / "gtk-3.0/noctalia.css"),
               write_path=str(p.config_home / "gtk-3.0/noctalia.css"), status=SlotStatus.HELD)
    rec.update(slot_kw)
    return Journal(state=State.HELD, owner=owner(), slots=[SlotRecord(**rec)])


def test_good_journals(p) -> None:
    inv.check_journal(p, held_journal(p))
    inv.check_journal(p, Journal(state=State.HELD, owner=owner(), slots=[
        SlotRecord(id="dconf.gtk-theme", kind=SlotKind.DCONF, target="dconf",
                   key=KEY + "gtk-theme", write=False, status=SlotStatus.HELD)]))
    j = held_journal(p, status=SlotStatus.RESTORED)
    j.state, j.released_at = State.RELEASED, "2026-11-09T11:00:00+01:00"
    inv.check_journal(p, j)
    j = held_journal(p, status=SlotStatus.FAILED)
    j.state = State.RELEASING
    inv.check_journal(p, j)


def _mutations(p):
    def no_owner(j): j.owner = None
    def released_no_stamp(j): j.state = State.RELEASED; j.slots[0].status = SlotStatus.RESTORED
    def stamp_while_held(j): j.released_at = "2026-11-09T11:00:00+01:00"
    def dup(j): j.slots.append(dataclasses.replace(j.slots[0]))
    def pending_in_held(j): j.slots[0].status = SlotStatus.PENDING
    def failed_in_held(j): j.slots[0].status = SlotStatus.FAILED
    def restored_in_taking(j): j.state = State.TAKING; j.slots[0].status = SlotStatus.RESTORED
    def record_only_file(j): j.slots[0].write = False
    def outside_home(j): j.slots[0].write_path = "/etc/gtk-3.0/noctalia.css"
    def into_noctalia(j): j.slots[0].write_path = str(p.noctalia_settings)
    def version(j): j.version = 2
    def foreign_key(j):
        j.slots[0] = SlotRecord(id="dconf.x", kind=SlotKind.DCONF, target="dconf",
                                key="/org/gnome/shell/x", status=SlotStatus.HELD)
    def written_gtk_theme(j):
        j.slots[0] = SlotRecord(id="dconf.gtk-theme", kind=SlotKind.DCONF, target="dconf",
                                key=KEY + "gtk-theme", write=True, status=SlotStatus.HELD)
    return [no_owner, released_no_stamp, stamp_while_held, dup, pending_in_held, failed_in_held,
            restored_in_taking, record_only_file, outside_home, into_noctalia, version,
            foreign_key, written_gtk_theme]


@pytest.mark.parametrize("i", range(13))
def test_bad_journal_refused(p, i) -> None:
    j = held_journal(p)
    _mutations(p)[i](j)
    with pytest.raises(inv.InvariantError):
        inv.check_journal(p, j)


def test_check_unset() -> None:
    inv.check_unset(["APTUS_SESSION", "XCURSOR_THEME"], ["APTUS_SESSION", "XCURSOR_THEME", "X"])
    with pytest.raises(inv.InvariantError, match="PATH"):
        inv.check_unset(["APTUS_SESSION", "PATH"], ["APTUS_SESSION"])


# --- dconf key set ---------------------------------------------------------------------------

def test_dconf_check_key() -> None:
    for k in dconf.KEYS:
        dconf.check_key(KEY + k, writing=False)
        if k not in dconf.RECORD_ONLY:
            dconf.check_key(KEY + k, writing=True)
    with pytest.raises(dconf.DconfError, match="recorded only"):
        dconf.check_key(KEY + "gtk-theme", writing=True)
    for bad in ("/org/gnome/desktop/interface/gtk-key-theme", "/org/gnome/desktop/interface/",
                "org/gnome/desktop/interface/color-scheme", KEY + "color-scheme/x",
                "/org/gnome/desktop/wm/preferences/theme"):
        with pytest.raises(dconf.DconfError, match="outside"):
            dconf.check_key(bad, writing=False)


# --- the safe-HOME refusal -------------------------------------------------------------------

REAL_HOME = Path(pwd.getpwuid(os.getuid()).pw_dir)


def test_temporary_home_accepted(p) -> None:
    paths_mod.require_safe_home(p)


def test_real_home_refused(p) -> None:
    with pytest.raises(paths_mod.UnsafeHome):
        paths_mod.require_safe_home(dataclasses.replace(p, home=REAL_HOME))


def test_tmp_link_to_real_home_refused(p, tmp_path) -> None:
    link = tmp_path / "looks-temporary"
    link.symlink_to(REAL_HOME)
    with pytest.raises(paths_mod.UnsafeHome, match=str(REAL_HOME)):
        paths_mod.require_safe_home(dataclasses.replace(p, home=link))


def test_missing_home_refused(p, tmp_path) -> None:
    with pytest.raises(paths_mod.UnsafeHome, match="not a directory"):
        paths_mod.require_safe_home(dataclasses.replace(p, home=tmp_path / "nope"))


def test_home_outside_tmp_refused(p) -> None:
    with pytest.raises(paths_mod.UnsafeHome, match="not below"):
        paths_mod.require_safe_home(dataclasses.replace(p, home=Path("/usr")))


def test_tmpdir_inside_real_home_refused(p, monkeypatch) -> None:
    """TMPDIR pointing into the real home does not make a directory there 'temporary'.
    Only paths are compared; nothing is created in the real home."""
    candidate = REAL_HOME / ".cache"
    monkeypatch.setattr(tempfile, "tempdir", str(REAL_HOME))
    if not candidate.is_dir():
        pytest.skip("no ~/.cache to point at")
    with pytest.raises(paths_mod.UnsafeHome, match="real home"):
        paths_mod.require_safe_home(dataclasses.replace(p, home=candidate))


def test_outside_tests_no_check(p) -> None:
    paths_mod.require_safe_home(dataclasses.replace(p, test=False, home=REAL_HOME))


def test_lease_lock_refuses_real_home(p) -> None:
    """The lease lock is the gate every lease writer passes: it refuses before touching a file."""
    from aptus.lease import ops
    with pytest.raises(paths_mod.UnsafeHome):
        with ops.lock(dataclasses.replace(p, home=REAL_HOME)):
            pass


def test_theme_lock_refuses_real_home(p) -> None:
    from aptus.theme import render
    with pytest.raises(paths_mod.UnsafeHome):
        with render.lock(dataclasses.replace(p, home=REAL_HOME)):
            pass
