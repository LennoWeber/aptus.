import QtQuick
import qs.models
import qs.theme
import qs.components

// One line of news in the notch: a small mark, then the text. It replaces the time for a moment.
Item {
    id: alertLine

    property var alert              // { id, text, severity, tileId, holdMs }, or null
    property string look: "light"
    property real textWidth         // width of the text as it will be drawn, so the pill can grow to it
    property real maxWidth: 420

    signal activated(int tileId)
}
