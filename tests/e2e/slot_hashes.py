"""The slots of the round trip (02 §10), read only: every lease and bake slot of the manifest with
its sha256 (or "missing"), and every leased dconf key with its value. Nothing is written, and
nothing below ~/.config/umbriel, ~/.config/noctalia or ~/.local/state/noctalia is read.

For Lenno's manual round trip:

    python3 tests/e2e/slot_hashes.py > ~/aptus-before.txt          # in Umbriel
    # … log into Hyprland, end it, log into Umbriel again …
    python3 tests/e2e/slot_hashes.py | diff ~/aptus-before.txt -   # no output: every byte is back

tests/e2e/test_s2.py uses `slots` to copy the real slot files into its temporary HOME.
"""
from __future__ import annotations

import hashlib
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "lib"))

from aptus import paths as paths_mod  # noqa: E402
from aptus.lease.kinds import dconf as dconf_kind  # noqa: E402
from aptus.theme import targets  # noqa: E402
from aptus.theme.targets import Mechanism  # noqa: E402

NEVER_READ = (".config/umbriel", ".config/noctalia", ".local/state/noctalia")


def _never(rel: Path) -> bool:
    s = str(rel)
    return any(s == n or s.startswith(n + "/") for n in NEVER_READ)


def manifest() -> targets.Manifest:
    return targets.load(REPO / "theme" / "targets.toml")


def slots(p: paths_mod.Paths) -> list[Path]:
    """Every lease and bake slot below p.home (`*` slots globbed), sorted."""
    out: set[Path] = set()
    for t in manifest().targets:
        if t.mechanism in (Mechanism.LEASE, Mechanism.BAKE):
            out |= {s for _f, s in targets.slots(p, t) if not _never(s.relative_to(p.home))}
    return sorted(out)


def dconf_keys() -> list[str]:
    return sorted({dconf_kind.KEY_DIR + k for t in manifest().targets for k, _ in t.dconf})


def dconf_read(key: str) -> str:
    """The key's value as `dconf read` prints it ("" when unset or dconf is missing)."""
    try:
        return subprocess.run(["dconf", "read", key], capture_output=True, text=True,
                              timeout=5).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ""


def lines(p: paths_mod.Paths) -> list[str]:
    out = []
    for s in slots(p):
        digest = hashlib.sha256(s.read_bytes()).hexdigest() if s.is_file() else "missing"
        out.append(f"{digest}  {s}")
    out += [f"dconf  {k} = {dconf_read(k) or '(unset)'}" for k in dconf_keys()]
    return out


def main() -> int:
    print("\n".join(lines(paths_mod.resolve({"HOME": str(Path.home())}))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
