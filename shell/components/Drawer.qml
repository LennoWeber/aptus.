// Base type of the docked drawers that are not notch modes (Deck, Overview).
import QtQuick

Item {
    property string monitorName: ""
    property bool open: false
    property var args: ({})
    property bool takesKeyboard: true
    property var keys: []

    // This drawer's part of the frame shape.
    readonly property BulgeSpec bulge: BulgeSpec {}

    signal closeRequested()
}
