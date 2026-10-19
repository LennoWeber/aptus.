import QtQuick

// Pick the session.
// Phase 2/3/4 skeleton. Body comes in phase 7.
Item {
    // TODO(phase 7): small and quiet; remembers the last session.

    property var sessions  // list of SessionInfo
    property string selectedSession
    signal sessionSelected(string sessionId)
}
