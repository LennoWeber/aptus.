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
    default property alias content: holder.data

    Item {
        id: holder
        anchors.fill: parent
    }
}
