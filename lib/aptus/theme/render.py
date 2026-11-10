"""aptus-theme render (08 §4): the template language and the generations.

Template language (no logic): `{{ name }}` or `{{ name | filter }}`; the names are listed at
`context`, the filters in FILTERS (08 §4). An unknown name or filter fails that target only.

Output: ~/.local/state/aptus/theme/gen-<n>/ with every target's files, resolved.json and
inputs.json; then `current` is swapped to it atomically; the last three generations are kept. An
unchanged input hash (the template context + inputs + manifest + templates) renders nothing.
"""
from __future__ import annotations

import colorsys
import dataclasses
import fcntl
import hashlib
import json
import logging
import math
import os
import re
import shutil
import threading
import time
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from .. import atomic
from ..lease import invariants
from ..paths import Paths, require_safe_home
from . import inputs as inputs_mod
from . import palette, resolve
from .inputs import Inputs
from .targets import FileOut, Manifest, Mechanism, Target


class TemplateError(ValueError):
    """An unknown name or filter, or a malformed placeholder, in one template."""


@dataclass
class Generation:
    n: int                                     # gen-<n>
    path: Path
    input_hash: str
    resolved: dict[str, Any]
    inputs: Inputs | None = None               # the inputs it was rendered from (inputs.json)
    reused: bool = False                       # the input hash was unchanged: nothing rendered
    failed: dict[str, str] = field(default_factory=dict)   # target id → error (previous output kept)


FILTERS = ("hex", "hexnoh", "rgb", "csv", "rgba", "hyprrgba", "argb", "hsl", "hue", "saturation",
           "lightness", "int")
WITH_ARG = ("rgba", "hyprrgba", "argb")       # the alpha: a number or a numeric name (shadowAlpha)
KEEP = 3                                       # generations kept (08 §4)
LOCK_TIMEOUT = 30.0
PLACEHOLDER = re.compile(
    r"\{\{\s*([A-Za-z0-9_.]+)\s*(?:\|\s*([a-z]+)(?:\(\s*([A-Za-z0-9_.]+)\s*\))?\s*)?\}\}")
GEN = re.compile(r"gen-(\d+)")
DCONF_JSON = "dconf.json"
FAILED_JSON = "failed.json"            # target id → why, for the targets that failed to render
_COLOUR = re.compile(r"#[0-9a-f]{6}")
_held: dict[tuple[str, int], list[int]] = {}   # (lock path, thread) → [fd, depth]
_log = logging.getLogger("aptus.theme.render")


class LockBusy(RuntimeError):
    """The theme lock stayed busy for the whole timeout."""


@contextmanager
def lock(paths: Paths, timeout: float = LOCK_TIMEOUT) -> Iterator[None]:
    """flock(theme/lock) around render, scope, Own writes and the bake queue, so two applies never
    race on gen-<n+1> and `current`; checks require_safe_home first. Re-entrant within one thread
    (apply holds it while render takes it again). Separate from the lease lock, which is taken
    inside it (theme first, then lease), never the other way round."""
    require_safe_home(paths)
    key = (str(paths.theme_lock), threading.get_ident())
    if key in _held:
        _held[key][1] += 1
        try:
            yield
        finally:
            _held[key][1] -= 1
        return
    invariants.writable(paths, paths.theme_lock, kind="state")
    paths.theme.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd = os.open(paths.theme_lock, os.O_RDWR | os.O_CREAT | os.O_CLOEXEC, 0o600)
    end = time.monotonic() + timeout
    while True:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            break
        except BlockingIOError:
            if time.monotonic() > end:
                os.close(fd)
                raise LockBusy(f"the theme lock is busy (waited {timeout:.0f} s)") from None
            time.sleep(0.05)
    _held[key] = [fd, 1]
    try:
        yield
    finally:
        del _held[key]
        fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)


def _text(value: Any) -> str:
    """A context value as text: strings as they are, numbers in their JSON form (1 stays "1")."""
    return value if isinstance(value, str) else json.dumps(value)


def _lua(flag: bool) -> str:
    return "true" if flag else "false"


