"""Run-time invariants of the isolation work (02 §1 I-1…I-4), checked by every writer.

Each check raises InvariantError ("isolation invariant: …"). Nothing catches it to carry on: a
violation stops the operation (or, in a release or an update, that one slot) before it changes
anything. The checks are cheap (realpath and string tests), so they run on every write, not just
in tests.
"""
from __future__ import annotations

import os
import re
from collections.abc import Iterable
from pathlib import Path

from ..paths import Paths, UnsafeHome, require_safe_home
from .journal import Journal, SlotKind, SlotRecord, SlotStatus, State
from .slots import SlotSpec


class InvariantError(RuntimeError):
    pass


# Journal transitions (02 §5.3–§5.7): from → the states a save may write next. None: no journal.
# A failed take goes taking → releasing; a release that leaves a failed slot stays releasing.
TRANSITIONS: dict[State | None, frozenset[State]] = {
    None: frozenset({State.TAKING}),
    State.RELEASED: frozenset({State.TAKING}),
    State.TAKING: frozenset({State.TAKING, State.HELD, State.RELEASING}),
    State.HELD: frozenset({State.HELD, State.RELEASING}),
    State.RELEASING: frozenset({State.RELEASING, State.RELEASED}),
}

# Slot statuses each journal state may hold.
STATUSES: dict[State, frozenset[SlotStatus]] = {
    State.TAKING: frozenset({SlotStatus.PENDING, SlotStatus.HELD}),
    State.HELD: frozenset({SlotStatus.HELD}),
    State.RELEASING: frozenset({SlotStatus.PENDING, SlotStatus.HELD, SlotStatus.RESTORED,
                                SlotStatus.FAILED}),
    State.RELEASED: frozenset({SlotStatus.RESTORED}),
}

# What a writer may write (02 §2): a leased slot, a scope mirror, an Own file, aptus's own state.
WRITE_KINDS = ("lease", "scope", "own", "state")

_SLOT_ID = re.compile(r"[a-z0-9][a-z0-9-]*\.[A-Za-z0-9][A-Za-z0-9_.-]*")
_SHA = re.compile(r"[0-9a-f]{64}")
_MODE = re.compile(r"0[0-7]{3}")


def fail(why: str) -> None:
    raise InvariantError(f"isolation invariant: {why}")


def transition(old: State | None, new: State) -> None:
    """The journal may go from `old` to `new` (TRANSITIONS)."""
    if new not in TRANSITIONS.get(old, frozenset()):
        fail(f"journal {old.value if old else 'none'} → {new.value}")


def _real(p: Path | str) -> str:
    return os.path.realpath(p)


def _under(where: str, root: Path | str) -> bool:
    r = _real(root)
    return where == r or where.startswith(r.rstrip(os.sep) + os.sep)


def never_paths(paths: Paths) -> list[Path]:
    """Places no aptus writer may ever touch (I-1, 02 §8–§9): Umbriel's and Noctalia's own files
    (also in ~/dotfiles), dconf's database (only `dconf` writes keys), the session's unit and
    environment dirs, hyprland.lua and Noctalia's hyprlock.conf, Papirus copies, the KDE colour
    scheme, the repository, fonts, XDG autostart, user GTK themes, the system. Under test also
    the whole sysroot and $HOME/.aptus-test (the fakes)."""
    home, cfg = paths.home, paths.config_home
    never = [paths.umbriel_config, paths.noctalia_settings.parent, paths.noctalia_config,
             home / "dotfiles/umbriel", home / "dotfiles/.git", cfg / "dconf",
             paths.systemd_user, cfg / "environment.d", paths.hyprland_lua,
             paths.hypr_config_dir / "hyprlock.conf", cfg / "autostart",
             paths.data_home / "color-schemes/noctalia.colors",
             paths.repo, paths.fonts, paths.user_themes, Path("/etc"), paths.sysroot / "etc"]
    never += [paths.icons / n for n in ("Papirus", "Papirus-Dark", "Papirus-Light")]
    if paths.test:
        never += [paths.sysroot, paths.test_bin.parent]
    return never


