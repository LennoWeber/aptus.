import QtQuick

// Restart and shut down.
// Phase 2/3/4 skeleton. Body comes in phase 7.
Item {
    // TODO(phase 7): only restart and shutdown; never a sleep button.

    property var actions  // list of Enums.PowerAction
    signal actionRequested(int action)
}
