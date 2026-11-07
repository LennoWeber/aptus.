pragma Singleton
// Capture: freeze, crop, save, record, colour.
// Owner: S9. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool recording: false
    // Date
    property var recordingSince: null
}