def _own_allowed(paths: Paths, where: str) -> bool:
    """Own files (08 §8): aptus's state and cache, the two qt6ct files, aptus-icons-{dark,light}
    (and their .new/.old siblings while one is rebuilt)."""
    if _under(where, paths.state) or _under(where, paths.cache):
        return True
    if where in (_real(paths.qt6ct_conf), _real(paths.qt6ct_colors)):
        return True
    return any(_under(where, paths.icons / f"aptus-icons-{m}{suffix}")
               for m in ("dark", "light") for suffix in ("", ".new", ".old"))


def writable(paths: Paths, target: Path, *, kind: str, no_link: bool = False) -> None:
    """`target`, with every symlink followed, may be written by a writer of `kind`.
    state: below aptus's state, cache or runtime dir (the runtime dir is outside HOME normally);
    every other kind: below HOME (under test: the temporary HOME, so a fixture linked into the
    real home is refused) and outside never_paths(); then
      lease: not inside aptus's own dirs (the caller has it as a journal slot),
      scope: below paths.scope,
      own:   below aptus's state or cache, the qt6ct files, or aptus-icons-{dark,light}.
    `no_link`: `target` itself must not be a symlink (an atomic rename would replace the link;
    the kinds write the realpath recorded at take). Also re-checks the safe HOME under test."""
    if kind not in WRITE_KINDS:
        fail(f"unknown write kind {kind!r}")
    try:
        require_safe_home(paths)
    except UnsafeHome as e:
        fail(str(e))
    if not os.path.isabs(target):
        fail(f"{target} is not an absolute path")
    if no_link and os.path.islink(target):
        fail(f"{target} became a symlink after the take")
    where = _real(target)
    if kind == "state":
        if not any(_under(where, r) for r in (paths.state, paths.cache, paths.runtime)):
            fail(f"state write {target} outside aptus's state, cache and runtime dirs")
        return
    if not _under(where, paths.home):
        fail(f"{target} ({where}) is outside HOME")
    for p in never_paths(paths):
        if _under(where, p):
            fail(f"{target} ({where}) is inside {p}")
    if kind == "scope" and not _under(where, paths.scope):
        fail(f"scope write {target} outside {paths.scope}")
    if kind == "own" and not _own_allowed(paths, where):
        fail(f"Own write {target} outside aptus's Own files")
    if kind == "lease" and any(_under(where, r) for r in (paths.state, paths.cache, paths.config)):
        fail(f"leased slot {target} inside aptus's own dirs")


def scope_entry(paths: Paths, into: str) -> Path:
    """scope/<into> with scope/ resolved but not the last component (swap replaces that link)."""
    check_scope_name(into)
    return Path(_real(paths.scope)) / into


def check_scope_name(into: str) -> None:
    """A scope name is one plain path component below scope/ ("kitty", "starship.toml")."""
    if not into or into in (".", "..") or "/" in into or into.startswith("."):
        fail(f"scope name {into!r} is not one plain path component")


def _check_id(slot_id: str, target: str) -> None:
    if not _SLOT_ID.fullmatch(slot_id) or not slot_id.startswith(target + "."):
        fail(f"slot id {slot_id!r} is not '<{target}>.<name>'")


def check_spec(paths: Paths, spec: SlotSpec) -> None:
    """A slot spec is consistent with its kind (02 §5.5) and names a writable slot."""
    _check_id(spec.id, spec.target)
    if spec.kind == SlotKind.DCONF:
        from .kinds import dconf
        if spec.path is not None or spec.content is not None or spec.sections:
            fail(f"dconf slot {spec.id} with a path, content or sections")
        try:
            dconf.check_key(spec.key, writing=spec.value is not None)
        except dconf.DconfError as e:
            fail(f"dconf slot {spec.id}: {e}")
        return
    if spec.path is None or spec.content is None or spec.key or spec.value is not None:
        fail(f"{spec.kind.value} slot {spec.id} needs a path and content, and no key or value")
    if spec.kind == SlotKind.INI and not spec.sections:
        fail(f"ini-sections slot {spec.id} without section globs")
    if spec.kind == SlotKind.FILE and spec.sections:
        fail(f"file slot {spec.id} with section globs")
    writable(paths, spec.path, kind="lease")


