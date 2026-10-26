pragma Singleton
import QtQuick
import Quickshell

// The look of the island (setting island.look). The ten looks are data in theme/island-looks.json; the values
// below are those of the chosen look, resolved against the current colours of Tokens.
Singleton {
    id: root

    property string lookId: "paper"
    property string name
    property var looks                    // raw data of theme/island-looks.json: { id, name, ... } per look

    // colours: Rest = pill and alert, Open = hover panel and opened island
    property color fillRest
    property color fillOpen
    property color inkRest
    property color inkSoftRest
    property color inkOpen
    property color strokeRest
    property color strokeOpen
    property real strokeWidthRest
    property real strokeWidthOpen

    // shape
    property real radiusRest
    property real radiusOpen
    property real gap                     // distance from the top edge in px, 0 = flush with the edge
    property bool monoClock               // the time in the mono font
    property bool accentLine              // 2 px signal line at the bottom edge
}