def context(resolved: dict[str, Any], resolved_dark: dict[str, Any],
            resolved_light: dict[str, Any], tokens: dict[str, Any], inputs: Inputs,
            generation: int, paths: Paths) -> dict[str, str]:
    """Every name a template may use → its value as text: the roles (colours "#rrggbb", alphas as
    numbers) and groundAlpha, `dark.<role>`/`light.<role>` (both modes with the same accent and
    contrast, for templates that carry both), ansi0…ansi15, mode, accent.name, papirus.folder,
    gnome.accent, font.ui/.mono (families), font.<uiApp|documentApp|monoApp> with .family and
    .size, cursor.theme, cursor.size, frame.edge, window.gap, glass, reduce_motion (Lua booleans),
    generation, dir.config/state/cache/data (the XDG bases)."""
    ctx = {k: _text(v) for k, v in resolved["roles"].items()}
    ctx["groundAlpha"] = _text(resolved["groundAlpha"])
    for prefix, other in (("dark", resolved_dark), ("light", resolved_light)):
        ctx.update({f"{prefix}.{k}": _text(v) for k, v in other["roles"].items()})
    ctx.update({f"ansi{i}": c for i, c in enumerate(resolved["ansi"])})
    families = tokens["type"]["families"]
    ctx.update({"mode": resolved["mode"], "accent.name": resolved["accentName"],
                "papirus.folder": resolved["papirus"], "gnome.accent": resolved["gnomeAccent"],
                "font.ui": families["ui"], "font.mono": families["mono"],
                "cursor.theme": tokens["cursor"]["theme"], "cursor.size": _text(tokens["cursor"]["size"]),
                "frame.edge": _text(inputs.frame_edge),
                "window.gap": _text(tokens["geometry"]["windowGap"]),
                "glass": _lua(bool(resolved["glass"])), "reduce_motion": _lua(inputs.reduce_motion),
                "generation": str(generation),
                "dir.config": str(paths.config_home), "dir.state": str(paths.state_home),
                "dir.cache": str(paths.cache_home), "dir.data": str(paths.data_home)})
    for name, value in tokens["fonts"].items():
        family, _, size = value.rpartition(" ")
        ctx[f"font.{name}"] = value
        ctx[f"font.{name}.family"], ctx[f"font.{name}.size"] = family, size
    return ctx


def _alpha(arg: str, ctx: dict[str, str]) -> float:
    value = ctx.get(arg, arg)
    try:
        a = float(value)
    except ValueError:
        raise TemplateError(f"alpha {arg!r} is not a number") from None
    if not 0 <= a <= 1:
        raise TemplateError(f"alpha {a} outside 0..1")
    return a


def _round(x: float) -> int:
    return math.floor(x + 0.5)


def _hsl(value: str) -> tuple[int, int, int]:
    r, g, b = (c / 255 for c in palette.hex_to_rgb(value))
    h, lightness, s = colorsys.rgb_to_hls(r, g, b)
    return _round(h * 360) % 360, _round(s * 100), _round(lightness * 100)


def _num(x: float) -> str:
    return str(int(x)) if float(x).is_integer() else repr(float(x))


def apply_filter(value: str, name: str, arg: str | None, ctx: dict[str, str]) -> str:
    """One filter on a "#rrggbb" value (08 §4 table plus csv = "r,g,b" as Noctalia's rgb_csv, and
    hue/saturation/lightness = the HSL components); TemplateError for an unknown filter, a missing
    or surplus argument, an alpha outside 0..1, or a filter on a value that is not a colour."""
    if name not in FILTERS:
        raise TemplateError(f"unknown filter {name!r}")
    if (arg is None) == (name in WITH_ARG):
        raise TemplateError(f"filter {name} " + ("needs an alpha" if arg is None else "takes no argument"))
    if not _COLOUR.fullmatch(value):
        raise TemplateError(f"filter {name} on {value!r}, which is not a colour")
    r, g, b = palette.hex_to_rgb(value)
    simple = {"hex": value, "hexnoh": value[1:], "rgb": f"{r}, {g}, {b}", "csv": f"{r},{g},{b}",
              "int": str((r << 16) | (g << 8) | b)}
    if name in simple:
        return simple[name]
    if name in ("hsl", "hue", "saturation", "lightness"):
        h, s, li = _hsl(value)
        return {"hsl": f"hsl({h}, {s}%, {li}%)", "hue": str(h), "saturation": str(s),
                "lightness": str(li)}[name]
    a = _alpha(arg or "", ctx)
    a8 = palette.round8(a * 255)
    if name == "rgba":
        return f"rgba({r}, {g}, {b}, {_num(a)})"
    if name == "hyprrgba":
        return f"rgba({value[1:]}{a8:02x})"
    return f"#{a8:02x}{value[1:]}"          # argb


