import QtQuick

// Search field of the settings app.
// Phase 2/3/4 skeleton. Body comes in phase 7.
Item {
    // TODO(phase 7): always at the top; results filter live and highlight matches.

    property string query
    signal edited(string text)
}
