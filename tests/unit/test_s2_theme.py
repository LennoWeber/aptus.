"""The theme renderer (08 §2–§8): inputs, the manifest, Noctalia's enabled templates, the template
language, generations, scope mirrors, Own files, reload hooks and apply. Everything in the
temporary HOME; tools are fakes in $HOME/.aptus-test/bin."""
from __future__ import annotations

import dataclasses
import json
import os
import socket
import threading
from pathlib import Path

import pytest

import s2_fakes as fakes
from aptus import paths as paths_mod
from aptus.lease import invariants
from aptus.theme import apply, hooks, inputs, noctalia, own, render, scope, targets
from aptus.theme.inputs import Inputs
from aptus.theme.targets import FileOut, Manifest, ManifestError, Mechanism, ScopeSpec, Target

DARK = Inputs(mode="dark", accent="jade", contrast="normal", glass=False)
LIGHT = Inputs(mode="light", accent="sky", contrast="normal", glass=True)


@pytest.fixture
def p(test_home: Path, monkeypatch: pytest.MonkeyPatch) -> paths_mod.Paths:
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(test_home / "r"))
    (test_home / "r").mkdir()
    return paths_mod.get()


@pytest.fixture
def manifest(p) -> Manifest:
    return targets.load(p.targets, p.templates)


def write_manifest(tmp: Path, text: str, templates: dict[str, str] | None = None) -> Path:
    (tmp / "templates").mkdir(parents=True, exist_ok=True)
    for name, body in (templates or {"a/t": "x"}).items():
        (tmp / "templates" / name).parent.mkdir(parents=True, exist_ok=True)
        (tmp / "templates" / name).write_text(body)
    (tmp / "targets.toml").write_text(text)
    return tmp / "targets.toml"


# --- inputs ----------------------------------------------------------------------------------

def test_inputs_from_settings_defaults_and_values(p) -> None:
    assert inputs.from_settings(p) == Inputs(mode="dark", accent="jade", contrast="normal",
                                             glass=False, mode_setting="dark")
    p.config.mkdir(parents=True)
    p.settings.write_text(json.dumps({"v": 2, "appearance.mode": "light", "appearance.accent": "sky",
                                      "appearance.glass": True, "frame.edge": 0,
                                      "motion.reduce": "on", "isolation.bakeTargets": ["spicetify"],
                                      "appearance.contrast": "loud"}))
    got = inputs.from_settings(p)
    assert (got.mode, got.accent, got.glass, got.frame_edge, got.reduce_motion) == ("light", "sky", True, 0, True)
    assert got.contrast == "normal"                 # outside the enum: the default
    assert got.bake_targets == ("spicetify",)
    p.settings.write_text(json.dumps({"appearance.mode": "light"}))     # v1: no "v" → defaults
    assert inputs.from_settings(p).mode == "dark"


def test_inputs_reduce_motion_auto_follows_gnome(p) -> None:
    """Wave-2 review 5: motion.reduce `auto` (the default) is reduced when GNOME's
    enable-animations is false, as the shell's Motion.reduced counts it; `off` never is."""
    assert not inputs.from_settings(p).reduce_motion             # no gsettings: not reduced
    fakes.tool(p.home, "gsettings", "out.append(state.get('v', 'true') + '\\n')\n")
    assert not inputs.from_settings(p).reduce_motion             # animations on
    (p.home / ".aptus-test/gsettings.json").write_text(json.dumps({"v": "false"}))
    assert inputs.from_settings(p).reduce_motion                 # auto + animations off
    assert ["gsettings", "get", "org.gnome.desktop.interface", "enable-animations"] in fakes.calls(p.home)
    p.config.mkdir(parents=True)
    p.settings.write_text(json.dumps({"v": 2, "motion.reduce": "off"}))
    assert not inputs.from_settings(p).reduce_motion


def test_inputs_auto_resolves_and_keeps_wallpaper(p, manifest) -> None:
    from datetime import datetime
    p.config.mkdir(parents=True)
    p.settings.write_text(json.dumps({"v": 2, "appearance.mode": "auto"}))
    noon, night = datetime(2026, 6, 21, 12, 0), datetime(2026, 6, 21, 23, 30)
    assert inputs.from_settings(p, noon).mode == "light"
    assert inputs.from_settings(p, night).mode == "dark"
    assert inputs.from_settings(p, noon).mode_setting == "auto"
    render.render(p, dataclasses.replace(DARK, wallpaper_hue=200.0, wallpaper_chroma=0.1,
                                         wallpaper_lightness=0.3), manifest)
    got = inputs.from_settings(p, night)
    assert (got.wallpaper_hue, got.wallpaper_chroma, got.wallpaper_lightness) == (200.0, 0.1, 0.3)


