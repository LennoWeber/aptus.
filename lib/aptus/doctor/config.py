"""`aptus doctor config`: settings.json against the schema (07-architecture §8)."""
from __future__ import annotations

import json
import os
import re
from pathlib import Path
from typing import TYPE_CHECKING

from ..paths import inside as inside_home

if TYPE_CHECKING:
    from . import Check
    from ..paths import Paths


def check(paths: Paths) -> list[Check]:
    """settings.json parses, has "v": 2, every key is known and valid (same rules as
    shell/core/js/config.js); a v1 file is reported as ignored, not as an error."""
    from . import Check

    name = "config: settings.json"
    if not paths.settings.exists():
        return [Check(name, True, "absent: every setting has its default")]
    try:
        raw = json.loads(paths.settings.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        return [Check(name, False, f"line {e.lineno}, column {e.colno}: {e.msg}")]
    except (OSError, UnicodeDecodeError) as e:
        return [Check(name, False, f"unreadable: {e}")]
    if not isinstance(raw, dict):
        return [Check(name, False, "not a JSON object")]
    if "v" not in raw:
        return [Check(name, True, 'a v1 file (no "v"): ignored, v2 uses the defaults '
                      "(install.sh moves it to the v1 backup)", warn=True)]
    if raw["v"] != 2:
        return [Check(name, False, f'unknown version "v": {raw["v"]!r} (expected 2)')]
    schema = json.loads(paths.schema.read_text(encoding="utf-8"))
    keys = schema["keys"]
    checks: list[Check] = []
    values = {k: e["default"] for k, e in keys.items()}
    for key, value in raw.items():
        if key == "v":
            continue
        if key not in keys:
            checks.append(Check(f"config: {key}", True, "unknown key (kept, not used)", warn=True))
            continue
        problem = validate(schema, key, value, str(paths.home))
        if problem:
            checks.append(Check(f"config: {key}", False, f"{problem}; the default is used"))
        else:
            values[key] = value
    for rule in schema.get("rules", []):
        if rule["kind"] == "order":
            chain = [(k, values[k]) for k in rule["keys"]
                     if not (rule.get("ignoreZero") and values[k] == 0)]
            ops = {"<": lambda x, y: x < y, "<=": lambda x, y: x <= y}
            relation = dict(zip(rule["keys"][1:], rule["relations"]))
            for (ka, va), (kb, vb) in zip(chain, chain[1:]):
                op = relation.get(kb, "<=")
                if not ops[op](va, vb):
                    checks.append(Check(f"config: {kb}", False,
                                        f"must be {'greater than' if op == '<' else 'at least'} "
                                        f"{ka} ({va}); the default is used"))
        elif rule["kind"] == "member":
            if values[rule["key"]] not in values[rule["of"]]:
                checks.append(Check(f"config: {rule['key']}", False,
                                    f"must be one of {rule['of']} "
                                    f"({', '.join(map(str, values[rule['of']]))}); the default is used"))
    set_count = len(raw) - 1
    if not any(not c.ok for c in checks):
        checks.insert(0, Check(name, True, f"{set_count} value(s) set"))
    return checks


def validate(schema: dict, key: str, value: object, home: str) -> str | None:
    """None when valid, else the message (the same wording as the shell)."""
    entry = schema["keys"].get(key)
    if entry is None:
        return "is not a known setting"
    kind = entry["type"]
    inside_types = {t for r in schema.get("rules", []) if r["kind"] == "insideHome"
                    for t in r["types"]}

    def is_int(v: object) -> bool:
        return isinstance(v, int) and not isinstance(v, bool)

    def number_problem(v: object, e: dict) -> str | None:
        if not is_int(v):
            return "must be a whole number"
        if v == 0 and e.get("zeroMeans"):
            return None
        lo, hi = e.get("min"), e.get("max")
        if (lo is not None and v < lo) or (hi is not None and v > hi):
            unit = f" {e['unit']}" if e.get("unit") else ""
            zero = f" (or 0: {e['zeroMeans']})" if e.get("zeroMeans") else ""
            return f"must be {lo}–{hi}{unit}{zero}"
        return None

    def path_problem(v: object, must_exist: bool, inside: bool) -> str | None:
        if not isinstance(v, str) or not v:
            return "must be a path"
        full = home + v[1:] if v == "~" or v.startswith("~/") else v
        if not os.path.isabs(full):
            return "must be an absolute path or start with ~"
        if inside and not inside_home(Path(os.path.normpath(full)), Path(home)):
            return "must be inside your home folder"
        if must_exist and not os.path.isdir(full):
            return "must be an existing folder"
        return None

    def time_ok(v: object) -> bool:
        return isinstance(v, str) and re.fullmatch(r"([01]\d|2[0-3]):[0-5]\d", v) is not None

    def in_values(v: object, vals: list) -> bool:
        return not isinstance(v, bool) and any(v == x for x in vals)

    if kind == "derived":
        return f"is derived from {entry.get('from', 'another setting')} and cannot be set"
    if kind == "bool":
        return None if isinstance(value, bool) else "must be true or false"
    if kind == "int":
        return number_problem(value, entry)
    if kind == "enum":
        return None if in_values(value, entry["values"]) else \
            "must be one of " + ", ".join(map(str, entry["values"]))
    if kind == "enum|int":
        if in_values(value, entry["values"]):
            return None
        problem = number_problem(value, entry)
        return None if problem is None else \
            f"must be {' or '.join(map(str, entry['values']))} or {entry['min']}–{entry['max']}"
    if kind == "enum|string":
        if in_values(value, entry["values"]):
            return None
        if isinstance(value, str) and entry.get("pattern", "") in value:
            return None
        return ("must be one of " + ", ".join(entry["values"])
                + f" or a URL with {entry.get('pattern', '')}")
    if kind == "string":
        if not isinstance(value, str):
            return "must be text"
        if entry.get("pattern") and entry["pattern"] not in value:
            return f"must contain {entry['pattern']}"
        return None
    if kind == "time":
        return None if time_ok(value) else "must be a time HH:MM"
    if kind == "path":
        return path_problem(value, bool(entry.get("mustExist")), "path" in inside_types)
    if kind == "list":
        if not isinstance(value, list):
            return "must be a list"
        if "minItems" in entry and len(value) < entry["minItems"] or \
                "maxItems" in entry and len(value) > entry["maxItems"]:
            lo, hi = entry.get("minItems", 0), entry.get("maxItems")
            return (f"must have exactly {lo} entries" if lo == hi
                    else f"must have at most {hi} entries" if lo == 0
                    else f"must have {lo}–{hi} entries")
        if entry.get("unique") and len({json.dumps(v, sort_keys=True) for v in value}) != len(value):
            return "must not list an entry twice"
        of = entry.get("of")
        for item in value:
            if of == "string" and not isinstance(item, str):
                return "every entry must be text"
            if of == "int":
                problem = number_problem(item, entry)
                if problem:
                    return f"every entry {problem}"
            if of == "enum" and not in_values(item, entry["values"]):
                return "every entry must be one of " + ", ".join(map(str, entry["values"]))
            if of == "path":
                problem = path_problem(item, False, "list<path>" in inside_types)
                if problem:
                    return f"every entry {problem}"
        return None
    if kind == "map":
        if not isinstance(value, dict):
            return "must be an object"
        for k, v in value.items():
            if not isinstance(v, str):
                return f"{k}: must be text"
            if entry.get("pattern") and entry["pattern"] not in v:
                return f"{k}: must contain {entry['pattern']}"
        return None
    if kind == "object":
        if value is None:
            return None if entry.get("nullable") else "must not be null"
        if not isinstance(value, dict):
            return "must be an object"
        for field, ftype in entry.get("shape", {}).items():
            v = value.get(field)
            if ftype == "string" and not isinstance(v, str):
                return f"{field}: must be text"
            if ftype == "number" and (not isinstance(v, (int, float)) or isinstance(v, bool)):
                return f"{field}: must be a number"
            if ftype == "time" and not time_ok(v):
                return f"{field}: must be a time HH:MM"
            if ftype == "list<int>":
                if not isinstance(v, list) or not all(is_int(x) for x in v):
                    return f"{field}: must be a list of whole numbers"
                ranges = entry.get("itemRanges", {}).get(field, {})
                if any(x < ranges.get("min", x) or x > ranges.get("max", x) for x in v):
                    return f"{field}: every entry must be {ranges.get('min')}–{ranges.get('max')}"
                if ranges.get("unique") and len(set(v)) != len(v):
                    return f"{field}: must not list an entry twice"
        return None
    return f"has an unknown type {kind!r} in the schema"
