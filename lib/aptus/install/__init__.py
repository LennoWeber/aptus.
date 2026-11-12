"""Helpers for install.sh (11-roadmap §4, 09-hyprland §1).

install.sh only plans and asks: every change outside the repo is listed first, the
hyprland.lua edit is shown as a diff, and nothing happens without a "y". Leftovers of v1 are
moved to ~/.local/state/aptus-v1-backup/<date>/, never deleted.
"""
from __future__ import annotations

import json
import os
import shutil
import sys
import time
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path

from .. import atomic
from ..paths import Paths, below, get, inside
from . import hyprlua


@dataclass(frozen=True)
class Action:
    kind: str                  # one of KINDS
    path: Path                 # what is created, re-pointed, moved or edited
    target: Path | None = None  # link target, or where a moved file goes
    detail: str = ""           # one line for the listing
    approval: str = ""         # the question group it belongs to ("" = part of the base install)


# "enable-unit"   path = systemd_user/WANTS_LINK: daemon-reload + enable aptus-recover.service
#                 (after its link action)
# "disable-unit"  the same path: `systemctl --user disable`; first in uninstall
# "baseline"      path = paths.baseline: doctor.isolation.record_baseline + save, only when no
#                 baseline exists (a re-install never re-records: that would hide an aptus write)
# "release-lease" path = paths.lease_journal: ops.release (uninstall, when a journal is there)
KINDS = ("mkdir", "link", "move", "edit-hyprland", "enable-unit", "disable-unit", "baseline",
         "release-lease")
WANTS_LINK = "default.target.wants/aptus-recover.service"   # below the user unit directory
RECOVER_UNIT = "aptus-recover.service"


def check_action(paths: Paths, action: Action) -> None:
    """Invariant: no action leaves HOME, changes anything inside the repo (also not through a
    link), or touches Umbriel's or Noctalia's files, autostart, fonts or user units other than
    aptus-recover.service; moves go only to the v1 backup or the install state (uninstall keeps the
    scope mirrors there), a link points into the repo (target None removes it), and the only edited
    file is ~/.config/hypr/hyprland.lua, its backups in the install state (02 §2, CLAUDE.md).
    A pre-flight check of the plan; apply() still refuses at run time to replace a real file by a
    link or to move onto something that exists. Raises RuntimeError("install invariant: …")."""
    def refuse(why: str) -> None:
        raise RuntimeError(f"install invariant: {action.kind} {action.path}: {why}")

    def real(p: Path, follow: bool = False) -> str:
        # absolute, no "..": the parent resolved, the last component itself unless `follow`
        # (a link stays a link, but a file that is edited is the file the link leads to)
        if not p.is_absolute() or ".." in p.parts:
            refuse(f"{p} is not an absolute, normalised path")
        return os.path.realpath(p) if follow else os.path.join(os.path.realpath(p.parent), p.name)

    def under(p: str, root: Path) -> bool:
        # `p` as real() made it (its last component may be a link), `root` with links followed
        return below(p, os.path.realpath(root), real=False)

    if action.kind not in KINDS:
        refuse("unknown kind")
    where = real(action.path, follow=action.kind == "edit-hyprland")
    if under(where, paths.repo):
        refuse("inside the repository")
    if not under(where, paths.home):
        refuse("outside HOME")
    for protected in (paths.config_home / "umbriel", paths.config_home / "noctalia",
                      paths.state_home / "noctalia"):
        if under(where, protected):
            refuse("Umbriel or Noctalia files")
    for protected in (paths.config_home / "autostart", paths.data_home / "fonts"):
        if under(where, protected):
            refuse("an autostart entry or a font (CLAUDE.md)")
    wants = paths.systemd_user / WANTS_LINK
    if under(where, paths.systemd_user) and where not in (real(paths.recover_unit), real(wants)):
        refuse("a user unit other than aptus-recover.service")
    for slot in leased_paths(paths):
        if any(under(where, Path(x)) for x in (os.path.normpath(slot), os.path.realpath(slot))):
            refuse("a leased slot (only aptus-lease writes those)")
    one_path = {"enable-unit": wants, "disable-unit": wants, "baseline": paths.baseline,
                "release-lease": paths.lease_journal}
    if action.kind in one_path and action.path != one_path[action.kind]:
        refuse(f"{action.kind} acts only on {one_path[action.kind]}")
    if action.kind == "edit-hyprland" and (action.path != paths.hyprland_lua or (
            action.target is not None and not under(real(action.target), paths.install_state))):
        refuse("not hyprland.lua, or its removed lines outside the install state")
    if action.kind == "move" and (action.target is None or not (under(real(action.target), paths.v1_backup)
                                                              or under(real(action.target), paths.install_state))):
        refuse("a move outside the v1 backup and the install state")
    if action.kind == "link" and action.target is not None and not under(real(action.target, follow=True),
                                                                       paths.repo):
        refuse("a link that does not point into the repository")