def test_inputs_json_round_trip_and_errors() -> None:
    full = Inputs(mode="light", accent="wallpaper", contrast="high", glass=True, mode_setting="auto",
                  wallpaper_hue=12.5, wallpaper_chroma=0.2, wallpaper_lightness=0.7,
                  current_accent="sky", frame_edge=0, reduce_motion=True, bake_targets=("spicetify",))
    assert inputs.from_json(json.dumps(inputs.to_dict(full))) == full
    for bad, why in (('[]', "object"), ('{"mode": "dark"}', "without accent"),
                     ('{"mode": "auto", "accent": "jade", "contrast": "normal", "glass": true}', "auto"),
                     ('{"mode": "dark", "accent": "jade", "contrast": "normal", "glass": "yes"}', "wrong type"),
                     ('{"mode": "dark", "accent": "jade", "contrast": "normal", "glass": true, "x": 1}', "unknown"),
                     ('{"mode": "dark", "accent": "jade", "contrast": "normal", "glass": true, "frameEdge": true}', "boolean"),
                     ('{"mode": "dark", "accent": "jade", "contrast": "normal", "glass": true, "wallpaperHue": NaN}', "finite")):
        with pytest.raises(ValueError, match=why):
            inputs.from_json(bad)


# --- the manifest -----------------------------------------------------------------------------

def test_real_manifest_loads(manifest) -> None:
    ids = [t.id for t in manifest.targets]
    assert len(ids) == len(set(ids)) >= 30
    rows = {t.row for t in manifest.targets}
    assert {1, 2, 3, 4, 6, 14, 28, 33, 35} <= rows
    vesktop = next(t for t in manifest.targets if t.id == "vesktop")
    assert len(vesktop.files) == 6 and vesktop.present
    dconf = next(t for t in manifest.targets if t.id == "dconf")
    assert dict(dconf.dconf)["gtk-theme"] == "" and dict(dconf.requires) == {"icon-theme": "icons"}
    assert next(t for t in manifest.targets if t.id == "kitty").scope == ScopeSpec(
        into="kitty", mirror="{config}/kitty")


@pytest.mark.parametrize("text, why", [
    ('[[target]]\nid = "a"\nmechanism = "lease"\ntemplate = "a/t"\nout = "a/t"\nslot = "~/x"\nbogus = 1\n', "unknown keys"),
    ('[[target]]\nid = "a"\nmechanism = "lend"\n', "unknown mechanism"),
    ('[[target]]\nid = "a"\nmechanism = "lease"\ntemplate = "a/none"\nout = "a/t"\nslot = "~/x"\n', "does not exist"),
    ('[[target]]\nid = "a"\nmechanism = "lease"\ntemplate = "a/t"\nout = "a/t"\nslot = "~/x"\nreload = "shout:x"\n', "unknown reload"),
    ('[[target]]\nid = "a"\nmechanism = "lease"\ntemplate = "a/t"\nout = "a/t"\nslot = "~/x"\nreload = "signal:kitty:SIGNOPE"\n', "signal"),
    ('[[target]]\nid = "a"\nmechanism = "lease"\ntemplate = "a/t"\nout = "a/t"\n', "needs a slot"),
    ('[[target]]\nid = "a"\nmechanism = "scope"\ntemplate = "a/t"\nout = "a/t"\nscope = { into = "../x", mirror = "~/x" }\n', "plain name"),
    ('[[target]]\nid = "a"\nmechanism = "own"\ntemplate = "a/t"\nout = "a/t"\n', "needs a dest"),
    ('[[target]]\nid = "a"\nmechanism = "lease"\ntemplate = "a/t"\nout = "../t"\nslot = "~/x"\n', "inside the generation"),
    ('[[target]]\nid = "a"\nmechanism = "never"\n[[target]]\nid = "a"\nmechanism = "never"\n', "duplicate"),
    ('[[target]]\nid = "a"\nmechanism = "lease"\nkind = "ini-sections"\ntemplate = "a/t"\nout = "a/t"\nslot = "~/x"\n', "without sections"),
    ('[[target]]\nid = "a"\nmechanism = "bake"\ntemplate = "a/t"\nout = "a/t"\nslot = "~/x"\n', "bake:"),
    ('[[target]]\nid = "a"\nmechanism = "never"\nwhen = "sometimes"\n', "when"),
    ('[[target]]\nid = "a"\nmechanism = "lease"\nfiles = [{ template = "a/t", out = "a/t", slot = "~/x" }, '
     '{ template = "a/t", out = "a/u", slot = "~/y" }]\n', "share a name"),
])
def test_bad_manifest_refused(tmp_path, text, why) -> None:
    with pytest.raises(ManifestError, match=why):
        targets.load(write_manifest(tmp_path, text))


def test_expand(p) -> None:
    assert targets.expand(p, "~/.config/x") == p.home / ".config/x"
    assert targets.expand(p, "{config}/kitty") == p.config_home / "kitty"
    assert targets.expand(p, "{state}/aptus/hypr/generated.lua") == p.generated_lua
    assert targets.expand(p, "/usr/share/icons/Papirus", system=True) == p.sysroot / "usr/share/icons/Papirus"
    for bad, why in (("~/../elsewhere", "leaves HOME"), ("/usr/share/x", "starts with"),
                     ("~/.config/umbriel/x", "inside"), ("{state}/noctalia/settings.toml", "inside"),
                     ("relative/x", "starts with")):
        with pytest.raises(ManifestError, match=why):
            targets.expand(p, bad)


