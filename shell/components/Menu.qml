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

    // Private state.
    // Edges to flip to when the menu does not fit right of / below the anchor (a submenu flips
    // to the other side of its parent menu).
    property real _altX
    property real _altY
    // Nesting depth (0: the root menu; ← closes a submenu).
    property int _level: 0
    property int _confirmIndex: -1
    property int _subIndex: -1
    // Entrance progress 0 → 1 (M-33).
    property real _appear
    readonly property real _pad: 0
    readonly property real _margin: 0
    readonly property real _rowRadius: 0
    readonly property bool _hasLead: false
    readonly property real _rowsWidth: 0
    readonly property real _space: 0
    readonly property real _spaceV: 0

    // Private helpers.
    function _usable(i: int): bool { throw new Error("Menu._usable: not implemented"); }
    function _hasSub(i: int): bool { throw new Error("Menu._hasSub: not implemented"); }
    function _setCurrent(i: int): void { throw new Error("Menu._setCurrent: not implemented"); }
    function _cancelConfirm(): void { throw new Error("Menu._cancelConfirm: not implemented"); }
    function _activate(i: int, viaKeyboard: bool): void { throw new Error("Menu._activate: not implemented"); }
    function _openSub(i: int, viaKeyboard: bool): void { throw new Error("Menu._openSub: not implemented"); }
    function _closeSub(refocus: bool): void { throw new Error("Menu._closeSub: not implemented"); }
}