def leased_paths(paths: Paths) -> list[Path]:
    """Every slot path of the lease and bake targets in theme/targets.toml (globs expanded,
    `present` ignored: every candidate), which no install action may touch (02 §5: only
    aptus-lease writes them); [] when the manifest does not load."""
    from dataclasses import replace

    from ..theme import targets
    from ..theme.targets import Mechanism
    try:
        manifest = targets.load(paths.targets, paths.templates)
    except (targets.ManifestError, OSError):
        return []
    return [slot for t in manifest.targets if t.mechanism in (Mechanism.LEASE, Mechanism.BAKE)
            for _, slot in targets.slots(paths, replace(t, present=False))]


def systemctl_user(paths: Paths, args: Sequence[str]) -> None:
    """`systemctl --user <args>` through lease.system (a fake under test); RuntimeError when it
    fails or is not available."""
    from ..lease import system
    r = system.run(paths, ["systemctl", "--user", *args], timeout=30)
    if not r.ok:
        raise RuntimeError(f"systemctl --user {' '.join(args)} failed: "
                           f"{r.stderr.strip() or 'systemctl is not available'}")


def _bin_links(paths: Paths) -> list[tuple[Path, Path]]:
    """~/.local/bin/aptus* → the repo's bin/aptus* (the commands install.sh links)."""
    return [(paths.local_bin / f.name, f) for f in sorted(paths.bin.iterdir())
            if f.name.startswith("aptus") and f.is_file()]


def _links_into_repo(paths: Paths, link: Path) -> bool:
    return link.is_symlink() and inside(link.parent / os.readlink(link), paths.repo)


def _removed_file(paths: Paths) -> Path:
    return paths.install_state / "removed.lua"


def _blocked(actions: Sequence[Action]) -> list[Action]:
    """The link actions whose way a real file blocks that no move among `actions` clears."""
    moved = {a.path for a in actions if a.kind == "move"}
    return [a for a in actions if a.kind == "link" and a.target is not None and os.path.lexists(a.path)
            and not a.path.is_symlink() and a.path not in moved]


def v1_leftovers(paths: Paths) -> list[Path]:
    """The v1 files of 11 §4.3 that exist (symlinks into the old repo count even if dangling)."""
    found: list[Path] = []
    candidates = [paths.config / "config", paths.config / "hypr", paths.config / "theme"]
    candidates += [paths.state / n for n in ("color-mode", "hyprland-colors.lua",
                                              "hyprland-look.lua", "hyprland-look.lua.before",
                                              "login-wallpaper", "wallpaper", "snapshots")]
    candidates += [paths.local_bin / n for n in ("aptus-ai-usage", "aptus-packages",
                                                  "aptus-settings-watchdog", "aptus-theme-apps")]
    for path in candidates:
        if os.path.lexists(path):
            found.append(path)
    # v1's settings.json has no "v" key; a v2 file (or one that does not parse) stays.
    try:
        settings = json.loads(paths.settings.read_text(encoding="utf-8"))
        if isinstance(settings, dict) and "v" not in settings:
            found.append(paths.settings)
    except (OSError, ValueError):
        pass
    return found


