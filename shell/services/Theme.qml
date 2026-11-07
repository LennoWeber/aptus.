pragma Singleton
// Theme: mode, accent, glass, auto schedule, render requests.
// Owner: S1 (mode, accent, glass via Config), S2 (aptus-theme apply). Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // JSON summary of the last aptus-theme apply
    property string lastApply: ""
    property bool applying: false
}
