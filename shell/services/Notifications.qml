pragma Singleton
// Notifications: server, toasts, history, held queue, interruption policy.
// Owner: S3. Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // TODO(phase): until S3 fills this service, each action method logs "not available yet"
    //   (category service.<name>) instead of throwing (phase-1 decision 6).

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
    function inject(payload: var): void { throw new Error("Notifications.inject: not implemented"); }
}