def plan(paths: Paths) -> list[Action]:
    """Directories (state, scope mirrors, ~/.local/bin), links (~/.config/hypr/aptus → hypr/,
    ~/.local/bin/aptus* → bin/), v1 leftovers to move, the hyprland.lua edit."""
    actions: list[Action] = []
    for d in (paths.config, paths.state, paths.install_state, paths.hypr_state, paths.scope,
              paths.local_bin, paths.hypr_config_dir):
        if not d.is_dir():
            actions.append(Action("mkdir", d, detail="create"))
    links = [(paths.hypr_aptus_link, paths.hypr_repo)] + _bin_links(paths)
    stamp = time.strftime("%Y-%m-%d")
    backup = paths.v1_backup / stamp
    for link, target in links:
        if link.is_symlink() and Path(os.readlink(link)) == target:
            continue
        if link.is_symlink():
            actions.append(Action("link", link, target,
                                  detail=f"re-point (was → {os.readlink(link)})"))
            continue
        if os.path.lexists(link):        # a real file or folder: moved aside, never replaced
            actions.append(Action("move", link, backup / link.relative_to(paths.home),
                                  detail="in the way of the link", approval="v1"))
        actions.append(Action("link", link, target, detail="create"))
    for leftover in v1_leftovers(paths):
        actions.append(Action("move", leftover, backup / leftover.relative_to(paths.home),
                              detail="v1 leftover", approval="v1"))
    actions += _recover_unit_actions(paths, backup)
    if not paths.baseline.exists():
        actions.append(Action("baseline", paths.baseline,
                              detail="fingerprint Umbriel's, Noctalia's and greetd's config (read only)"))
    if paths.hyprland_lua.is_file():
        edit = hyprlua.plan_install(paths.hyprland_lua.read_text(encoding="utf-8"))
        if edit.new_text != edit.original:
            actions.append(Action(
                "edit-hyprland", paths.hyprland_lua,
                detail=(f"remove {len(edit.removals)} Noctalia line(s)"
                        + ("" if edit.block_present else ", append the aptus block")),
                approval="hyprland"))
    return actions


def _recover_unit_actions(paths: Paths, backup: Path) -> list[Action]:
    """The link of aptus-recover.service into the repo and its enabling (02 §7, the only unit)."""
    actions: list[Action] = []
    unit, target = paths.recover_unit, paths.recover_unit_repo
    if not (unit.is_symlink() and Path(os.readlink(unit)) == target):
        if os.path.lexists(unit) and not unit.is_symlink():
            actions.append(Action("move", unit, backup / unit.relative_to(paths.home),
                                  detail="in the way of the link", approval="recover"))
        actions.append(Action("link", unit, target, detail="the crash-recovery unit",
                              approval="recover"))
    if not os.path.lexists(paths.systemd_user / WANTS_LINK):
        actions.append(Action("enable-unit", paths.systemd_user / WANTS_LINK,
                              detail=f"systemctl --user enable {RECOVER_UNIT}", approval="recover"))
    return actions


def _own_outside_state(paths: Paths) -> list[Path]:
    """Own files and folders aptus created outside its state and cache (own.json): the
    aptus-icons-* themes and the qt6ct files."""
    from ..theme import own
    keep = (paths.state, paths.cache)
    return [p for p in own.recorded(paths) if os.path.lexists(p)
            and not any(inside(p, k) for k in keep)]


def plan_uninstall(paths: Paths) -> list[Action]:
    """02 §11: release a held lease, disable and unlink aptus-recover.service, remove the links
    into the repo, move the scope mirrors and the Own files aptus created (own.json) into
    install_state/uninstalled-<date>/, take the aptus block out of hyprland.lua. Lease history
    stays. Action has no "remove" kind: a link action without target removes the link, and what
    aptus filled is moved into install_state instead of being deleted."""
    actions: list[Action] = []
    gone = paths.install_state / f"uninstalled-{time.strftime('%Y-%m-%d')}"
    if paths.lease_journal.exists():
        actions.append(Action("release-lease", paths.lease_journal,
                              detail="give Noctalia's paint back first"))
    if os.path.lexists(paths.systemd_user / WANTS_LINK):
        actions.append(Action("disable-unit", paths.systemd_user / WANTS_LINK,
                              detail=f"systemctl --user disable {RECOVER_UNIT}"))
    for link in [paths.hypr_aptus_link, paths.recover_unit] + [link for link, _ in _bin_links(paths)]:
        if _links_into_repo(paths, link):
            actions.append(Action("link", link, None, detail="remove the link into the repo"))
    if paths.scope.exists():
        actions.append(Action("move", paths.scope, gone / "scope", detail="scope mirrors (02 §11)"))
    for own_path in _own_outside_state(paths):
        actions.append(Action("move", own_path, gone / own_path.relative_to(paths.home),
                              detail="created by aptus (own.json)"))
    if paths.hyprland_lua.is_file():
        text = paths.hyprland_lua.read_text(encoding="utf-8")
        removed_file = _removed_file(paths)
        removed = hyprlua.read_removed(removed_file)
        if hyprlua.BLOCK_BEGIN in text.splitlines():
            actions.append(Action("edit-hyprland", paths.hyprland_lua, removed_file,
                                  detail="remove the aptus block", approval="hyprland"))
        if removed:
            actions.append(Action("edit-hyprland", paths.hyprland_lua, removed_file,
                                  detail=f"put back the {len(removed)} Noctalia line(s) install removed",
                                  approval="restore"))
    return actions


