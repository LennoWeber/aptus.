#!/usr/bin/bash
# tests/lint.sh: qmllint over shell/ (QML and the JS libraries), 0 warnings as the target (CLAUDE.md).
# qs.* imports resolve through a temp dir holding `qs -> <repo>/shell`; Quickshell's own modules come
# from the Qt module path; .qmllint.ini at the repo root holds the settings.
set -euo pipefail

repo="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
qmllint="${QMLLINT:-/usr/lib64/qt6/bin/qmllint}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
ln -s "$repo/shell" "$tmp/qs"

cd "$repo/shell"
mapfile -t files < <(find . \( -name '*.qml' -o -name '*.js' \) -type f | sort)
if "$qmllint" --max-warnings 0 -I "$tmp" -I /usr/lib64/qt6/qml "${files[@]}"; then
    echo "qmllint: ${#files[@]} files, 0 warnings"
else
    echo "qmllint: warnings (see above)" >&2
    exit 1
fi
