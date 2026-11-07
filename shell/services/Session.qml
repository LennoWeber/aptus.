pragma Singleton
// Session: lock state, PAM, fingerprint, logout path, polkit agent, lid (logind inhibitors).
// Owner: S6. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // TODO(phase): until S6 fills this service, each action method logs "not available yet"
    //   (category service.<name>) instead of throwing (phase-1 decision 6).

    property bool locked: false
    property bool loggingOut: false
    property bool lidClosed: false

    // Lock now (Super+L, IPC, idle, lid).
    // The lock screen exists (S6 binds it); until then `session lock` answers an error so Super+L
    // falls back to hyprlock.
    readonly property bool canLock: false

    function lock(): void { throw new Error("Session.lock: not implemented"); }
    // The graceful logout of surfaces/session.md §3, without the countdown when called from a key.
    function logout(): void { throw new Error("Session.logout: not implemented"); }
    function reboot(): void { throw new Error("Session.reboot: not implemented"); }
    function poweroff(): void { throw new Error("Session.poweroff: not implemented"); }
    // Only while power.allowSuspend.
    function suspend(): void { throw new Error("Session.suspend: not implemented"); }

}
