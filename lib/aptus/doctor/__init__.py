"""`aptus doctor [isolation | config | deps]`: one line per check, non-zero exit on failure."""
from __future__ import annotations

from collections.abc import Sequence

from ..paths import Paths, get

from dataclasses import dataclass


@dataclass(frozen=True)
class Check:
    name: str
    ok: bool
    detail: str = ""
    warn: bool = False         # ok, but worth a look (stale plocate index, uncovered template)


def run(which: Sequence[str], paths: Paths) -> list[Check]:
    """Run the named groups ("config", "deps"; "isolation" arrives with S2), all by default."""
    from . import config, deps
    checks: list[Check] = []
    for group in list(which) or ["isolation", "config", "deps"]:
        if group == "config":
            checks += config.check(paths)
        elif group == "deps":
            checks += deps.check()
        elif group == "isolation":
            # TODO(S2): from . import isolation; checks += isolation.check(paths)
            checks.append(Check("isolation", True, "arrives with S2", warn=True))
        else:
            checks.append(Check(group, False, "unknown check group (isolation, config, deps)"))
    return checks


def render(checks: Sequence[Check]) -> str:
    """One line per check: "ok   name", "warn name: detail", "FAIL name: detail"."""
    lines = []
    for c in checks:
        word = "FAIL" if not c.ok else "warn" if c.warn else "ok  "
        lines.append(f"{word} {c.name}" + (f": {c.detail}" if c.detail and (c.warn or not c.ok)
                                            else ""))
    return "\n".join(lines)


def main(argv: Sequence[str]) -> int:
    checks = run(argv, get())
    print(render(checks))
    return 0 if all(c.ok for c in checks) else 1
