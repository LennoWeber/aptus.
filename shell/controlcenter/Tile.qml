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
    border.color: Tokens.line

    // Hover is a soft tint, never a colour.
    Rectangle {
        anchors.fill: parent
        radius: tile.radius
        color: Tokens.surfaceAlt
        opacity: area.pressed ? 0.9 : area.containsMouse ? 0.45 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
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
