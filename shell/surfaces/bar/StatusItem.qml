// One status item (surfaces/bar.md §6): a 16 px glyph (with the charging bolt or the VPN key),
// optional text, a tooltip; opens 0 → w and then fades its glyph in (M-04).
pragma ComponentBehavior: Bound
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // The status item record (bar.js).
    property var item: ({})
    // The item is wanted (M-04: width opens, then the glyph fades in; reverse to leave).
    property bool shown: true

    readonly property bool hovered: false

    signal clicked()
    signal middleClicked()
    signal rightClicked(real x, real y)
    signal wheelStep(int direction)

    // M-04 progress: width 0 → 1, then the glyph 0 → 1.
    property real _open: 0
    property real _glyph: 0
}
