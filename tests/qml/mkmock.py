"""Build the import dir for qmltestrunner (tests/run): qmltestrunner cannot load the Quickshell
plugin, so the tests import test doubles of Quickshell (incl. Quickshell.Io: a FileView that reads
through XHR and writes to memory, a Process that runs nothing) and of Log and Paths from here, plus
the real qs.components, core/js, MonitorState, and Config, Tokens, Motion and SurfaceManager made
independent of the Quickshell plugin.

    python3 tests/qml/mkmock.py <out-dir>
"""
from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
MOCK = Path(__file__).resolve().parent / "mock"


def strip_quickshell(text: str) -> str:
    """A core singleton without the Quickshell plugin: `Singleton {` → `Item {`, no `import
    Quickshell` (Quickshell.Io stays: the mock module provides it)."""
    text = text.replace("import Quickshell\n", "")
    return re.sub(r"\nSingleton \{", "\nItem {", text, count=1)


def build(out: Path) -> None:
    if out.exists():
        shutil.rmtree(out)
    shutil.copytree(MOCK, out, symlinks=True)
    core = out / "qs" / "core"
    # the real core singletons; Quickshell.Io comes from the mock (FileView reads through XHR,
    # Process and StdioCollector do nothing, so reduced motion stays off)
    for name in ("Tokens", "Motion", "Config", "SurfaceManager"):
        text = (REPO / "shell/core" / f"{name}.qml").read_text(encoding="utf-8")
        (core / f"{name}.qml").write_text(strip_quickshell(text), encoding="utf-8")
    paths = core / "Paths.qml"
    paths.write_text(paths.read_text(encoding="utf-8").replace("@REPO@", str(REPO)), encoding="utf-8")
    (core / "MonitorState.qml").symlink_to(REPO / "shell/core/MonitorState.qml")
    (core / "js").symlink_to(REPO / "shell/core/js")
    (out / "qs" / "components").symlink_to(REPO / "shell/components")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    build(Path(sys.argv[1]))
