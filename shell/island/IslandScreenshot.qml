import QtQuick
import qs.models
import qs.theme
import qs.services
import qs.components

// Screenshot view: region, screen, window, and screen recording (start and stop).
Item {
    id: shot

    property var captureState  // CaptureState
    property int selectedIndex
    property var actions       // { id, label, glyph }
    property color ink
    property color inkSoft
    property color line

    signal closeRequested()
}