def test_active_and_slots(p, manifest) -> None:
    by = {t.id: t for t in manifest.targets}
    assert not targets.active(p, by["gtk3"])
    (p.config_home / "gtk-3.0").mkdir(parents=True)
    assert targets.active(p, by["gtk3"])
    assert targets.active(p, by["hyprland"])                           # always
    assert not targets.active(p, by["qt6ct"])
    fakes.tool(p.home, "qt6ct", "pass\n")
    assert targets.active(p, by["qt6ct"])                              # which: the fake only
    assert targets.slots(p, by["vesktop"]) == []                       # present: none exists
    vs = p.config_home / "vesktop/themes/noctalia.theme.css"
    vs.parent.mkdir(parents=True)
    vs.write_text("x")
    assert [s for _, s in targets.slots(p, by["vesktop"])] == [vs]
    for ver in ("1.0.0", "1.1.0"):
        d = p.home / f".vscode/extensions/noctalia.noctaliatheme-{ver}/themes"
        d.mkdir(parents=True)
        (d / "NoctaliaTheme-color-theme.json").write_text("{}")
    found = targets.slots(p, by["vscode"])
    assert [s.parts[-3] for _, s in found] == ["noctalia.noctaliatheme-1.0.0", "noctalia.noctaliatheme-1.1.0"]
    ids = {targets.slot_id(by["vscode"], f, s) for f, s in found}
    assert len(ids) == 2 and all(i.startswith("vscode.code.") for i in ids)


# --- Noctalia's enabled templates (read only) -------------------------------------------------

def noctalia_config(p, overlay: str = "", settings: str = "") -> None:
    p.noctalia_config.mkdir(parents=True, exist_ok=True)
    (p.noctalia_config / "a.toml").write_text(
        '[theme.templates]\nbuiltin_ids = ["gtk3", "kitty", "niri"]\ncommunity_ids = ["yazi"]\n'
        '[theme.templates.user.mine]\noutput_path = "~/.config/gtk-3.0/noctalia.css"\n'
        '[theme.templates.user.off]\nenabled = false\noutput_path = "~/x"\n' + overlay)
    if settings:
        p.noctalia_settings.parent.mkdir(parents=True, exist_ok=True)
        p.noctalia_settings.write_text(settings)


def test_noctalia_enabled_overlays(p) -> None:
    noctalia_config(p, settings='[theme.templates]\nbuiltin_ids = ["gtk3", "weird"]\n')
    before = {f: f.read_bytes() for f in p.home.rglob("*.toml")}
    e = noctalia.enabled(p)
    assert e.builtin == ["gtk3", "weird"]                    # the state file is the last overlay
    assert e.community == ["yazi"]
    assert e.user == {"mine": str(p.config_home / "gtk-3.0/noctalia.css")}
    assert len(e.sources) == 2 and not e.error
    assert {f: f.read_bytes() for f in p.home.rglob("*.toml")} == before     # never writes
    (p.noctalia_config / "b.toml").write_text("[theme.templates]\nenable_community_templates = false\n")
    p.noctalia_settings.unlink()
    assert noctalia.enabled(p).community == []
    (p.noctalia_config / "b.toml").write_text("not = [toml")
    assert "b.toml" in noctalia.enabled(p).error


def test_coverage(p, manifest) -> None:
    noctalia_config(p, settings='[theme.templates]\nbuiltin_ids = ["gtk3", "fastfetch", "niri", "mystery"]\n')
    slot_paths = {s: t.id for t in manifest.targets for _, s in targets.slots(p, t)}
    cov = targets.coverage(manifest, noctalia.enabled(p), slot_paths)
    assert cov.covered == {"gtk3": "gtk3", "yazi": "yazi", "mine": "gtk3"}
    assert cov.kept == {"fastfetch": "fastfetch"}
    assert set(cov.inert) == {"niri"}
    assert cov.uncovered == ["mystery"]


NOCTALIA_BUILTIN = Path("/usr/share/noctalia/assets/templates/builtin.toml")
UNCOVERED = ["emacs", "helix", "wezterm"]     # reported by coverage; not installed here


@pytest.mark.skipif(not NOCTALIA_BUILTIN.is_file(), reason="Noctalia is not installed")
def test_every_installed_noctalia_template_is_covered_or_reported(manifest) -> None:
    """Every built-in template of the installed Noctalia (a read-only system file) is covered,
    kept, inert or in the reported list: a new Noctalia template shows up here."""
    import tomllib
    ids = sorted(tomllib.loads(NOCTALIA_BUILTIN.read_text())["catalog"])
    cov = targets.coverage(manifest, noctalia.Enabled(builtin=ids), {})
    assert cov.uncovered == UNCOVERED


# --- the template language --------------------------------------------------------------------

