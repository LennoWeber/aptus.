pragma Singleton
// Dnd: do not disturb: modes, schedule, summary.
// Owner: S8. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool on: false
    // Date or null (until turned off)
    property var until: null
}
