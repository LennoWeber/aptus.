pragma Singleton
// Focus: focus state machine, log, stats, quiet bar.
// Owner: S8. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool running: false
    property bool paused: false
    // Date
    property var endsAt: null
    property string intent: ""
    // the bar is quiet (focus session or Super+Shift+B)
    property bool quietBar: false
}
