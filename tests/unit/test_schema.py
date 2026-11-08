"""settings-schema.json against design/10-settings.md (07 §8: a test fails if they differ)."""
from __future__ import annotations

import json
import re
from pathlib import Path

from aptus.doctor import config as dconfig

REPO = Path(__file__).resolve().parents[2]
SCHEMA = json.loads((REPO / "shell" / "config" / "settings-schema.json").read_text(encoding="utf-8"))
DOC = (REPO / "design" / "10-settings.md").read_text(encoding="utf-8")
KEYS = SCHEMA["keys"]
TYPES = {"bool", "int", "enum", "enum|int", "enum|string", "string", "time", "path", "list", "map",
         "object", "derived"}


def doc_rows() -> dict[str, list[str]]:
    """key (as written, `<id>` patterns included) → the table cells of its row."""
    rows: dict[str, list[str]] = {}
    for line in DOC.splitlines():
        m = re.match(r"^\| `([a-zA-Z][\w.<>]*)` \|", line)
        if m:
            rows[m.group(1)] = [c.strip() for c in line.strip().strip("|").split("|")]
    return rows


def expanded_doc_keys() -> set[str]:
    out: set[str] = set()
    templates = {t["pattern"]: t["ids"] for t in SCHEMA["templates"]}
    for key in doc_rows():
        if "<" in key:
            out |= {key.replace("<id>", i) for i in templates[key]}
        else:
            out.add(key)
    return out


def test_every_key_documented() -> None:
    missing = sorted(set(KEYS) - expanded_doc_keys())
    assert not missing, f"in the schema, not in 10-settings.md: {missing}"


def test_every_documented_key_in_schema() -> None:
    missing = sorted(expanded_doc_keys() - set(KEYS))
    assert not missing, f"in 10-settings.md, not in the schema: {missing}"
    for template in doc_rows():
        if "<" in template:
            assert template in {t["pattern"] for t in SCHEMA["templates"]}


def test_defaults_equal() -> None:
    pages = {p["id"] for p in SCHEMA["pages"]}
    for key, e in KEYS.items():
        for field in ("type", "default", "page", "label", "description"):
            assert field in e, f"{key}: no {field}"
        assert e["page"] in pages, key
        assert e["label"].strip() and e["description"].strip(), key
        # Defaults validate against their own entry (derived keys are not settable).
        if e["type"] != "derived":
            problem = dconfig.validate(SCHEMA, key, e["default"], "/home/t")
            # A default folder need not exist yet (the settings window creates it on demand).
            assert problem in (None, "must be an existing folder"), (key, e["default"], problem)
    # Defaults written in the doc agree with the schema where the cell is plain JSON.
    rows = doc_rows()
    checked = 0
    for key, cells in rows.items():
        keys = [key] if "<" not in key else [k for k in KEYS if k.startswith(key.split("<")[0])
                                              and k.endswith(key.split(">")[-1])]
        raw = cells[2].strip("`")
        try:
            doc_default = json.loads(raw)
        except ValueError:
            doc_default = raw if raw.startswith("~") or raw.isalpha() else None
        if doc_default is None or (isinstance(doc_default, str) and not isinstance(
                KEYS[keys[0]]["default"], str)):
            continue
        for k in keys:
            default = KEYS[k]["default"]
            if isinstance(doc_default, (int, float)) and not isinstance(doc_default, bool) \
                    and isinstance(default, (int, float)):
                assert float(default) == float(doc_default), (k, default, doc_default)
            else:
                assert default == doc_default, (k, default, doc_default)
            checked += 1
    assert checked > 60


def test_types_valid() -> None:
    for key, e in KEYS.items():
        assert e["type"] in TYPES, (key, e["type"])
        if e["type"] in ("enum", "enum|int", "enum|string"):
            assert e["values"], key
            if e["type"] == "enum":
                assert e["default"] in e["values"], key
        if e["type"] == "list":
            assert e.get("of") in ("string", "int", "enum", "path"), key
            if e["of"] == "enum":
                assert e["values"], key
        if e["type"] in ("int", "enum|int"):
            if "min" in e or "max" in e:
                assert e["min"] <= e["max"], key
            else:                       # unbounded only when a cross rule bounds it (focus.default)
                assert key in {r["key"] for r in SCHEMA["rules"] if r["kind"] == "member"}, key
        if e["type"] == "object":
            assert "shape" in e, key
    # A wrong value of every kind is rejected, never accepted silently.
    assert dconfig.validate(SCHEMA, "appearance.glass", "yes", "/h")
    assert dconfig.validate(SCHEMA, "appearance.mode", "blue", "/h")
    assert dconfig.validate(SCHEMA, "bar.tray.max", 7, "/h")
    assert dconfig.validate(SCHEMA, "bar.tray.max", True, "/h")
    assert dconfig.validate(SCHEMA, "bar.height", 32, "/h")        # derived: not settable
    assert dconfig.validate(SCHEMA, "jot.file", "relative/x.md", "/h")
    assert dconfig.validate(SCHEMA, "jot.file", "/etc/passwd", "/h")   # outside home
    assert dconfig.validate(SCHEMA, "dnd.schedule", {"from": "25:00", "to": "07:00", "days": [1]}, "/h")
    assert dconfig.validate(SCHEMA, "dnd.schedule", None, "/h") is None


def test_rules_reference_keys() -> None:
    kinds = set()
    for rule in SCHEMA["rules"]:
        kinds.add(rule["kind"])
        if rule["kind"] == "order":
            assert set(rule["keys"]) <= set(KEYS)
            assert len(rule["relations"]) == len(rule["keys"]) - 1
            assert set(rule["relations"]) <= {"<", "<="}
        elif rule["kind"] == "member":
            assert rule["key"] in KEYS and rule["of"] in KEYS
            assert KEYS[rule["of"]]["type"] == "list"
        elif rule["kind"] == "insideHome":
            assert set(rule["types"]) <= {"path", "list<path>"}
    assert kinds <= {"order", "member", "insideHome"}
    for template in SCHEMA["templates"]:
        for i in template["ids"]:
            assert template["pattern"].replace("<id>", i) in KEYS