@pytest.mark.parametrize("filt, arg, out", [
    ("hex", None, "#1f5f86"), ("hexnoh", None, "1f5f86"), ("rgb", None, "31, 95, 134"),
    ("csv", None, "31,95,134"), ("int", None, str(0x1f5f86)), ("rgba", "0.5", "rgba(31, 95, 134, 0.5)"),
    ("rgba", "1", "rgba(31, 95, 134, 1)"), ("hyprrgba", "shadowAlpha", "rgba(1f5f8680)"),
    ("argb", "0.5", "#801f5f86"), ("hsl", None, "hsl(203, 62%, 32%)"), ("hue", None, "203"),
    ("saturation", None, "62"), ("lightness", None, "32"),
])
def test_filters(filt, arg, out) -> None:
    assert render.apply_filter("#1f5f86", filt, arg, {"shadowAlpha": "0.5"}) == out


@pytest.mark.parametrize("value, filt, arg, why", [
    ("#1f5f86", "bogus", None, "unknown filter"), ("#1f5f86", "rgba", None, "needs an alpha"),
    ("#1f5f86", "hex", "1", "takes no argument"), ("#1f5f86", "rgba", "1.5", "outside"),
    ("#1f5f86", "rgba", "nope", "not a number"), ("0.5", "hex", None, "not a colour"),
])
def test_filter_errors(value, filt, arg, why) -> None:
    with pytest.raises(render.TemplateError, match=why):
        render.apply_filter(value, filt, arg, {})


def test_render_text() -> None:
    ctx = {"accent": "#1f5f86", "mode": "dark", "font.ui": "Inter"}
    assert render.render_text("a {{accent}} {{ mode }} {{ accent | hexnoh }} {{font.ui}}", ctx) == \
        "a #1f5f86 dark 1f5f86 Inter"
    with pytest.raises(render.TemplateError, match="unknown name 'nope' on line 2"):
        render.render_text("x\n{{ nope }}", ctx)
    with pytest.raises(render.TemplateError, match="malformed placeholder on line 3"):
        render.render_text("x\n{{ mode }}\n{{ mode | }", ctx)
    assert render.render_text("{{ mode }}", {"mode": "{{ x }}"}) == "{{ x }}"   # values are not re-read


def test_context_covers_every_template(p, manifest) -> None:
    from aptus.theme import resolve
    tokens = resolve.load_tokens(p)
    for inp in (DARK, LIGHT, dataclasses.replace(DARK, contrast="high", accent="rose")):
        res = resolve.resolve(tokens, inp)
        ctx = render.context(res, resolve.resolve(tokens, dataclasses.replace(inp, mode="dark")),
                             resolve.resolve(tokens, dataclasses.replace(inp, mode="light")),
                             tokens, inp, 7, p)
        assert ctx["font.uiApp.family"] == "Inter" and ctx["font.uiApp.size"] == "11"
        assert ctx["glass"] in ("true", "false") and ctx["generation"] == "7"
        for t in manifest.targets:
            for f in t.files:
                render.render_text((p.templates / f.template).read_text(), ctx)
            for _, tpl in t.dconf:
                render.render_text(tpl, ctx)


# --- generations --------------------------------------------------------------------------------

def test_render_generation_and_reuse(p, manifest) -> None:
    g1 = render.render(p, DARK, manifest)
    assert g1.n == 1 and not g1.reused and not g1.failed
    assert os.readlink(p.theme_current) == "gen-1"
    assert (g1.path / "kitty/noctalia.conf").is_file()
    assert json.loads((g1.path / "dconf/dconf.json").read_text())["color-scheme"] == "'prefer-dark'"
    assert json.loads((g1.path / "dconf/dconf.json").read_text())["gtk-theme"] is None
    assert json.loads(p.theme_resolved.read_text())["mode"] == "dark"
    assert render.current(p).inputs == DARK
    again = render.render(p, DARK, manifest)
    assert again.reused and again.n == 1
    g2 = render.render(p, LIGHT, manifest)
    assert g2.n == 2 and json.loads(p.theme_resolved.read_text())["mode"] == "light"
    for inp in (DARK, LIGHT, DARK):
        render.render(p, dataclasses.replace(inp, frame_edge=0 if inp is DARK else 6), manifest)
    gens = sorted(x.name for x in p.theme.iterdir() if x.name.startswith("gen-"))
    assert gens == ["gen-3", "gen-4", "gen-5"]                       # three kept


def test_failed_target_keeps_previous_output(p, tmp_path, manifest) -> None:
    g1 = render.render(p, DARK, manifest)
    t = next(t for t in manifest.targets if t.id == "ghostty")
    broken = tmp_path / "templates"
    shutil_copy_tree(p.templates, broken)
    (broken / "ghostty/noctalia").write_text("{{ nope }}\n")
    p2 = dataclasses.replace(p, templates=broken)
    g2 = render.render(p2, LIGHT, manifest)
    assert "ghostty" in g2.failed and "unknown name" in g2.failed["ghostty"]
    assert (g2.path / t.files[0].out).read_bytes() == (g1.path / t.files[0].out).read_bytes()
    assert (g2.path / "kitty/noctalia.conf").read_bytes() != (g1.path / "kitty/noctalia.conf").read_bytes()


def shutil_copy_tree(src: Path, dst: Path) -> None:
    import shutil
    shutil.copytree(src, dst)


