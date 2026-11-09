"""The target manifest theme/targets.toml (08 §5): one entry per row of 02-isolation §4. Adding an
app is adding an entry and a template. Also the coverage rule (02 §4): Noctalia's enabled
templates against the entries' `noctalia` lists."""
from __future__ import annotations

import glob
import hashlib
import os
import tomllib
from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any

from ..lease.journal import SlotKind
from ..paths import Paths
from .noctalia import Enabled


class Mechanism(str, Enum):
    LEASE = "lease"
    SCOPE = "scope"
    OWN = "own"
    BAKE = "bake"
    NEVER = "never"            # stays Noctalia's on purpose (with a `note` saying why)


@dataclass(frozen=True)
class FileOut:
    """One rendered file of a target and where it goes. Paths may start with `~` or one of
    {config} {state} {cache} {data} (the XDG base directories, so tests and a changed XDG variable
    agree with paths.py)."""
    template: str              # path below theme/templates ("ghostty/noctalia")
    out: str                   # path inside the generation ("ghostty/noctalia")
    name: str = "artifact"     # slot id "<target>.<name>"; a `*` slot adds ".<sha256(path)[:8]>"
    slot: str = ""             # lease / bake: the artifact (may hold one `*`, globbed, sorted)
    dest: str = ""             # own: where the file is written
    at: str = ""               # scope mirror: the path inside the mirror this file replaces
    missing_only: bool = False # scope mirror: used only when the mirrored source lacks `at`


@dataclass(frozen=True)
class ScopeSpec:
    """Scope outputs below scope/: a mirror of `mirror` in scope/<into> (symlinks to every entry,
    except the target's files at their `at` paths), or a copy of `source` with the text between
    the `begin` and `end` lines replaced by the rendered file (starship)."""
    into: str                  # name below scope/ ("kitty", "starship.toml"); no "/" or ".."
    mirror: str = ""
    source: str = ""
    begin: str = ""
    end: str = ""


@dataclass(frozen=True)
class Target:
    id: str
    row: int                                   # row in 02-isolation §4
    mechanism: Mechanism
    noctalia: tuple[str, ...] = ()             # Noctalia template ids this covers (or keeps, for never)
    kind: SlotKind = SlotKind.FILE             # lease / bake
    files: tuple[FileOut, ...] = ()
    sections: tuple[str, ...] = ()             # ini-sections globs
    dconf: tuple[tuple[str, str], ...] = ()    # (key name, value template; "" = record only)
    requires: tuple[tuple[str, str], ...] = () # dconf: (key name, target id) — the key is only
                                               # recorded when that target is not applied (icons)
    scope: ScopeSpec | None = None
    own: str = ""                              # builtin Own step: icons | bat | ""
    when: str = "always"                       # always | exists:<path> | which:<command>
    present: bool = False                      # lease only the slots that exist (02 §4 "only if present")
    reload: str = "none"                       # none | signal:<comm>:<SIG> | exec:<cmd> | builtin:<name> | bake:<process>:<cmd>
    note: str = ""


@dataclass
class Manifest:
    path: Path
    targets: tuple[Target, ...]
    inert: dict[str, str] = field(default_factory=dict)   # Noctalia id → why it does not matter in Hyprland


@dataclass
class Coverage:
    covered: dict[str, str] = field(default_factory=dict)    # Noctalia id → target id
    kept: dict[str, str] = field(default_factory=dict)       # Noctalia id → target id of a `never` target
    inert: dict[str, str] = field(default_factory=dict)      # Noctalia id → reason
    uncovered: list[str] = field(default_factory=list)       # reported: "uncovered: <id>"


class ManifestError(ValueError):
    """targets.toml is malformed (unknown field, mechanism, kind, reload or a missing template)."""


_TARGET_KEYS = {"id", "row", "noctalia", "mechanism", "kind", "files", "template", "out", "name",
                "slot", "sections", "dconf", "requires", "scope", "own", "when", "present",
                "reload", "note"}
_FILE_KEYS = {"template", "out", "name", "slot", "dest", "at", "missing_only"}
_SCOPE_KEYS = {"into", "mirror", "source", "begin", "end"}
_OWN_STEPS = ("", "icons", "bat")
_PREFIXES = {"{config}": "config_home", "{state}": "state_home", "{cache}": "cache_home",
             "{data}": "data_home"}


def load(path: Path, templates: Path | None = None) -> Manifest:
    """Parse and validate targets.toml (tomllib); `templates` defaults to the `templates`
    directory next to it, where every named template must exist."""
    templates = templates or path.parent / "templates"
    try:
        with open(path, "rb") as f:
            raw = tomllib.load(f)
    except (OSError, tomllib.TOMLDecodeError) as e:
        raise ManifestError(f"{path}: {e}") from e
    unknown = set(raw) - {"target", "inert"}
    if unknown:
        raise ManifestError(f"unknown top-level keys {sorted(unknown)}")
    parsed = tuple(parse_target(t) for t in raw.get("target", []))
    ids = [t.id for t in parsed]
    dup = sorted({i for i in ids if ids.count(i) > 1})
    if dup:
        raise ManifestError(f"duplicate target ids {dup}")
    for t in parsed:
        _check_target(t, templates, set(ids))
    inert = raw.get("inert", {})
    if not isinstance(inert, dict) or not all(isinstance(v, str) for v in inert.values()):
        raise ManifestError("[inert] maps a Noctalia id to a reason")
    return Manifest(path=path, targets=parsed, inert=dict(inert))


