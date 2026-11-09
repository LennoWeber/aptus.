// An event (surfaces/notch.md §7): glyph + one line, bulge 260–360 × 36, shown 1.6 s.
pragma ComponentBehavior: Bound
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // { text, glyph } (SurfaceManager.post("event", …)).
    property var payload: ({})

    // 260–360 × 36, from the text's width.
    // TODO(phase): notch.js bulgeSize("event", …): the row's width clamped 260–360 × 36.
    readonly property real bulgeWidth: 0
    readonly property real bulgeHeight: 0

    // TODO(phase): glyph + one line of text (body).
}