def test_render_lock_reentrant_and_exclusive(p) -> None:
    with render.lock(p):
        with render.lock(p):
            pass
        result = []

        def other() -> None:
            try:
                with render.lock(p, timeout=0.2):
                    result.append("got it")
            except RuntimeError as e:
                result.append(str(e))
        th = threading.Thread(target=other)
        th.start()
        th.join()
        assert "busy" in result[0]


def test_render_refuses_unsafe_home(p, manifest) -> None:
    # a HOME outside the temporary directory (one that cannot be written, should the check fail)
    with pytest.raises(paths_mod.UnsafeHome):
        render.render(dataclasses.replace(p, home=Path("/nonexistent/aptus-home")), DARK, manifest)


# --- scope ---------------------------------------------------------------------------------------

def kitty_config(p) -> Path:
    k = p.config_home / "kitty"
    (k / "themes").mkdir(parents=True)
    (k / "kitty.conf").write_text("include themes/noctalia.conf\n")
    (k / "themes/noctalia.conf").write_text("# noctalia\n")
    (k / "themes/other.conf").write_text("# other\n")
    return k


def test_scope_mirror(p, manifest) -> None:
    k = kitty_config(p)
    gen = render.render(p, DARK, manifest)
    t = next(t for t in manifest.targets if t.id == "kitty")
    before = {f: f.read_bytes() for f in k.rglob("*") if f.is_file()}
    scope.apply(p, t, gen)
    entry = p.scope / "kitty"
    assert entry.is_symlink()
    assert os.readlink(entry / "kitty.conf") == str(k / "kitty.conf")
    assert os.readlink(entry / "themes/other.conf") == str(k / "themes/other.conf")
    assert not (entry / "themes/noctalia.conf").is_symlink()
    assert (entry / "themes/noctalia.conf").read_bytes() == (gen.path / "kitty/noctalia.conf").read_bytes()
    assert {f: f.read_bytes() for f in k.rglob("*") if f.is_file()} == before     # source untouched
    first = os.readlink(entry)
    gen2 = render.render(p, LIGHT, manifest)
    scope.apply(p, t, gen2)
    assert os.readlink(entry) != first and not (p.scope / first).exists()       # old build removed


def test_scope_missing_only(p, tmp_path) -> None:
    src = tmp_path / "yazi"
    src.mkdir()
    (src / "theme.toml").write_text("mine")
    rendered = tmp_path / "r"
    rendered.write_text("aptus")
    build = tmp_path / "build"
    build.mkdir()
    files = [(FileOut(template="t", out="o", at="theme.toml", missing_only=True), rendered),
             (FileOut(template="t", out="o", at="flavors/n.yazi/flavor.toml"), rendered)]
    scope.mirror(src, build, files)
    assert os.readlink(build / "theme.toml") == str(src / "theme.toml")
    assert (build / "flavors/n.yazi/flavor.toml").read_text() == "aptus"
    (src / "theme.toml").unlink()
    build2 = tmp_path / "build2"
    build2.mkdir()
    scope.mirror(src, build2, files)
    assert (build2 / "theme.toml").read_text() == "aptus"


def test_scope_marked(tmp_path) -> None:
    src = tmp_path / "starship.toml"
    src.write_text("format = 'x'\n# >>> B >>>\nold\n# <<< E <<<\ntail = 1\n")
    assert scope.marked(src, "# >>> B >>>", "# <<< E <<<", "new\n") == \
        "format = 'x'\n# >>> B >>>\nnew\n# <<< E <<<\ntail = 1\n"
    src.write_text("format = 'x'")
    assert scope.marked(src, "# >>> B >>>", "# <<< E <<<", "new") == \
        "format = 'x'\n\n# >>> B >>>\nnew\n# <<< E <<<\n"
    assert scope.marked(tmp_path / "none", "B", "E", "new") == "B\nnew\nE\n"


def test_scope_swap_moves_a_real_dir_aside(p) -> None:
    (p.scope / "kitty").mkdir(parents=True)
    (p.scope / "kitty/old.conf").write_text("from an old install")
    build = p.scope / ".kitty.1.1"
    build.mkdir()
    scope.swap(p, "kitty", build)
    assert os.readlink(p.scope / "kitty") == ".kitty.1.1"
    (aside,) = [x for x in p.scope.iterdir() if x.name.startswith(".kitty.old-")]
    assert (aside / "old.conf").read_text() == "from an old install"
    with pytest.raises(invariants.InvariantError):
        scope.swap(p, "../x", build)


def test_scope_starship(p, manifest) -> None:
    (p.config_home).mkdir(parents=True)
    (p.config_home / "starship.toml").write_text(
        "format = '$all'\n# >>> NOCTALIA STARSHIP PALETTE >>>\nold\n# <<< NOCTALIA STARSHIP PALETTE <<<\n")
    gen = render.render(p, DARK, manifest)
    scope.apply(p, next(t for t in manifest.targets if t.id == "starship"), gen)
    text = (p.scope / "starship.toml").read_text()
    assert text.startswith("format = '$all'\n") and "old" not in text and "[palettes.noctalia]" in text
    import tomllib
    tomllib.loads(text)


