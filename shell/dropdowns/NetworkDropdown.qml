import QtQuick

// Content of the network dropdown.
// Phase 2/3/4 skeleton. Body comes in phase 7.
Item {
    // TODO(phase 7): Wi-Fi switch, known networks, current connection, link to the Network tile.

    property var networkState
    signal moreRequested(int tileId)  // opens the control center on a tile
}
