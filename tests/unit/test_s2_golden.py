"""Golden files (08 §4): every template of theme/targets.toml rendered with two fixed inputs must
equal tests/golden/<variant>/<template>. A template change that is meant shows up as a diff of the
golden files; APTUS_BLESS=1 rewrites them (look at the diff before committing it)."""
from __future__ import annotations

import dataclasses
import json
import os
import tomllib
from pathlib import Path

import pytest

from aptus import paths as paths_mod
from aptus.theme import render, resolve, targets
from aptus.theme.inputs import Inputs

GOLDEN = Path(__file__).resolve().parents[1] / "golden"
VARIANTS = {
    "dark-jade": Inputs(mode="dark", accent="jade", contrast="normal", glass=False),
    "light-sky-high-glass": Inputs(mode="light", accent="sky", contrast="high", glass=True,
                                   frame_edge=0, reduce_motion=True),
}


def fixed_paths(p: paths_mod.Paths) -> paths_mod.Paths:
    """The XDG bases as on a normal machine, so the golden files do not name a temporary dir."""
    home = Path("/home/user")
    return dataclasses.replace(p, home=home, config_home=home / ".config",
                               state_home=home / ".local/state", cache_home=home / ".cache",
                               data_home=home / ".local/share")


def rendered(variant: str) -> dict[str, str]:
    p = fixed_paths(paths_mod.get())
    tokens = resolve.load_tokens(p)
    inp = VARIANTS[variant]
    ctx = render.context(resolve.resolve(tokens, inp),
                         resolve.resolve(tokens, dataclasses.replace(inp, mode="dark")),
                         resolve.resolve(tokens, dataclasses.replace(inp, mode="light")),
                         tokens, inp, 1, p)
    manifest = targets.load(p.targets, p.templates)
    out = {}
    for t in manifest.targets:
        for f in t.files:
            out[f.template] = render.render_text((p.templates / f.template).read_text(), ctx)
        if t.dconf:
            out[f"{t.id}/dconf.json"] = json.dumps(
                {k: render.render_text(v, ctx) if v else None for k, v in t.dconf},
                indent=2, sort_keys=True) + "\n"
    return out


@pytest.mark.parametrize("variant", sorted(VARIANTS))
def test_golden(variant: str) -> None:
    got = rendered(variant)
    root = GOLDEN / variant
    if os.environ.get("APTUS_BLESS") == "1":
        for name, text in got.items():
            (root / name).parent.mkdir(parents=True, exist_ok=True)
            (root / name).write_text(text)
    want = {str(f.relative_to(root)): f.read_text() for f in root.rglob("*") if f.is_file()}
    assert sorted(want) == sorted(got), "templates and golden files differ in names"
    for name in sorted(got):
        assert got[name] == want[name], f"{variant}/{name} differs from its golden file"


def test_golden_files_parse() -> None:
    """What has a parser parses: JSON and TOML outputs of both variants."""
    for variant in VARIANTS:
        for name, text in rendered(variant).items():
            if name.endswith(".json"):
                json.loads(text)
            elif name.endswith(".toml"):
                tomllib.loads(text)
