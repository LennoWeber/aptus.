// IconButton: Icon-only button (03 §9): 28 (bar) or 32 (drawers), glyph 18, tooltip required.
import QtQuick
import qs.core

Item {
    id: root

    // TODO(phase): Glyph in a square with Wash and Tooltip (every icon-only control has one).

    property string glyph: ""
    property string tooltip: ""
    // "bar" | "drawer"
    property string size: "drawer"
    property bool on: false
    property bool keyboardFocus: false
    signal clicked()
    signal rightClicked()
    signal middleClicked()
}
