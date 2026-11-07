// Glyph: A Material Symbols Rounded glyph (03 §5). FILL and wght follow `on`/`active` and animate (P-17).
import QtQuick
import qs.core

Text {
    id: root

    // The symbol name (ligature), e.g. "wifi".
    property string name: ""
    property real size: 18
    // FILL 1 when on.
    property bool on: false
    // wght 500 when active.
    property bool active: false
    property color colour
}
