import QtQuick
import qs.models
import qs.theme
import qs.components

// Frame around one tile.
Rectangle {
    id: tile

    property int tileId  // Enums.TileId
    property string title
    property bool expanded
    property int severity  // Enums.Severity
    property var spec  // tile layout entry
    default property alias content: contentArea.data
    signal activated(int tileId)

    color: Tokens.surface
    radius: Tokens.radiusTile
    border.width: 1
    border.color: Qt.tint(Tokens.line, Qt.rgba(Tokens.inkFaint.r, Tokens.inkFaint.g, Tokens.inkFaint.b, hover))

    // Hover: the tile lifts 2 px, its edge darkens a little and the shadow deepens. Never a colour.
    property real hover: area.pressed ? 0.6 : area.containsMouse ? 1 : 0
    Behavior on hover { NumberAnimation { duration: Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
    transform: Translate { y: -2 * tile.hover }

    Rectangle {
        z: -1
        anchors.fill: parent
        anchors.topMargin: 4 + 2 * tile.hover
        anchors.bottomMargin: -4 - 2 * tile.hover
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        radius: tile.radius
        color: Tokens.ink
        opacity: 0.03 + 0.07 * tile.hover
    }

    // Soft tint over the surface.
    Rectangle {
        anchors.fill: parent
        radius: tile.radius
        color: Tokens.surfaceAlt
        opacity: 0.8 * tile.hover
    }

    // Behind the content: controls inside the tile take their own clicks first.
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: tile.activated(tile.tileId)
    }

    Label {
        x: 16
        y: 13
        text: tile.title
        role: Enums.TextRole.Bar
        tone: tile.severity
        color: tile.severity === Enums.Severity.Neutral ? Tokens.inkFaint : Tokens.colorFor(tile.severity)
    }

    Item {
        id: contentArea
        anchors { fill: parent; leftMargin: 16; rightMargin: 16; bottomMargin: 14; topMargin: 38 }
    }
}
