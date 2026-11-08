"""Build the import dir for qmltestrunner (tests/run): qmltestrunner cannot load the Quickshell
plugin, so tst_components imports test doubles of Quickshell and qs.core from here, plus the real
qs.components, core/js, MonitorState, and Tokens/Motion with their Quickshell parts taken out.

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
    """A core singleton without Quickshell: no Quickshell imports, `Singleton {` → `Item {`."""
    text = text.replace("import Quickshell.Io\n", "").replace("import Quickshell\n", "")
    return re.sub(r"\nSingleton \{", "\nItem {", text, count=1)


def cut_block(text: str, start: str, replacement: str = "") -> str:
    """Replace the brace block that begins with the line `start` (e.g. "    FileView {")."""
    i = text.index(start)
    depth, j = 0, i
    while True:
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                break
        j += 1
    return text[:i] + replacement + text[j + 1:]


def tokens_qml() -> str:
    """Tokens reads tokens.json with a synchronous XHR instead of FileView (needs
    QML_XHR_ALLOW_FILE_READ=1)."""
    s = strip_quickshell((REPO / "shell/core/Tokens.qml").read_text(encoding="utf-8"))
    s = cut_block(s, "    FileView {", f"""    function _load(): void {{
        const x = new XMLHttpRequest();
        x.open("GET", "file://{REPO}/theme/tokens.json", false);
        x.send();
        root.raw = JSON.parse(x.responseText);
    }}""")
    if "Component.onCompleted: {" not in s:
        raise SystemExit("mkmock: Tokens.qml has no Component.onCompleted block to load from")
    return s.replace("Component.onCompleted: {", "Component.onCompleted: { _load();", 1)


def motion_qml() -> str:
    """Motion without the gsettings Process (reduced motion stays off)."""
    s = strip_quickshell((REPO / "shell/core/Motion.qml").read_text(encoding="utf-8"))
    return cut_block(s, "    Process {")


def build(out: Path) -> None:
    if out.exists():
        shutil.rmtree(out)
    shutil.copytree(MOCK, out, symlinks=True)
    core = out / "qs" / "core"
    (core / "Tokens.qml").write_text(tokens_qml(), encoding="utf-8")
    (core / "Motion.qml").write_text(motion_qml(), encoding="utf-8")
    paths = core / "Paths.qml"
    paths.write_text(paths.read_text(encoding="utf-8").replace("@REPO@", str(REPO)), encoding="utf-8")
    (core / "MonitorState.qml").symlink_to(REPO / "shell/core/MonitorState.qml")
    (core / "js").symlink_to(REPO / "shell/core/js")
    (out / "qs" / "components").symlink_to(REPO / "shell/components")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    build(Path(sys.argv[1]))
