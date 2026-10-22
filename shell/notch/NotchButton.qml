import QtQuick
import qs.models
import qs.theme
import qs.components

// A round icon button for the notch. Small to look at, 40 px to touch.
Item {
    id: button

    property string glyph: "play"       // a StatusGlyph kind
    property string look: "light"
    property bool active
    property int hitSize: 40
    property int glyphSize: 16
    signal clicked()
}
