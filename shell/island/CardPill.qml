import QtQuick
import qs.models
import qs.theme
import qs.components

// A switch of the opened card: glyph and label in a pill (round: the glyph only). `open` marks the one whose list is shown below.
Item {
    id: pill

    property string kind
    property string label
    property bool checked
    property bool open
    property bool round
    property color ink
    property color fill       // the card's fill, for the glyph on an ink-filled pill
    property color line
    signal clicked()

    implicitWidth: round ? 44 : row.implicitWidth + 22
    implicitHeight: round ? 44 : 34

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: pill.checked ? pill.ink : "transparent"
        border.width: pill.open ? 2 : 1
        border.color: pill.checked || pill.open ? pill.ink : pill.line
        opacity: mouse.pressed ? 0.8 : 1
        Behavior on color { ColorAnimation { duration: Tokens.durFast } }
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        StatusGlyph { anchors.verticalCenter: parent.verticalCenter; kind: pill.kind; color: pill.checked ? pill.fill : pill.ink }
        Label {
            visible: !pill.round
            anchors.verticalCenter: parent.verticalCenter
            text: pill.label
            role: Enums.TextRole.Bar
            color: pill.checked ? pill.fill : pill.ink
            font.weight: Font.Medium
        }
    }
    MouseArea { id: mouse; anchors.fill: parent; onClicked: pill.clicked() }
}