def check_specs(paths: Paths, specs: Iterable[SlotSpec]) -> None:
    """Every spec passes check_spec; ids and resolved slot files are unique."""
    ids, files = [], []
    for spec in specs:
        check_spec(paths, spec)
        ids.append(spec.id)
        if spec.path is not None:
            files.append(_real(spec.path))
    if len(ids) != len(set(ids)):
        fail("duplicate slot ids in one take or update")
    if len(files) != len(set(files)):
        fail("two slots resolve to the same file")


def check_update(spec: SlotSpec, rec: SlotRecord) -> None:
    """An update writes a slot as it was taken: same kind, path, key and sections."""
    if (spec.kind, str(spec.path or ""), spec.key, list(spec.sections)) != \
            (rec.kind, rec.path, rec.key, list(rec.sections)):
        fail(f"update of {spec.id} changes its kind, path, key or sections")


def _check_before(s: SlotRecord) -> None:
    """A slot that may still need restoring has a well-formed `before` (Noctalia's state)."""
    b = s.before
    if s.kind == SlotKind.DCONF:
        ok = isinstance(b.get("set"), bool) and (b.get("value") is None) != b["set"]
    elif not isinstance(b.get("exists"), bool):
        ok = False
    elif not b["exists"]:
        ok = True
    elif s.kind == SlotKind.FILE:
        ok = bool(_SHA.fullmatch(str(b.get("sha256", "")))) and bool(_MODE.fullmatch(str(b.get("mode", ""))))
    else:
        ok = bool(_MODE.fullmatch(str(b.get("mode", "")))) and isinstance(b.get("sections"), list)
    if not ok:
        fail(f"slot {s.id} has a malformed before record")


def check_journal(paths: Paths, j: Journal) -> None:
    """A journal about to be saved is consistent (02 §5.2): version 1, an owner unless released,
    `released_at` exactly when released, well-formed unique ids, statuses that fit the state,
    absolute unique slot files, a well-formed `before` for every slot not yet restored, dconf
    keys in the fixed set, record-only only for dconf. While taking or held every file/ini slot
    must also be writable (a release checks each slot when it restores it instead, so one slot
    whose path changed cannot stop the others from going back)."""
    if j.version != 1:
        fail(f"journal version {j.version}")
    if j.state != State.RELEASED and j.owner is None:
        fail(f"journal {j.state.value} without an owner")
    if (j.state == State.RELEASED) != bool(j.released_at):
        fail(f"journal {j.state.value} with released_at {j.released_at!r}")
    ids = [s.id for s in j.slots]
    if len(ids) != len(set(ids)):
        fail("duplicate slot ids in the journal")
    files = [s.write_path for s in j.slots if s.kind != SlotKind.DCONF]
    if len(files) != len(set(files)):
        fail("two journal slots write the same file")
    for s in j.slots:
        _check_id(s.id, s.target)
        if s.status not in STATUSES[j.state]:
            fail(f"slot {s.id} is {s.status.value} in a {j.state.value} journal")
        if s.status != SlotStatus.RESTORED:
            _check_before(s)
        if s.kind == SlotKind.DCONF:
            from .kinds import dconf
            try:
                dconf.check_key(s.key, writing=s.write)
            except dconf.DconfError as e:
                fail(f"journal slot {s.id}: {e}")
            continue
        if not s.write:
            fail(f"{s.kind.value} slot {s.id} marked record-only")
        if not os.path.isabs(s.path) or not os.path.isabs(s.write_path):
            fail(f"slot {s.id} has a relative path")
        if j.state in (State.TAKING, State.HELD):
            writable(paths, Path(s.write_path), kind="lease")


def check_save(old: Journal | None, new: Journal) -> None:
    """journal.save's choke point: the state change is a legal transition, and until released
    no slot disappears and no `before` changes (Noctalia's only record)."""
    transition(old.state if old else None, new.state)
    if old is None or old.state == State.RELEASED:
        return
    befores = {s.id: s.before for s in new.slots}
    for s in old.slots:
        if s.id not in befores:
            fail(f"slot {s.id} would vanish from the journal")
        if befores[s.id] != s.before:
            fail(f"slot {s.id}'s before would change")


def check_unset(names: Iterable[str], allowed: Iterable[str]) -> None:
    """The guard unsets only the variables aptus imported itself (02 §6)."""
    extra = sorted(set(names) - set(allowed))
    if extra:
        fail(f"unsetting {', '.join(extra)}, which aptus never set")
