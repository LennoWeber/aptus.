pragma Singleton
// Switcher: Alt+Tab logic: MRU order, the 150 ms threshold, commit.
// Owner: S7. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // window addresses, most recent first
    property var mru: []
}
