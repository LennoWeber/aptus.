import QtQuick
import qs.theme

// The body of the island: hangs from the top edge when flush (only the lower corners are round: the shape reaches
// above the item, the item clips it), or floats with all corners round when the look has a gap.
Item {
    id: shape

    property real cornerRadius
    property color fill
    property color stroke
    property real strokeWidth
    property bool floating                // all four corners round
    property color accent                 // colour of the signal line, only when IslandLook.accentLine
    property real accentOpacity
    property bool glassEdge               // the lit edge and the sheen of the glass style
    property color edgeColor              // colour of the lit edge
    property real edgeLight               // 0..1, how strong the sheen is
    default property alias content: holder.data

    clip: !floating

    Behavior on fill { ColorAnimation { duration: Tokens.durSlow } }
    Behavior on stroke { ColorAnimation { duration: Tokens.durSlow } }

    Rectangle {
        x: 0
        y: shape.floating ? 0 : -shape.cornerRadius
        width: shape.width
        height: shape.height + (shape.floating ? 0 : shape.cornerRadius)
        radius: shape.cornerRadius
        color: shape.fill
        border.width: shape.strokeWidth
        border.color: shape.stroke
    }

    // The glass style: a sheen from the top edge, in the shape of the fill.
    Rectangle {
        visible: shape.glassEdge
        x: 0
        y: shape.floating ? 0 : -shape.cornerRadius
        width: shape.width
        height: shape.height + (shape.floating ? 0 : shape.cornerRadius)
        radius: shape.cornerRadius
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(shape.edgeColor.r, shape.edgeColor.g, shape.edgeColor.b, shape.edgeLight) }
            GradientStop { position: 0.6; color: Qt.rgba(shape.edgeColor.r, shape.edgeColor.g, shape.edgeColor.b, 0) }
        }
    }

    // The signal line: the one place the island shows colour by itself, and only while something is serious.
    Rectangle {
        visible: IslandLook.accentLine
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        width: Math.max(0, parent.width - 2 * shape.cornerRadius)
        height: 2
        radius: 1
        color: shape.accent
        opacity: shape.accentOpacity
        Behavior on color { ColorAnimation { duration: Tokens.durFast } }
        Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
    }

    Item {
        id: holder
        anchors.fill: parent
    }
}