def _check_target(t: Target, templates: Path, ids: set[str]) -> None:
    from . import hooks
    try:
        hooks.parse(t.reload)
    except ValueError as e:
        raise ManifestError(f"{t.id}: {e}") from e
    for f in t.files:
        if not (templates / f.template).is_file():
            raise ManifestError(f"{t.id}: template {f.template} does not exist")
        if os.path.isabs(f.out) or ".." in Path(f.out).parts:
            raise ManifestError(f"{t.id}: out {f.out!r} must stay inside the generation")
    for key, needed in t.requires:
        if needed not in ids or key not in dict(t.dconf):
            raise ManifestError(f"{t.id}: requires {key} = {needed} names no key or target")
    if not (t.when == "always" or t.when.startswith(("exists:", "which:"))):
        raise ManifestError(f"{t.id}: when {t.when!r}")
    _check_mechanism(t)


def _check_mechanism(t: Target) -> None:
    m, files = t.mechanism, t.files
    if m in (Mechanism.LEASE, Mechanism.BAKE):
        if t.kind == SlotKind.DCONF:
            if not t.dconf or files:
                raise ManifestError(f"{t.id}: a dconf target has a [target.dconf] table only")
        elif not files or not all(f.slot for f in files):
            raise ManifestError(f"{t.id}: every file of a {m.value} target needs a slot")
        if t.kind == SlotKind.INI and not t.sections:
            raise ManifestError(f"{t.id}: ini-sections without sections")
        if any(f.slot.count("*") > 1 for f in files):
            raise ManifestError(f"{t.id}: a slot holds at most one *")
    if m == Mechanism.OWN and not all(f.dest for f in files):
        raise ManifestError(f"{t.id}: every file of an own target needs a dest")
    if m == Mechanism.OWN and t.own not in _OWN_STEPS:
        raise ManifestError(f"{t.id}: own step {t.own!r}")
    if m == Mechanism.SCOPE:
        _check_scope(t)
    if m == Mechanism.NEVER and (files or t.dconf):
        raise ManifestError(f"{t.id}: a never target renders nothing")
    if m == Mechanism.BAKE and not t.reload.startswith("bake:"):
        raise ManifestError(f"{t.id}: a bake target needs reload = bake:<process>:<command>")


def _check_scope(t: Target) -> None:
    sc = t.scope
    if sc is None:
        raise ManifestError(f"{t.id}: a scope target needs scope = {{ into, … }}")
    if not sc.into or sc.into in (".", "..") or "/" in sc.into or sc.into.startswith("."):
        raise ManifestError(f"{t.id}: scope into {sc.into!r} is not one plain name")
    if bool(sc.mirror) == bool(sc.source):
        raise ManifestError(f"{t.id}: scope has either mirror or source")
    if sc.mirror and not all(f.at and ".." not in Path(f.at).parts and not os.path.isabs(f.at)
                             for f in t.files):
        raise ManifestError(f"{t.id}: every file of a mirror needs a relative `at`")
    if sc.source and (len(t.files) != 1 or not sc.begin or not sc.end):
        raise ManifestError(f"{t.id}: a marked scope has one file and begin/end markers")


def _fileout(raw: dict[str, Any], where: str) -> FileOut:
    unknown = set(raw) - _FILE_KEYS
    if unknown:
        raise ManifestError(f"{where}: unknown file keys {sorted(unknown)}")
    if not raw.get("template") or not raw.get("out"):
        raise ManifestError(f"{where}: a file needs template and out")
    return FileOut(template=raw["template"], out=raw["out"], name=raw.get("name", "artifact"),
                   slot=raw.get("slot", ""), dest=raw.get("dest", ""), at=raw.get("at", ""),
                   missing_only=bool(raw.get("missing_only", False)))


def _enum(cls: type[Enum], value: Any, where: str) -> Any:
    try:
        return cls(value)
    except ValueError:
        raise ManifestError(f"{where}: unknown {cls.__name__.lower()} {value!r}") from None


