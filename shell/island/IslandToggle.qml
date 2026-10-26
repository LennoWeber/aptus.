import QtQuick
import qs.models
import qs.theme
import qs.components

Item {
    id: toggle

    property string kind
    property string label
    property bool checked
    property color ink
    property color fill       // the island's fill, for the glyph on an ink-filled tile
    property color line
    signal clicked()

    implicitWidth: 62
    implicitHeight: 58

    Rectangle {
        id: tile
        width: parent.width
        height: 38
        radius: 12
        color: toggle.checked ? toggle.ink : "transparent"
        border.width: 1
        border.color: toggle.checked ? toggle.ink : toggle.line
        opacity: mouse.pressed ? 0.8 : 1
        Behavior on color { ColorAnimation { duration: Tokens.durFast } }
        StatusGlyph {
            anchors.centerIn: parent
            kind: toggle.kind
            color: toggle.checked ? toggle.fill : toggle.ink
        }
    }
    Label {
        anchors { top: tile.bottom; topMargin: 3; horizontalCenter: parent.horizontalCenter }
        text: toggle.label
        role: Enums.TextRole.Bar
        font.pixelSize: 10
        color: toggle.ink
        opacity: 0.7
    }
    MouseArea { id: mouse; anchors.fill: parent; onClicked: toggle.clicked() }
}