def render_text(template: str, ctx: dict[str, str]) -> str:
    """Replace every placeholder; an unknown name, or a `{{` left that does not form a placeholder,
    is a TemplateError with the line number."""
    stray = PLACEHOLDER.sub("", template).find("{{")
    if stray >= 0:
        cleaned = PLACEHOLDER.sub(lambda m: " " * len(m.group(0)), template)
        line = cleaned.count("\n", 0, cleaned.find("{{")) + 1
        raise TemplateError(f"malformed placeholder on line {line}")

    def one(m: re.Match[str]) -> str:
        name, filt, arg = m.group(1), m.group(2), m.group(3)
        if name not in ctx:
            line = template.count("\n", 0, m.start()) + 1
            raise TemplateError(f"unknown name {name!r} on line {line}")
        try:
            return apply_filter(ctx[name], filt, arg, ctx) if filt else ctx[name]
        except TemplateError as e:
            raise TemplateError(f"{e} on line {template.count(chr(10), 0, m.start()) + 1}") from None
    return PLACEHOLDER.sub(one, template)


def input_hash(ctx: dict[str, str], inputs: Inputs, manifest_path: Path, templates: Path) -> str:
    """SHA-256 over the template context (without `generation`), inputs.json, the manifest and
    every template file (sorted by path)."""
    h = hashlib.sha256()
    stable = {k: v for k, v in ctx.items() if k != "generation"}
    for obj in (stable, inputs_mod.to_dict(inputs)):
        h.update(json.dumps(obj, sort_keys=True).encode() + b"\0")
    h.update(manifest_path.read_bytes() + b"\0")
    for f in sorted(p for p in templates.rglob("*") if p.is_file()):
        h.update(str(f.relative_to(templates)).encode() + b"\0" + f.read_bytes() + b"\0")
    return h.hexdigest()


def _gen_n(name: str) -> int | None:
    m = GEN.fullmatch(name)
    return int(m.group(1)) if m else None


