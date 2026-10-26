import QtQuick
import qs.models
import qs.theme
import qs.services
import qs.components

// Power view: lock, log out, restart, shut down. Never suspend or hibernate. Restart and shut down need a second tap.
Item {
    id: power

    property var lockState  // LockState
    property string armed   // id of the action waiting for its second tap
    property int selectedIndex
    property var actions    // { id, label, glyph }
    property color ink
    property color inkSoft
    property color line

    signal closeRequested()
}
