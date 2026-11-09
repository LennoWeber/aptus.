"""Run-time invariants of the isolation work (02 §1 I-1…I-4), checked by every writer.

Each check raises InvariantError ("isolation invariant: …"). Nothing catches it to carry on: a
violation stops the operation before it changes anything. The checks are cheap and pure (realpath
and string tests only), so they run on every write, not just in tests.
"""
from __future__ import annotations

import os
import re
from collections.abc import Iterable
from pathlib import Path

from ..paths import Paths
from .journal import Journal, SlotKind, SlotStatus, State
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

# What a writer may write (02 §2): a leased slot, a scope mirror, an Own file, aptus's own state.
WRITE_KINDS = ("lease", "scope", "own", "state")

_SLOT_ID = re.compile(r"[a-z0-9][a-z0-9-]*\.[A-Za-z0-9][A-Za-z0-9_.-]*")


def fail(why: str) -> None:
    raise InvariantError(f"isolation invariant: {why}")


def transition(old: State | None, new: State) -> None:
    """The journal may go from `old` to `new` (TRANSITIONS)."""
    if new not in TRANSITIONS.get(old, frozenset()):
        fail(f"journal {old.value if old else 'none'} → {new.value}")


def _real(p: Path | str) -> str:
    return os.path.realpath(p)


def _under(where: str, root: Path) -> bool:
    r = _real(root)
    return where == r or where.startswith(r.rstrip(os.sep) + os.sep)


def never_paths(paths: Paths) -> list[Path]:
    """Places no aptus writer may ever touch (I-1, 02 §8–§9): Umbriel's and Noctalia's own files,
    the repository, the fonts dir, XDG autostart, user GTK themes, and the system."""
    return [paths.umbriel_config, paths.noctalia_settings.parent, paths.noctalia_config,
            paths.repo, paths.fonts, paths.config_home / "autostart", paths.user_themes,
            paths.sysroot / "etc", Path("/etc")]


def _own_allowed(paths: Paths, where: str) -> bool:
    """Own files (08 §8): aptus's state and cache, the two qt6ct files, aptus-icons-{dark,light}."""
    if _under(where, paths.state) or _under(where, paths.cache):
        return True
    if where in (_real(paths.qt6ct_conf), _real(paths.qt6ct_colors)):
        return True
    return any(_under(where, paths.icons / f"aptus-icons-{m}") for m in ("dark", "light"))


def writable(paths: Paths, target: Path, *, kind: str) -> None:
    """`target`, with every symlink followed, may be written by a writer of `kind`:
    always below HOME (under test: the temporary HOME, so a fixture linked into the real home is
    refused) and outside never_paths(); then per kind
      lease: anywhere else (the caller has it as a journal slot),
      scope: below paths.scope,
      own:   below aptus's state or cache, the qt6ct files, or aptus-icons-{dark,light},
      state: below aptus's state, cache or runtime dir."""
    if kind not in WRITE_KINDS:
        fail(f"unknown write kind {kind!r}")
    where = _real(target)
    if not _under(where, paths.home):
        fail(f"{target} ({where}) is outside HOME")
    for p in never_paths(paths):
        if _under(where, p):
            fail(f"{target} ({where}) is inside {p}")
    if kind == "scope" and not _under(where, paths.scope):
        fail(f"scope write {target} outside {paths.scope}")
    if kind == "own" and not _own_allowed(paths, where):
        fail(f"Own write {target} outside aptus's Own files")
    if kind == "state" and not any(_under(where, r) for r in (paths.state, paths.cache, paths.runtime)):
        fail(f"state write {target} outside aptus's state, cache and runtime dirs")
    if kind == "lease" and any(_under(where, r) for r in (paths.state, paths.cache, paths.config)):
        fail(f"leased slot {target} inside aptus's own dirs")


def check_spec(paths: Paths, spec: SlotSpec) -> None:
    """A slot spec is consistent with its kind (02 §5.5) and names a writable slot."""
    if not _SLOT_ID.fullmatch(spec.id) or not spec.id.startswith(spec.target + "."):
        fail(f"slot id {spec.id!r} is not '<{spec.target}>.<name>'")
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
    """Every spec passes check_spec, and the ids are unique."""
    ids = []
    for spec in specs:
        check_spec(paths, spec)
        ids.append(spec.id)
    if len(ids) != len(set(ids)):
        fail("duplicate slot ids in one take or update")


def check_scope_name(into: str) -> None:
    """A scope name is one plain path component below scope/ ("kitty", "starship.toml")."""
    if not into or into in (".", "..") or "/" in into or into.startswith("."):
        fail(f"scope name {into!r} is not one plain path component")


def check_journal(paths: Paths, j: Journal) -> None:
    """A journal about to be saved is consistent (02 §5.2): an owner unless released, slot ids
    unique, statuses that fit the state, every file/ini slot writable, dconf keys in the fixed set,
    and record-only slots only for record-only dconf keys or a dconf key not written."""
    if j.version != 1:
        fail(f"journal version {j.version}")
    if j.state != State.RELEASED and j.owner is None:
        fail(f"journal {j.state.value} without an owner")
    if (j.state == State.RELEASED) != bool(j.released_at):
        fail(f"journal {j.state.value} with released_at {j.released_at!r}")
    ids = [s.id for s in j.slots]
    if len(ids) != len(set(ids)):
        fail("duplicate slot ids in the journal")
    allowed = {
        State.TAKING: {SlotStatus.PENDING, SlotStatus.HELD},
        State.HELD: {SlotStatus.HELD},
        State.RELEASING: {SlotStatus.PENDING, SlotStatus.HELD, SlotStatus.RESTORED, SlotStatus.FAILED},
        State.RELEASED: {SlotStatus.RESTORED},
    }[j.state]
    for s in j.slots:
        if s.status not in allowed:
            fail(f"slot {s.id} is {s.status.value} in a {j.state.value} journal")
        if s.kind == SlotKind.DCONF:
            from .kinds import dconf
            try:
                dconf.check_key(s.key, writing=s.write)
            except dconf.DconfError as e:
                fail(f"journal slot {s.id}: {e}")
        else:
            if not s.write:
                fail(f"{s.kind.value} slot {s.id} marked record-only")
            writable(paths, Path(s.write_path or s.path), kind="lease")


def check_unset(names: Iterable[str], allowed: Iterable[str]) -> None:
    """The guard unsets only the variables aptus imported itself (02 §6)."""
    extra = sorted(set(names) - set(allowed))
    if extra:
        fail(f"unsetting {', '.join(extra)}, which aptus never set")
