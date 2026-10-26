import QtQuick
import qs.models
import qs.theme
import qs.components

// A switch of the hover panel: a glyph on a rounded tile, ink-filled when on, with a label.
Item {
    id: toggle

    property string kind
    property string label
    property bool checked
    property color ink
    property color fill       // the island's fill, for the glyph on an ink-filled tile
    property color line
    signal clicked()
}
