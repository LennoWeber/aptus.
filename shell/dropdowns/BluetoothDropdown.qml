import QtQuick

// Content of the bluetooth dropdown.
// Phase 2/3/4 skeleton. Body comes in phase 7.
Item {
    // TODO(phase 7): power switch, paired devices with battery, link to the Bluetooth tile.

    property var bluetoothState
    signal moreRequested(int tileId)  // opens the control center on a tile
}
