import QtQuick

// Choose and order control center tiles.
// Phase 2/3/4 skeleton. Body comes in phase 7.
Item {
    // TODO(phase 7): drag to reorder, switch to hide; works by touch.

    property var tiles  // list of TileSpec
    signal orderChanged(var tileIds)
}
