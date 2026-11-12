pragma ComponentBehavior: Bound
// An event (surfaces/notch.md §7): glyph + one line, bulge 260–360 × 36, shown 1.6 s.
import QtQuick
import qs.core
import qs.components
import "js/notch.js" as NJ

Item {
    id: root

    // { text, glyph } (SurfaceManager.post("event", …)).
    property var payload: ({})

    // The bulge size: 260–360 × 36, from the text's width.
    readonly property var _size: NJ.bulgeSize("event", payload, { width: row.implicitWidth + 2 * Tokens.padToast }, Tokens.surfaces)
    readonly property real bulgeWidth: _size.width
    readonly property real bulgeHeight: _size.height

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.s4
        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: name !== ""
            name: root.payload.glyph || ""
            size: Tokens.glyphRow
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            type: "body"
            elide: Text.ElideRight
            width: Math.min(implicitWidth, Tokens.surfaces.event.maxWidth - 2 * Tokens.padToast - Tokens.glyphRow - row.spacing)
            text: root.payload.text || ""
        }
    }
}
