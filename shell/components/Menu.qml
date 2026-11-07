// Menu: Floating menu (03 §9): raised, radius 12, 6 padding, rows 30, shadow; separators 1 px line inset 8 (M-33).
import QtQuick
import qs.core

Item {
    id: root

    // [{ label, glyph, risk: bool, enabled: bool, separator: bool, checked: bool, submenu: [...], id }]
    property var model: []
    // The point the menu grows from (monitor-local).
    property real anchorX: 0
    property real anchorY: 0
    property int currentIndex: -1
    signal triggered(var row)
    signal dismissed()
}