def describe(actions: Sequence[Action]) -> str:
    home = str(Path.home())

    def short(p: Path | None) -> str:
        s = str(p)
        return "~" + s[len(home):] if s == home or s.startswith(home + "/") else s

    out = []
    for a in actions:
        if a.kind == "link" and a.target is None:
            out.append(f"  unlink {short(a.path)}  ({a.detail})")
        elif a.kind in ("link", "move"):
            arrow = "→" if a.kind == "link" else "⇒"
            out.append(f"  {a.kind:<6} {short(a.path)} {arrow} {short(a.target)}  ({a.detail})")
        elif a.kind == "edit-hyprland":
            out.append(f"  edit   {short(a.path)}  ({a.detail})")
        else:
            out.append(f"  {a.kind:<6} {short(a.path)}  ({a.detail})")
    return "\n".join(out)


ORDER = {"release-lease": 0, "disable-unit": 1, "mkdir": 2, "move": 3, "link": 4,
         "edit-hyprland": 5, "enable-unit": 6, "baseline": 7}


def _apply_s2(paths: Paths, a: Action) -> None:
    """The lease, unit and baseline kinds (02 §11)."""
    if a.kind == "release-lease":
        from ..lease import guard, ops
        report = ops.release(paths)
        if guard.after_release(paths, report, "") == guard.GuardState.FAILED:
            raise RuntimeError(f"the lease release failed for {', '.join(sorted(report.failed))}; "
                               "see aptus doctor isolation")
    elif a.kind == "disable-unit":
        systemctl_user(paths, ["disable", RECOVER_UNIT])
    elif a.kind == "enable-unit":
        systemctl_user(paths, ["daemon-reload"])
        systemctl_user(paths, ["enable", RECOVER_UNIT])
    elif a.kind == "baseline" and not paths.baseline.exists():
        from ..doctor import isolation
        isolation.save_baseline(paths, isolation.record_baseline(paths))


def apply(paths: Paths, actions: Sequence[Action]) -> None:
    """Carry out approved actions (backups first: hyprland.lua.<date> in install_state).

    Everything is checked before anything changes: the invariant of every action, a real file in
    the way of a link that no approved move clears, a move onto something that exists. Then the
    actions run folders → moves → links → the hyprland.lua edit, so a file in the way is moved
    aside before its link is made."""
    stamp = time.strftime("%Y-%m-%d-%H%M%S")
    restore = any(a.kind == "edit-hyprland" and a.approval == "restore" for a in actions)
    for action in actions:
        check_action(paths, action)
    blocked = _blocked(actions)
    if blocked:
        raise FileExistsError(f"{blocked[0].path} is in the way of the link and is not moved aside; nothing changed")
    for a in actions:
        if a.kind == "move" and os.path.lexists(a.target):
            raise FileExistsError(f"{a.target} exists already; nothing changed")
    edited = False
    for a in sorted(actions, key=lambda a: ORDER[a.kind]):
        if a.kind == "mkdir":
            a.path.mkdir(parents=True, exist_ok=True)
        elif a.kind == "link" and a.target is None:
            if a.path.is_symlink():
                a.path.unlink()
        elif a.kind == "link":
            a.path.parent.mkdir(parents=True, exist_ok=True)
            atomic.symlink(a.target, a.path)
        elif a.kind == "move":
            a.target.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(a.path), str(a.target))
        elif a.kind in ("release-lease", "disable-unit", "enable-unit", "baseline"):
            _apply_s2(paths, a)
        elif a.kind == "edit-hyprland" and not edited:
            edited = True                     # remove-block and restore are one edit
            # the file a link leads to (check_action checked that one): writing the link's own
            # path would replace the link with a copy
            lua = a.path.resolve()
            text = lua.read_text(encoding="utf-8")
            paths.install_state.mkdir(parents=True, exist_ok=True)
            shutil.copy2(lua, paths.install_state / f"hyprland.lua.{stamp}")
            removed_file = _removed_file(paths)
            if a.target is None:              # install
                edit = hyprlua.plan_install(text)
                if edit.removals:
                    # a later install adds to the record, so the lines of the first stay
                    # restorable; a line removed again replaces its old entry (its anchor is the
                    # current file's), so it is put back once
                    again = {r.text for r in edit.removals}
                    earlier = [r for r in hyprlua.read_removed(removed_file) if r.text not in again]
                    if removed_file.exists():
                        shutil.copy2(removed_file, paths.install_state / f"removed.lua.{stamp}")
                    atomic.write_text(removed_file, hyprlua.removed_lua(earlier + edit.removals))
            else:                             # uninstall, optionally putting the lines back
                edit = hyprlua.plan_uninstall(text, hyprlua.read_removed(removed_file), restore)
            atomic.write_text(lua, edit.new_text)
            if a.target is not None and restore and removed_file.exists():
                # put back once: a later uninstall must not offer the same lines again
                removed_file.rename(paths.install_state / f"removed.lua.restored-{stamp}")


