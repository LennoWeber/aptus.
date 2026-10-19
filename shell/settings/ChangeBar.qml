import QtQuick

// Bar with the Save and Discard buttons.
// Phase 2/3/4 skeleton. Body comes in phase 7.
Item {
    // TODO(phase 7): only visible while there are unsaved changes; Save starts the 15 second confirmation.

    property bool hasUnsavedChanges
    property int changedCount
    signal saveRequested()
    signal discardRequested()
}
