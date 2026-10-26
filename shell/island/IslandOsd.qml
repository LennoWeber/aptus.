import QtQuick
import qs.models
import qs.theme
import qs.components

// The on-screen indicator in the island: a symbol, a bar (or a text) and the value.
Item {
    id: osdView

    property var osd                // { kind (Enums.OsdKind), level (0..1), muted, label } or null
    property color ink
    property color inkSoft
    property color line

    readonly property bool hasLabel: osd !== null && osd !== undefined && osd.label !== ""

    // Symbol name for an Enums.OsdKind (volume, sun, mic, cup, rotate).
    function glyphFor(kind: int): string {
        if (kind < Enums.OsdKind.Volume || kind > Enums.OsdKind.Caffeine) throw new Error("invariant: IslandOsd.glyphFor: unknown OSD kind")
        return kind === Enums.OsdKind.Brightness ? "sun" : kind === Enums.OsdKind.Microphone ? "mic" : kind === Enums.OsdKind.Caffeine ? "cup" : kind === Enums.OsdKind.Rotation ? "rotate" : "volume"
    }

    // The value as text: "42%", "Muted", or the label.
    function valueText(): string {
        if (!osd) return ""
        if (osd.label !== "") return osd.label
        return osd.muted ? "Muted" : Math.round(osd.level * 100) + "%"
    }

    StatusGlyph {
        x: 18
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        kind: osdView.osd ? osdView.glyphFor(osdView.osd.kind) : "volume"
        level: osdView.osd ? osdView.osd.level : 0
        muted: osdView.osd ? osdView.osd.muted : false
        color: osdView.osd && osdView.osd.muted ? Tokens.critical : osdView.ink
    }

    // The bar: a hairline track and a filled part that follows the value quickly.
    Rectangle {
        visible: !osdView.hasLabel
        anchors { left: parent.left; leftMargin: 50; right: parent.right; rightMargin: 64; verticalCenter: parent.verticalCenter }
        height: 5
        radius: height / 2
        color: Qt.rgba(osdView.ink.r, osdView.ink.g, osdView.ink.b, 0.16)
        Rectangle {
            height: parent.height
            width: Math.max(parent.height, parent.width * (osdView.osd && !osdView.osd.muted ? osdView.osd.level : 0))
            radius: height / 2
            color: osdView.ink
            Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
        }
    }

    Label {
        anchors { right: parent.right; rightMargin: osdView.hasLabel ? 0 : 20; verticalCenter: parent.verticalCenter }
        anchors.left: osdView.hasLabel ? parent.left : undefined
        anchors.leftMargin: osdView.hasLabel ? 50 : 0
        text: osdView.valueText()
        tabularNumbers: !osdView.hasLabel
        color: osdView.osd && osdView.osd.muted ? Tokens.critical : osdView.ink
        font.weight: osdView.hasLabel ? Font.Medium : Font.Normal
        elide: Text.ElideRight
    }
}