def _aptus_linked(paths: Paths, approved: Sequence[Action]) -> bool:
    """~/.config/hypr/aptus points into the repo now, or an approved action makes it so."""
    link = paths.hypr_aptus_link
    return _links_into_repo(paths, link) or any(
        a.kind == "link" and a.path == link and a.target is not None for a in approved)


def main(argv: Sequence[str]) -> int:
    """install.sh [--uninstall]: list, ask per group, apply. Every group needs its own "y"."""
    args = list(argv)
    if args not in ([], ["--uninstall"]):
        print("usage: install.sh [--uninstall]", file=sys.stderr)
        return 2
    p = get()
    uninstall = args == ["--uninstall"]
    actions = plan_uninstall(p) if uninstall else plan(p)
    if not actions:
        print("Nothing to do.")
        return 0
    titles = {"": "Uninstall: links and scope mirrors" if uninstall else
              "Base install: folders and links into the repo",
              "v1": "Move v1 leftovers (never deleted) to " + str(p.v1_backup),
              "recover": "Install and enable aptus-recover.service (gives Noctalia's paint back "
                         "after a crash; the only user unit aptus installs)",
              "hyprland": "Edit ~/.config/hypr/hyprland.lua (backup first)",
              "restore": "Put the removed Noctalia lines back into hyprland.lua"}
    approved: list[Action] = []
    text = p.hyprland_lua.read_text(encoding="utf-8") if p.hyprland_lua.is_file() else ""
    for group in ("", "v1", "recover", "hyprland", "restore"):
        members = [a for a in actions if a.approval == group]
        if not members:
            continue
        if group == "restore" and any(a.approval == "hyprland" for a in actions) \
                and not any(a.approval == "hyprland" for a in approved):
            continue                          # putting lines back implies removing the block
        if group == "hyprland" and not uninstall and not _aptus_linked(p, approved):
            print(f"\n{titles[group]}: skipped, the block requires ~/.config/hypr/aptus, which is"
                  " not linked (the base install was declined).")
            continue
        print(f"\n{titles[group]}:")
        print(describe(members))
        if group == "hyprland" and not uninstall:
            print(hyprlua.diff(hyprlua.plan_install(text)))
        elif group in ("hyprland", "restore"):
            removed = hyprlua.read_removed(_removed_file(p))
            base = hyprlua.plan_uninstall(text, removed, False)
            shown = base if group == "hyprland" else hyprlua.Plan(
                original=base.new_text,
                new_text=hyprlua.plan_uninstall(text, removed, True).new_text)
            print(hyprlua.diff(shown))
        try:
            answer = input("Apply? [y/N] ").strip().lower()
        except EOFError:
            answer = ""
        if answer in ("y", "yes"):
            approved += members
        else:
            print("Skipped.")
    # a link whose way is blocked by a file the declined v1 group would have moved aside is left out
    blocked = _blocked(approved)
    for a in blocked:
        print(f"Left out: the link {a.path} (a file is in the way and its move was declined).")
    approved = [a for a in approved if a not in blocked]
    if not approved:
        print("\nNothing changed.")
        return 0
    apply(p, approved)
    print("\nDone.")
    return 0