# --- Own -------------------------------------------------------------------------------------------

def test_own_files_and_foreign_file(p, manifest) -> None:
    gen = render.render(p, DARK, manifest)
    hl = next(t for t in manifest.targets if t.id == "hyprland")
    own.apply(p, hl, gen)
    assert "accent = \"rgb(" in p.generated_lua.read_text()
    qt = next(t for t in manifest.targets if t.id == "qt6ct")
    p.qt6ct_conf.parent.mkdir(parents=True)
    p.qt6ct_conf.write_text("Lenno's own")
    with pytest.raises(own.OwnError, match="is not aptus's"):
        own.apply(p, qt, gen)
    assert p.qt6ct_conf.read_text() == "Lenno's own"
    assert p.qt6ct_colors.is_file()                              # the other file is written
    assert p.qt6ct_colors in own.recorded(p) and p.qt6ct_conf not in own.recorded(p)
    p.qt6ct_conf.unlink()
    own.apply(p, qt, gen)
    assert p.qt6ct_conf in own.recorded(p)


def papirus(p) -> None:
    for size in own.ICON_SIZES:
        d = p.papirus / size / "places"
        d.mkdir(parents=True)
        for colour in ("teal", "blue"):
            for name in ("", "-documents", "-download"):
                (d / f"folder-{colour}{name}.svg").write_text(f"<svg>{colour}</svg>")
        (d / "folder-tealish.svg").write_text("not teal")


def test_own_icons(p) -> None:
    papirus(p)
    built = own.icons(p, "teal")
    assert [d.name for d in built] == list(own.ICON_THEMES)
    dark = p.icons / "aptus-icons-dark"
    idx = (dark / "index.theme").read_text()
    assert "Inherits=Papirus-Dark,hicolor" in idx and "X-Aptus-Folder=teal" in idx
    places = dark / "48x48/places"
    assert sorted(x.name for x in places.iterdir()) == ["folder-documents.svg", "folder-download.svg", "folder.svg"]
    assert os.readlink(places / "folder.svg") == str(p.papirus / "48x48/places/folder-teal.svg")
    assert own.icons(p, "teal") == []                            # same folder: nothing rebuilt
    own.icons(p, "blue")
    assert os.readlink(places / "folder.svg").endswith("folder-blue.svg")
    assert not (p.icons / "aptus-icons-dark.old").exists() and not (p.icons / "aptus-icons-dark.new").exists()
    assert set(own.ICON_THEMES) <= {x.name for x in own.recorded(p)}


def test_own_bat(p, manifest) -> None:
    gen = render.render(p, DARK, manifest)
    bat = next(t for t in manifest.targets if t.id == "bat")
    with pytest.raises(own.OwnError, match="not installed"):
        own.apply(p, bat, gen)
    fakes.tool(p.home, "bat", "pass\n")
    own.apply(p, bat, gen)
    assert (p.bat_source / "themes/aptus.tmTheme").is_file()
    assert fakes.calls(p.home, "bat")[-1][1:] == ["cache", "--build", "--source", str(p.bat_source),
                                                   "--target", str(p.cache_bat)]


# --- hooks ----------------------------------------------------------------------------------------

def test_hook_parse() -> None:
    assert hooks.parse("none") == hooks.Hook("none")
    assert hooks.parse("signal:kitty:SIGUSR1") == hooks.Hook("signal", comm="kitty", signal="SIGUSR1")
    assert hooks.parse("exec:pywalfox update") == hooks.Hook("exec", command="pywalfox update")
    assert hooks.parse("bake:spotify:spicetify apply") == hooks.Hook("bake", comm="spotify", command="spicetify apply")
    for bad in ("builtin:emacs", "signal:kitty", "exec:", "bake:spotify", "none:x", "whatever"):
        with pytest.raises(ValueError):
            hooks.parse(bad)


def unix_socket(path: Path) -> socket.socket:
    path.parent.mkdir(parents=True, exist_ok=True)
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.bind(str(path))
    return s


def test_hooks_without_session_and_tools(p) -> None:
    got = {r.target: r.state for r in hooks.run_reloads(
        p, {"kitty": "signal:kitty:SIGUSR1", "kde": "builtin:kde", "pywalfox": "exec:pywalfox update",
            "hyprland": "builtin:hyprland", "gtk3": "none"}, "")}
    assert got == {"kitty": "next-start", "kde": "next-start", "pywalfox": "next-start",
                   "hyprland": "next-start"}


