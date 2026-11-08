"""theme/tokens.json against 03/04 (structure and the numbers the docs fix)."""
from __future__ import annotations

import json
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
TOKENS = json.loads((REPO / "theme" / "tokens.json").read_text(encoding="utf-8"))
HEX = re.compile(r"^#[0-9a-f]{6}$")
ROLES = ("mode", "ground", "raised", "raisedHot", "sunken", "line", "ink", "warn", "crit",
         "onAccent", "scrim", "shadow", "selectionAmount", "glyphGrad", "ansi")


def test_palettes_have_every_role() -> None:
    assert set(TOKENS["palettes"]) == {"ember", "linen"}
    assert TOKENS["modes"] == {"dark": "ember", "light": "linen"}
    for name, p in TOKENS["palettes"].items():
        assert set(ROLES) <= set(p), name
        assert p["mode"] == ("dark" if name == "ember" else "light")
        for role in ("ground", "raised", "raisedHot", "sunken", "line", "warn", "crit", "onAccent"):
            assert HEX.match(p[role]), (name, role)
        assert set(p["ink"]) == {"main", "sec", "meta", "faint"}
        assert all(HEX.match(v) for v in p["ink"].values())
        for layer in ("scrim", "shadow"):
            assert HEX.match(p[layer]["color"]) and 0 < p[layer]["alpha"] < 1
    assert TOKENS["palettes"]["ember"]["ground"] == "#191613"
    assert TOKENS["palettes"]["linen"]["ground"] == "#f4ede1"


def test_ansi_tables() -> None:
    for name, p in TOKENS["palettes"].items():
        assert len(p["ansi"]) == 16, name
        assert all(HEX.match(c) for c in p["ansi"]), name
        assert len(set(p["ansi"])) == 16, name
    ember = TOKENS["palettes"]["ember"]
    # Ember: black is the raised-hot surface, white (7) the secondary ink, bright white the main ink.
    assert ember["ansi"][0] == ember["raisedHot"]
    assert ember["ansi"][7] == ember["ink"]["sec"]
    assert ember["ansi"][15] == ember["ink"]["main"]
    assert ember["ansi"][1] == ember["crit"] and ember["ansi"][3] == ember["warn"]


def test_accents() -> None:
    accents = TOKENS["accents"]
    assert TOKENS["accentOrder"] == ["jade", "apricot", "sky", "iris", "rose", "sand"]
    assert set(accents) == set(TOKENS["accentOrder"])
    for name, a in accents.items():
        assert HEX.match(a["ember"]) and HEX.match(a["linen"]), name
        assert a["papirus"] and a["gnome"], name
    assert accents["jade"]["ember"] == "#9acfae" and accents["jade"]["linen"] == "#25704f"
    assert accents["jade"]["papirus"] == "teal"
    assert len({a["papirus"] for a in accents.values()}) == 6


def test_motion_durations() -> None:
    d = TOKENS["motion"]["durations"]
    expected = {"press": (60, 60), "hover": (120, 120), "fade": (160, 110), "small": (200, 140),
                "surface": (280, 200), "page": (300, 220), "morph": (380, 300), "intro": (420, 0)}
    assert {k: (v["in"], v["out"]) for k, v in d.items() if k != "ambient"} == expected
    assert d["ambient"] == {"theme": 400, "wallpaper": 600}
    curves = TOKENS["motion"]["curves"]
    assert curves["standard"] == [0.2, 0, 0, 1] and curves["linear"] == [0, 0, 1, 1]
    assert TOKENS["motion"]["maxShellMs"] == 420


def test_springs() -> None:
    s = TOKENS["motion"]["springs"]
    assert set(s) == {"notch", "snappy", "gentle"}
    assert (s["notch"]["zeta"], s["notch"]["settle"]) == (0.78, 380)
    assert (s["snappy"]["zeta"], s["snappy"]["settle"]) == (0.9, 240)
    assert (s["gentle"]["zeta"], s["gentle"]["settle"]) == (1.0, 320)
    for name, spring in s.items():
        for k in ("spring", "damping", "mass", "epsilon"):
            assert spring[k] > 0, (name, k)
    # 04 §2.3: spring 4.0 / damping 0.30, 5.0 / 0.40, 3.0 / 0.45; epsilon 0.25 throughout.
    assert [(s[n]["spring"], s[n]["damping"]) for n in ("notch", "snappy", "gentle")] == \
        [(4.0, 0.30), (5.0, 0.40), (3.0, 0.45)]
    assert all(v["epsilon"] == 0.25 for v in s.values())
    assert s["gentle"]["overshoot"] == [0, 0]


def test_no_unknown_top_level() -> None:
    known = {"version", "palettes", "modes", "accents", "accentOrder", "washes", "contrastHigh",
             "glass", "wallpaperAccent", "frameLine", "shadow", "type", "glyph", "appIcon",
             "geometry", "spacing", "padding", "components", "motion", "fonts", "cursor",
             "surfaces"}
    assert set(TOKENS) == known
    assert TOKENS["version"] == 1
