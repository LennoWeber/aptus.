import QtQuick
import qs.models
import qs.theme
import qs.components

// The on-screen indicator in the island: a symbol, a bar (or a text) and the value.
Item {
    id: osdView

    property var osd                // { kind (Enums.OsdKind), level (0..1), muted, label } or null
    property color ink
    property color inkSoft
    property color line
}
