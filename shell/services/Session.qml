pragma Singleton
// Session: lock state, PAM, fingerprint, logout path, polkit agent, lid (logind inhibitors).
// Owner: S6. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool locked: false
    property bool loggingOut: false
    property bool lidClosed: false
}
