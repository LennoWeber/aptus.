import QtQuick
import qs.models
import qs.theme
import qs.components

// The alert on the pill: a dot for how serious it is, the text, a line of detail.
Item {
    id: alertView

    property var alert        // { text, detail, severity }
    property color ink
    property color inkSoft
    signal clicked()
}
