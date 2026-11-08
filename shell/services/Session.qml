pragma Singleton
// Session: lock state, PAM, fingerprint, logout path, polkit agent, lid (logind inhibitors).
// Owner: S6. Stub until its stage fills it.
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    property bool locked: false
    // The lock screen exists (S6 binds it); until then `session lock` answers an error so Super+L
    // falls back to hyprlock.
    readonly property bool canLock: false
    property bool loggingOut: false
    property bool lidClosed: false

    // Lock now (Super+L, IPC, idle, lid).
    function lock(): void { Log.info("service.session", "lock: not available yet"); }
    // The graceful logout of surfaces/session.md §3, without the countdown when called from a key.
    function logout(): void { Log.info("service.session", "logout: not available yet"); }
    function reboot(): void { Log.info("service.session", "reboot: not available yet"); }
    function poweroff(): void { Log.info("service.session", "poweroff: not available yet"); }
    // Only while power.allowSuspend.
    function suspend(): void { Log.info("service.session", "suspend: not available yet"); }
}
