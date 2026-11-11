"""S3's surfaces take every colour from Tokens (CLAUDE.md, 03): no colour literal in the bar, the
notch or the frame (wave-2 review of S3, finding 10: a `"transparent"` in WorkspacePill)."""
from __future__ import annotations

import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SURFACES = [REPO / "shell" / "surfaces" / d for d in ("bar", "notch", "frame")]
# a colour written out: a named "transparent", a hex string, Qt.rgba/hsla/hsva or Qt.color("…")
LITERAL = re.compile(r'"transparent"|"#[0-9a-fA-F]{3,8}"|\bQt\.(rgba|hsla|hsva|color)\(')


def test_no_colour_literals_in_s3_surfaces() -> None:
    found = []
    for folder in SURFACES:
        for path in sorted(folder.rglob("*.qml")) + sorted(folder.rglob("*.js")):
            for no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                code = line.split("//", 1)[0]
                if LITERAL.search(code):
                    found.append(f"{path.relative_to(REPO)}:{no}: {line.strip()}")
    assert not found, "colour literals:\n" + "\n".join(found)
