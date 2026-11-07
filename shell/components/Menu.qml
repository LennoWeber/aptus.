// Menu: Floating menu (03 §9): raised, radius 12, 6 padding, rows 30, shadow; separators 1 px line inset 8 (M-33).
import QtQuick
import qs.core

Item {
    id: root

    // TODO(phase): raised rect with rows/separators/submenus, grows from the anchor (M-33), keyboard handling.

    // [{ id, label, glyph, keys: "Ctrl+Enter", risk: bool, confirm: "Press again to …" (inline confirm,
    //    bar.md §3), enabled: bool, separator: bool, checked: bool, submenu: [...] }]
    property var model: []
    // The point the menu grows from (monitor-local).
    property real anchorX: 0
    property real anchorY: 0
    property int currentIndex: -1
    signal triggered(var row)
    signal dismissed()

    // Keyboard: ↑ ↓ move (skipping separators and disabled rows), Enter triggers.
    function moveCurrent(delta: int): void { throw new Error("Menu.moveCurrent: not implemented"); }
    function triggerCurrent(): void { throw new Error("Menu.triggerCurrent: not implemented"); }
}
