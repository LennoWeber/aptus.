import QtQuick
import qs.models
import qs.theme
import qs.services
import qs.components

// Wallpaper view: the pictures come out of the island one after the other as a row of cards; the one in the middle
// is chosen with the arrow keys, the wheel or a tap, and set at once.
Item {
    id: wall

    property int selectedIndex
    property real reveal       // 0..1, how far the cards have come out of the island
    property bool active       // the view is the one shown
    property color ink
    property color inkSoft
    property color line

    signal closeRequested()
}
