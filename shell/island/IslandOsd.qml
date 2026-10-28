import QtQuick
import qs.models
import qs.theme
import qs.components

// The on-screen indicator in the island: a badge with the symbol, the title and the device, the value large, a bar.
Item {
    id: osdView

    property var osd                // { kind (Enums.OsdKind), level (0..1), muted, label, detail } or null
    property color ink
    property color inkSoft
    property color line
    property real outerRadius: 22       // corner radius of the island body: inner shapes take outerRadius minus their margin

    readonly property bool hasLabel: osd !== null && osd !== undefined && osd.label !== ""
    readonly property bool muted: osd !== null && osd !== undefined && osd.muted

    // Symbol name for an Enums.OsdKind (volume, sun, mic, cup, rotate).
    function glyphFor(kind: int): string {
        if (kind < Enums.OsdKind.Volume || kind > Enums.OsdKind.Caffeine) throw new Error("invariant: IslandOsd.glyphFor: unknown OSD kind")
        return kind === Enums.OsdKind.Brightness ? "sun" : kind === Enums.OsdKind.Microphone ? "mic" : kind === Enums.OsdKind.Caffeine ? "cup" : kind === Enums.OsdKind.Rotation ? "rotate" : "volume"
    }

    // Title for an Enums.OsdKind ("Volume", "Brightness", ...).
    function titleFor(kind: int): string {
        if (kind < Enums.OsdKind.Volume || kind > Enums.OsdKind.Caffeine) throw new Error("invariant: IslandOsd.titleFor: unknown OSD kind")
        return ["Volume", "Brightness", "Microphone", "Rotation", "Caffeine"][kind]
    }

    // The value as text: "42%", "Muted", or the label.
    function valueText(): string {
        if (!osd) return ""
        if (osd.label !== "") return osd.label
        return osd.muted ? "Muted" : Math.round(osd.level * 100) + "%"
    }

    Rectangle {
        id: plate
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        height: 44
        // TODO(phase 7, style): plate radius = outerRadius minus its margin (14), min 4.
        radius: 14
        color: Qt.rgba((osdView.muted ? Tokens.critical : osdView.ink).r, (osdView.muted ? Tokens.critical : osdView.ink).g, (osdView.muted ? Tokens.critical : osdView.ink).b, 0.14)
        StatusGlyph {
            anchors.centerIn: parent
            width: 22
            height: 22
            kind: osdView.osd ? osdView.glyphFor(osdView.osd.kind) : "volume"
            level: osdView.osd ? osdView.osd.level : 0
            muted: osdView.muted
            color: osdView.muted ? Tokens.critical : osdView.ink
        }
    }

    // Title and device on one line, the value large on the right.
    Label {
        id: title
        x: 70
        y: osdView.hasLabel ? (osdView.height - implicitHeight) / 2 - (detailText.visible ? 8 : 0) : 12
        width: osdView.width - 70 - 18 - (osdView.hasLabel ? 0 : value.implicitWidth + 10)
        text: osdView.hasLabel ? osdView.osd.label : osdView.osd ? osdView.titleFor(osdView.osd.kind) : ""
        color: osdView.ink
        font.weight: Font.DemiBold
        font.pixelSize: 14
        elide: Text.ElideRight
    }
    Label {
        id: detailText
        x: 70
        y: osdView.hasLabel ? title.y + title.implicitHeight + 1 : 29
        width: osdView.width - 70 - 18
        visible: osdView.osd !== null && osdView.osd !== undefined && osdView.osd.detail !== "" && (osdView.hasLabel || false)
        text: osdView.osd ? osdView.osd.detail : ""
        color: osdView.inkSoft
        role: Enums.TextRole.Bar
        elide: Text.ElideRight
    }
    Label {
        id: value
        visible: !osdView.hasLabel
        anchors { right: parent.right; rightMargin: 18 }
        y: 8
        text: osdView.valueText()
        tabularNumbers: true
        color: osdView.muted ? Tokens.critical : osdView.ink
        font.pixelSize: 20
        font.weight: Font.DemiBold
    }

    // The bar: a thicker track and a filled part that follows the value quickly.
    Rectangle {
        visible: !osdView.hasLabel
        x: 70
        y: osdView.height - 22
        width: osdView.width - 70 - 18
        height: 6
        radius: 3
        color: Qt.rgba(osdView.ink.r, osdView.ink.g, osdView.ink.b, 0.16)
        Rectangle {
            height: parent.height
            width: Math.max(parent.height, parent.width * (osdView.osd && !osdView.muted ? osdView.osd.level : 0))
            radius: 3
            color: osdView.ink
            Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
        }
    }
    // The device under the title when there is a bar: a small line between title row and bar.
    Label {
        visible: !osdView.hasLabel && osdView.osd !== null && osdView.osd !== undefined && osdView.osd.detail !== ""
        x: 70
        y: 31
        width: osdView.width - 70 - 18
        text: osdView.osd ? osdView.osd.detail : ""
        color: osdView.inkSoft
        role: Enums.TextRole.Bar
        font.pixelSize: 11
        elide: Text.ElideRight
    }
}
