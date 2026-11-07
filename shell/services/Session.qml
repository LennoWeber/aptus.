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

    // Lock now (Super+L, IPC, idle, lid).
    function lock(): void { throw new Error("Session.lock: not implemented"); }
    // The graceful logout of surfaces/session.md §3, without the countdown when called from a key.
    function logout(): void { throw new Error("Session.logout: not implemented"); }
    function reboot(): void { throw new Error("Session.reboot: not implemented"); }
    function poweroff(): void { throw new Error("Session.poweroff: not implemented"); }
}