def parse_target(raw: dict[str, Any]) -> Target:
    """One `[[target]]` table; the one-file shorthand (template/out/slot at the top level) becomes
    a single FileOut."""
    tid = raw.get("id")
    if not isinstance(tid, str) or not tid:
        raise ManifestError(f"a target without an id: {raw}")
    unknown = set(raw) - _TARGET_KEYS
    if unknown:
        raise ManifestError(f"{tid}: unknown keys {sorted(unknown)}")
    if "template" in raw and "files" in raw:
        raise ManifestError(f"{tid}: template and files together")
    short = {k: raw[k] for k in ("template", "out", "name", "slot") if k in raw}
    files = [short] if "template" in raw else raw.get("files", [])
    if not short.get("template") and short:
        raise ManifestError(f"{tid}: name/slot/out without template")
    scope = raw.get("scope")
    if scope is not None:
        if not isinstance(scope, dict) or set(scope) - _SCOPE_KEYS:
            raise ManifestError(f"{tid}: scope keys {sorted(scope) if isinstance(scope, dict) else scope}")
        scope = ScopeSpec(**scope)
    return Target(
        id=tid, row=int(raw.get("row", 0)),
        mechanism=_enum(Mechanism, raw.get("mechanism"), tid),
        noctalia=tuple(raw.get("noctalia", ())),
        kind=_enum(SlotKind, raw.get("kind", "file"), tid),
        files=tuple(_fileout(f, tid) for f in files),
        sections=tuple(raw.get("sections", ())),
        dconf=tuple(sorted(raw.get("dconf", {}).items())),
        requires=tuple(sorted(raw.get("requires", {}).items())),
        scope=scope, own=raw.get("own", ""), when=raw.get("when", "always"),
        present=bool(raw.get("present", False)), reload=raw.get("reload", "none"),
        note=raw.get("note", ""))


def expand(paths: Paths, value: str, *, system: bool = False) -> Path:
    """`~` → paths.home, {config} {state} {cache} {data} → the XDG base directories. A path aptus
    may write (slot, dest, mirror) must lie below HOME and outside ~/.config/umbriel,
    ~/.local/state/noctalia and /etc, else ManifestError. With `system` (a `when` or a read-only
    source) an absolute path outside HOME is allowed and mapped into paths.sysroot."""
    if value == "~" or value.startswith("~/"):
        out = str(paths.home) + value[1:]
    elif value.split("/", 1)[0] in _PREFIXES:
        head, _, rest = value.partition("/")
        out = os.path.join(str(getattr(paths, _PREFIXES[head])), rest)
    elif os.path.isabs(value) and system:
        out = os.path.join(str(paths.sysroot), value.lstrip("/"))
    else:
        raise ManifestError(f"path {value!r}: starts with ~, {{config}}, {{state}}, {{cache}} "
                            f"or {{data}}")
    out = os.path.normpath(out)
    if system and value.startswith("/"):
        return Path(out)
    if not _below(out, paths.home):
        raise ManifestError(f"path {value!r} leaves HOME")
    for never in (paths.umbriel_config, paths.noctalia_settings.parent, Path("/etc")):
        if _below(out, never):
            raise ManifestError(f"path {value!r} lies inside {never}")
    return Path(out)


def _below(path: str, root: Path) -> bool:
    r = os.path.normpath(str(root))
    return path == r or path.startswith(r.rstrip("/") + "/")


def active(paths: Paths, target: Target) -> bool:
    """The `when` rule: always, exists:<path>, which:<command> (under test: $HOME/.aptus-test/bin)."""
    from ..lease import system
    kind, _, arg = target.when.partition(":")
    if kind == "exists":
        return expand(paths, arg, system=True).exists()
    if kind == "which":
        return system.tool(paths, arg) is not None
    return True


def slot_id(target: Target, f: FileOut, slot: Path) -> str:
    """"<target>.<name>", plus ".<sha256(path)[:8]>" for a slot found through a `*`."""
    if "*" not in f.slot:
        return f"{target.id}.{f.name}"
    return f"{target.id}.{f.name}.{hashlib.sha256(str(slot).encode()).hexdigest()[:8]}"


def slots(paths: Paths, target: Target) -> list[tuple[FileOut, Path]]:
    """(file, slot path) of a lease or bake target: `*` expanded by glob (sorted), and with
    `present` only the slots that exist."""
    out: list[tuple[FileOut, Path]] = []
    for f in target.files:
        if not f.slot:
            continue
        p = expand(paths, f.slot)
        if "*" in f.slot:
            found = [Path(m) for m in sorted(glob.glob(glob.escape(str(p)).replace("[*]", "*")))]
        else:
            found = [p]
        out += [(f, s) for s in found if not target.present or s.exists()]
    return out


def coverage(manifest: Manifest, enabled: Enabled, slot_paths: Mapping[Path, str]) -> Coverage:
    """Each enabled Noctalia id is covered by a lease/scope/own/bake target's `noctalia` list, kept
    by a `never` target's, inert, or (a user template) covered when its output path is one of
    `slot_paths` (slot path → target id); else uncovered."""
    result = Coverage()
    by_id: dict[str, Target] = {}
    for t in manifest.targets:
        for nid in t.noctalia:
            by_id.setdefault(nid, t)
    outputs = {os.path.normpath(str(p)): tid for p, tid in slot_paths.items()}
    for nid in dict.fromkeys([*enabled.builtin, *enabled.community, *enabled.user]):
        t = by_id.get(nid)
        user_out = os.path.normpath(enabled.user[nid]) if enabled.user.get(nid) else ""
        if t is not None:
            (result.kept if t.mechanism == Mechanism.NEVER else result.covered)[nid] = t.id
        elif nid in manifest.inert:
            result.inert[nid] = manifest.inert[nid]
        elif user_out in outputs:
            result.covered[nid] = outputs[user_out]
        else:
            result.uncovered.append(nid)
    return result
