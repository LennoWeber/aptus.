#!/usr/bin/env bash
# aptus: qmllint over the shell and greeter. Read-only. Writes ./aptus-lint.txt next to this script.
# Quickshell resolves `import qs.<folder>` at runtime; qmllint needs a folder named `qs` to find them,
# so a temporary link  <tmp>/qs -> shell/  is created and passed with -I (the tmp folder is removed afterwards).
cd "$(dirname "$0")" || exit 1
LINT=/usr/lib64/qt6/bin/qmllint
OUT="$PWD/aptus-lint.txt"; : > "$OUT"
T=$(mktemp -d); ln -s "$PWD/shell" "$T/qs"
echo "===== shell =====" >> "$OUT"
find shell -name '*.qml' | sort | while read -r f; do
  r=$($LINT -I /usr/lib64/qt6/qml -I "$T" "$f" 2>&1); [ -n "$r" ] && printf '%s\n' "$r" >> "$OUT"
done
echo "===== greeter =====" >> "$OUT"
find greeter -name '*.qml' | sort | while read -r f; do
  r=$($LINT -I /usr/lib64/qt6/qml -I "$T" -I greeter "$f" 2>&1); [ -n "$r" ] && printf '%s\n' "$r" >> "$OUT"
done
rm -rf "$T"
echo "===== summary =====" >> "$OUT"
echo "warnings: $(grep -c 'Warning:' "$OUT")" >> "$OUT"; echo "errors: $(grep -c 'Error:' "$OUT")" >> "$OUT"
echo "Fertig: $OUT"
