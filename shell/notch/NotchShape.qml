import QtQuick
import qs.theme

// A body that hangs from the top edge of the screen: only the lower corners are round. The body is a rounded
// rectangle that reaches above the item; the item clips it, so the top corners are never seen.
Item {
    id: shape

    property real cornerRadius: 14
    property color fill: Tokens.surface
    property color stroke: Tokens.line
    property bool outlined: true
    default property alias content: holder.data

    clip: true

    Rectangle {
        x: 0
        y: -shape.cornerRadius
        width: shape.width
        height: shape.height + shape.cornerRadius
        radius: shape.cornerRadius
        color: shape.fill
        border.width: shape.outlined ? 1 : 0
        border.color: shape.stroke
    }

    Item {
        id: holder
        anchors.fill: parent
    }
}
