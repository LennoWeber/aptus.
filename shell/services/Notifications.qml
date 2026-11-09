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

    // Today's list, newest first (≤ notifications.historyMax): notifications.js records
    property var history: []
    property int unread: 0
    // an unread one is from an allowlisted app
    property bool unreadAllowlisted: false
    // held by DND, focus or a fullscreen window, for the summary toast
    property int held: 0
    // aptus owns org.freedesktop.Notifications
    property bool serverActive: false

    // What holds toasts now: "" | "dnd" | "focus" | "fullscreen" (the summary's wording).
    property string holding: ""
    // App name → muted until (ms since the epoch), "Mute App for 1 hour" (notch.md §6).
    property var muted: ({})

    // Record id → the live Quickshell Notification (actions, reply, dismiss); dropped when the
    // sender closes it or the record leaves the history.
    property var _live: ({})
    // Record id → the passive entry id of its toast (replaces_id updates it in place).
    property var _toasts: ({})
    // The stack toast being built (notifications.js stack record) or null.
    property var _stack: null
    // The id of the next injected notification (counts down from -1; IPC `notch toast`).
    property int _injectSerial: -1
    // The held summary's hold reason when it started (the toast's wording when it ends).
    property string _heldReason: ""

    // IPC `notch toast <json>` (test only): a fake notification through the real interruption policy.
    function inject(payload: var): void { Log.info("service.notifications", "inject: not available yet"); }
}