def test_hooks_tools(p) -> None:
    for name in ("dbus-send", "pywalfox", "tmux", "nvim"):
        fakes.tool(p.home, name, "pass\n")
    (p.config_home / "tmux").mkdir(parents=True)
    (p.config_home / "tmux/tmux.conf").write_text("set -g x 1\n")
    p.tmux_sockets.mkdir(mode=0o700, parents=True)                 # as tmux makes it
    socks = [unix_socket(p.tmux_sockets / "default"), unix_socket(p.nvim_sockets / "nvim.123.0")]
    try:
        got = {r.target: r.state for r in hooks.run_reloads(
            p, {"kde": "builtin:kde", "pywalfox": "exec:pywalfox update", "tmux": "builtin:tmux",
                "nvim": "builtin:nvim"}, "")}
    finally:
        for s in socks:
            s.close()
    assert got == {"kde": "applied", "pywalfox": "applied", "tmux": "applied", "nvim": "applied"}
    calls = {c[0]: c[1:] for c in fakes.calls(p.home)}
    assert calls["pywalfox"] == ["update"]
    assert calls["tmux"] == ["-S", str(p.tmux_sockets / "default"), "source-file",
                             str(p.config_home / "tmux/tmux.conf")]
    assert calls["nvim"] == ["--server", str(p.nvim_sockets / "nvim.123.0"), "--remote-send",
                             hooks.NVIM_KEYS]
    fakes.tool(p.home, "pywalfox", "code = 3\n")
    (r,) = hooks.run_reloads(p, {"pywalfox": "exec:pywalfox update"}, "")
    assert r.state == "failed" and "exited 3" in r.detail


def test_hook_tmux_only_in_a_private_socket_dir(p, tmp_path, monkeypatch) -> None:
    """Security review 11: tmux -S skips tmux's own check of the socket directory, so the hook
    makes it: a real directory of this uid with mode & 0o077 == 0, sockets of this uid that are
    not symlinks; otherwise nothing is run ("next-start")."""
    fakes.tool(p.home, "tmux", "pass\n")
    (p.config_home / "tmux").mkdir(parents=True)
    (p.config_home / "tmux/tmux.conf").write_text("set -g x 1\n")
    d = p.tmux_sockets
    assert hooks.builtin_tmux(p, "tmux", "").detail == "no tmux server running"    # no directory
    private = tmp_path / "private"
    private.mkdir(mode=0o700)
    socks = [unix_socket(private / "default")]
    try:
        d.parent.mkdir(parents=True, exist_ok=True)
        d.symlink_to(private)                                          # a symlinked directory
        assert hooks.builtin_tmux(p, "tmux", "").state == "next-start"
        d.unlink()
        d.mkdir(mode=0o755)                                            # others may enter
        socks.append(unix_socket(d / "default"))
        assert hooks.builtin_tmux(p, "tmux", "").state == "next-start"
        assert fakes.calls(p.home, "tmux") == []
        d.chmod(0o700)
        (d / "other").symlink_to(private / "default")                  # a symlinked socket
        (d / "file").write_text("")
        r = hooks.builtin_tmux(p, "tmux", "")
        assert (r.state, r.detail) == ("applied", "1 tmux server")
        assert [c[2] for c in fakes.calls(p.home, "tmux")] == [str(d / "default")]
        real_uid = os.getuid()
        monkeypatch.setattr(hooks.os, "getuid", lambda: real_uid + 1)  # another uid's directory
        assert hooks.tmux_sockets(p) is None
        assert hooks.builtin_tmux(p, "tmux", "").state == "next-start"
    finally:
        for s in socks:
            s.close()


def test_hook_hyprland_eval(p, fake_hypr) -> None:
    p.generated_lua.parent.mkdir(parents=True)
    p.generated_lua.write_text("return {}")
    seen = fake_hypr([b"ok"], sig="nested")
    (r,) = hooks.run_reloads(paths_mod.get(), {"hyprland": "builtin:hyprland"}, "nested")
    assert r.state == "applied"
    assert seen[0].startswith(b"eval local g = dofile(") and b"active_border = g.accent" in seen[0]
    (r,) = hooks.run_reloads(p, {"hyprland": "builtin:hyprland"},
                             os.environ["APTUS_REAL_HYPRLAND_SIGNATURE"])
    assert r.state == "failed" and "RefusedInstance" in r.detail


def test_hook_signal_reaches_only_this_session(p, tmp_path) -> None:
    h = fakes.hyprland(p.home, tmp_path, "nested-sig")
    try:
        exe = tmp_path / "fakebin/kitty"
        import shutil
        import subprocess
        shutil.copy(shutil.which("sleep"), exe)
        mine = subprocess.Popen([str(exe), "600"], env={"HOME": str(p.home), "HYPRLAND_INSTANCE_SIGNATURE": "nested-sig"})
        other = subprocess.Popen([str(exe), "600"], env={"HOME": str(p.home), "HYPRLAND_INSTANCE_SIGNATURE": "else"})
        try:
            (r,) = hooks.run_reloads(p, {"kitty": "signal:kitty:SIGTERM"}, "nested-sig")
            assert r.state == "applied"
            assert mine.wait(5) == -15 and other.poll() is None
        finally:
            other.kill()
            mine.kill()
    finally:
        h.kill()