def current(paths: Paths) -> Generation | None:
    """The generation `current` points at (None when there is none or it is unreadable)."""
    try:
        name = os.readlink(paths.theme_current)
    except OSError:
        return None
    n = _gen_n(name)
    if n is None:
        return None
    path = paths.theme / name
    try:
        resolved = json.loads((path / "resolved.json").read_text(encoding="utf-8"))
        digest = (path / ".input-hash").read_text(encoding="utf-8").strip()
    except (OSError, ValueError):
        return None
    try:
        inputs = inputs_mod.from_json((path / "inputs.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        inputs = None
    try:
        failed = json.loads((path / FAILED_JSON).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        failed = {}
    return Generation(n=n, path=path, input_hash=digest, resolved=resolved, inputs=inputs,
                      failed={str(k): str(v) for k, v in failed.items()}
                      if isinstance(failed, dict) else {})


def _next_n(paths: Paths) -> int:
    ns = [n for p in paths.theme.iterdir() if (n := _gen_n(p.name)) is not None] \
        if paths.theme.is_dir() else []
    return max(ns, default=0) + 1


def _render_target(paths: Paths, target: Target, ctx: dict[str, str], build: Path) -> None:
    """One target's files into the build directory; dconf targets as <id>/dconf.json."""
    for f in target.files:
        text = render_text((paths.templates / f.template).read_text(encoding="utf-8"), ctx)
        out = build / f.out
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(text, encoding="utf-8")
    if target.dconf:
        values = {key: render_text(tpl, ctx) if tpl else None for key, tpl in target.dconf}
        (build / target.id).mkdir(parents=True, exist_ok=True)
        (build / target.id / DCONF_JSON).write_text(json.dumps(values, indent=2, sort_keys=True) + "\n")


def _keep_previous(target: Target, prev: Generation | None, build: Path) -> None:
    """A failed target keeps the output of the previous generation (when there is one)."""
    if prev is None:
        return
    outs = [f.out for f in target.files] + ([f"{target.id}/{DCONF_JSON}"] if target.dconf else [])
    for out in outs:
        src = prev.path / out
        if src.is_file():
            (build / out).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, build / out)


def render(paths: Paths, inputs: Inputs, manifest: Manifest) -> Generation:
    """Under the theme lock: resolve (both modes too), hash; unchanged → the current generation
    with reused=True. Else write gen-<n+1>/: every target's files (rendering is cheap; `when`
    decides only what is applied) and, for dconf targets, <id>/dconf.json (a failing target keeps
    its previous output, copied from the current generation, and is listed in `failed`),
    resolved.json, inputs.json, .input-hash; swap `current`; write theme/resolved.json (the stable
    copy the shell watches: a swapped symlink is not seen, phase-5 probe); prune."""
    with lock(paths):
        tokens = resolve.load_tokens(paths)
        res = resolve.resolve(tokens, inputs)
        dark = resolve.resolve(tokens, dataclasses.replace(inputs, mode="dark"))
        light = resolve.resolve(tokens, dataclasses.replace(inputs, mode="light"))
        prev = current(paths)
        n = _next_n(paths)
        ctx = context(res, dark, light, tokens, inputs, n, paths)
        digest = input_hash(ctx, inputs, manifest.path, paths.templates)
        if prev is not None and prev.input_hash == digest:
            prev.reused = True
            return prev
        invariants.writable(paths, paths.theme / f"gen-{n}", kind="state")
        build = paths.theme / f".gen-{n}.build"
        shutil.rmtree(build, ignore_errors=True)
        build.mkdir(parents=True, mode=0o700)
        failed = {}
        for target in manifest.targets:
            if target.mechanism == Mechanism.NEVER:
                continue
            try:
                _render_target(paths, target, ctx, build)
            except (TemplateError, OSError, UnicodeError) as e:
                failed[target.id] = f"{type(e).__name__}: {e}"
                _log.warning("render %s failed: %s", target.id, failed[target.id])
                _keep_previous(target, prev, build)
        _finish(paths, build, res, inputs, digest, failed)
        gen = paths.theme / f"gen-{n}"
        os.rename(build, gen)
        atomic.fsync_dir(paths.theme)
        atomic.symlink(Path(gen.name), paths.theme_current)
        invariants.writable(paths, paths.theme_resolved, kind="state")
        atomic.write_text(paths.theme_resolved, json.dumps(res, indent=2) + "\n", 0o644)
        prune(paths)
        return Generation(n=n, path=gen, input_hash=digest, resolved=res, inputs=inputs,
                          failed=failed)


def _finish(paths: Paths, build: Path, res: dict[str, Any], inputs: Inputs, digest: str,
            failed: dict[str, str]) -> None:
    """The generation's own files (written into the private build directory, which becomes
    visible only through the atomic rename to gen-<n>), then fsync of everything."""
    (build / "resolved.json").write_text(json.dumps(res, indent=2) + "\n", encoding="utf-8")
    (build / FAILED_JSON).write_text(json.dumps(failed, indent=2, sort_keys=True) + "\n",
                                     encoding="utf-8")
    (build / "inputs.json").write_text(json.dumps(inputs_mod.to_dict(inputs), indent=2) + "\n",
                                       encoding="utf-8")
    (build / ".input-hash").write_text(digest + "\n", encoding="utf-8")
    for d, _, files in os.walk(build):
        for f in files:
            with open(os.path.join(d, f), "rb") as fh:
                os.fsync(fh.fileno())


def prune(paths: Paths, keep: int = KEEP) -> None:
    """Remove all but the newest `keep` gen-<n>/ directories (never the one `current` names) and
    build directories a crashed render left (the caller holds the theme lock)."""
    try:
        cur = os.readlink(paths.theme_current)
    except OSError:
        cur = ""
    gens = sorted((n, p) for p in paths.theme.iterdir() if (n := _gen_n(p.name)) is not None
                  and p.is_dir() and not p.is_symlink())
    doomed = [p for _, p in gens[:-keep] if p.name != cur] if keep > 0 else []
    doomed += [p for p in paths.theme.iterdir() if re.fullmatch(r"\.gen-\d+\.build", p.name)]
    for p in doomed:
        invariants.writable(paths, p, kind="state")
        shutil.rmtree(p)


def output(gen: Generation, f: FileOut) -> Path:
    """gen.path / f.out."""
    return gen.path / f.out
