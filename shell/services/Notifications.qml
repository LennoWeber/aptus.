pragma Singleton
// Notifications: server, toasts, history, held queue, interruption policy.
// Owner: S3. Stub until its stage fills it.
import QtQuick
import Quickshell
import qs.core

Singleton {
    id: root

    // False until S3 fills this service; while false, Ipc answers "error: notifications is not
    // available yet" instead of "ok" (aptus msg exits non-zero).
    readonly property bool available: false

    // Today's list, newest first (≤ notifications.historyMax)
    property var history: []
    property int unread: 0
    // an unread one is from an allowlisted app
    property bool unreadAllowlisted: false
    // held by DND or focus, for the summary toast
    property int held: 0
    // aptus owns org.freedesktop.Notifications
    property bool serverActive: false

    // IPC `notch toast <json>` (test only): a fake notification through the real interruption policy.
    function inject(payload: var): void { Log.info("service.notifications", "inject: not available yet"); }
}