def test_bake_queued_while_app_runs(p, tmp_path) -> None:
    import shutil
    import subprocess
    fakes.tool(p.home, "spicetify", "pass\n")
    exe = tmp_path / "fakebin/spotify"
    exe.parent.mkdir(parents=True)
    shutil.copy(shutil.which("sleep"), exe)
    app = subprocess.Popen([str(exe), "600"], env={"HOME": str(p.home)})
    try:
        (r,) = hooks.run_reloads(p, {"spicetify": "bake:spotify:spicetify apply"}, "")
        assert r.state == "queued"
        assert hooks.load_queue(p) == {"spicetify": "bake:spotify:spicetify apply"}
        assert hooks.retry_queued(p) == []                     # still running
    finally:
        app.kill()
        app.wait(5)
    (r,) = hooks.retry_queued(p)
    assert r.state == "applied" and hooks.load_queue(p) == {} and not p.bake_queue.exists()
    assert fakes.calls(p.home, "spicetify")[-1][1:] == ["apply"]


# --- apply -----------------------------------------------------------------------------------------

def test_apply_scope_only(p, manifest) -> None:
    kitty_config(p)
    (p.config_home / "gtk-3.0").mkdir(parents=True)
    report = apply.apply(p, DARK, "")
    assert report.mode == "scope-only" and report.generation == 1 and not report.failed
    assert "gtk3" in report.stays_noctalia and "fastfetch" in report.stays_noctalia
    assert "spicetify" in report.stays_noctalia                     # bake not opted in
    assert "kitty" in report.next_start and "hyprland" in report.next_start
    assert "alacritty" in report.not_installed
    assert not (p.config_home / "gtk-3.0/noctalia.css").exists()    # leased: never touched
    assert (p.scope / "kitty/themes/noctalia.conf").is_file()
    again = apply.apply(p, DARK, "")
    assert again.unchanged and again.generation == 1
    d = json.loads(apply.report_json(report))
    assert "next-start" in d and "next_start" not in d


def test_slot_specs(p, manifest) -> None:
    for d in ("gtk-3.0", "kitty"):
        (p.config_home / d).mkdir(parents=True)
    gen = render.render(p, dataclasses.replace(DARK, bake_targets=("spicetify",)), manifest)
    specs = {s.id: s for s in apply.slot_specs(p, manifest, gen)}
    assert specs["gtk3.artifact"].content == (gen.path / "gtk3/noctalia.css").read_bytes()
    assert specs["gtk3.artifact"].create
    assert specs["dconf.color-scheme"].value == "'prefer-dark'"
    assert specs["dconf.gtk-theme"].value is None
    assert specs["dconf.icon-theme"].value is None                  # icons target not active
    assert specs["cursor.cursor-size"].value == "24"
    assert not any(s.startswith("kitty.") for s in specs)           # scope, not leased
    assert not any(s.startswith("spicetify.") for s in specs)       # opted in, but no slot present
    papirus(p)
    specs = {s.id: s for s in apply.slot_specs(p, manifest, gen)}
    assert specs["dconf.icon-theme"].value == "'aptus-icons-dark'"


# --- the phase-7 review fixes ------------------------------------------------------------------

def test_a_reused_generation_remembers_its_failed_targets(p, tmp_path, manifest) -> None:
    """A target that failed with no earlier output has no file in the generation: the next
    session start (same inputs, the generation is reused) leaves it out instead of failing the
    whole take."""
    (p.config_home / "ghostty").mkdir(parents=True)
    broken = tmp_path / "templates"
    shutil_copy_tree(p.templates, broken)
    (broken / "ghostty/noctalia").write_text("{{ nope }}\n")
    p2 = dataclasses.replace(p, templates=broken)
    g1 = render.render(p2, DARK, manifest)
    assert "ghostty" in g1.failed
    again = render.render(p2, DARK, manifest)
    assert again.reused and "ghostty" in again.failed
    assert "ghostty" in render.current(p2).failed
    ids = {s.id for s in apply.slot_specs(p2, manifest, again)}
    assert "ghostty.artifact" not in ids and "dconf.color-scheme" in ids
    lost = dataclasses.replace(again, failed={})            # an older generation without failed.json
    assert "ghostty.artifact" not in {s.id for s in apply.slot_specs(p2, manifest, lost)}


def test_target_ids_are_path_components(tmp_path) -> None:
    with pytest.raises(ManifestError, match="lowercase"):
        targets.load(write_manifest(tmp_path, '[[target]]\nid = "../a"\nmechanism = "never"\n'))


def test_bake_retry_skips_a_busy_theme_lock(p) -> None:
    import time
    fakes.tool(p.home, "spicetify", "pass\n")
    hooks.update_queue(p, add={"spicetify": "bake:spotify:spicetify apply"})
    held, done = threading.Event(), threading.Event()

    def hold() -> None:
        with render.lock(p):
            held.set()
            done.wait(10)
    th = threading.Thread(target=hold)
    th.start()
    try:
        held.wait(5)
        t0 = time.monotonic()
        assert hooks.retry_queued(p) == []
        assert time.monotonic() - t0 < 1                     # the guard never waits for it
        assert hooks.load_queue(p) == {"spicetify": "bake:spotify:spicetify apply"}
    finally:
        done.set()
        th.join()
    (r,) = hooks.retry_queued(p)
    assert r.state == "applied" and hooks.load_queue(p) == {}
