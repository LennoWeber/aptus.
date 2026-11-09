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

    // The toast's actions (notch.md §6): the default action ("") or a button; dismisses unless
    // the notification is resident. Without a default action: focus the app's window.
    function activate(id: int, action: string): void { throw new Error("not implemented"); }
    // ✕ or middle click: the toast closes, the record stays in Today as read.
    function dismiss(id: int): void { throw new Error("not implemented"); }
    // The inline reply was sent.
    function reply(id: int, text: string): void { throw new Error("not implemented"); }
    // "Mute <App> for 1 hour".
    function muteApp(appName: string): void { throw new Error("not implemented"); }
    // Today (S4) and the toast: read state and removal.
    function markRead(id: int): void { throw new Error("not implemented"); }
    function markAllRead(): void { throw new Error("not implemented"); }
    function remove(id: int): void { throw new Error("not implemented"); }
    function clearAll(): void { throw new Error("not implemented"); }
    // The Notch tells that a toast's passive entry left the notch (timed out or dismissed).
    function toastGone(passiveId: int): void { throw new Error("not implemented"); }

    // A notification arrived from the server (a Quickshell Notification), or was replaced in place.
    function _arrive(n: var): void { throw new Error("not implemented"); }
    // The sender closed a notification (CloseNotification, or it expired on the sender's side):
    // its toast goes, its progress item goes (Progress.remove), the record leaves the history.
    function _senderClosed(id: int): void { throw new Error("not implemented"); }
    // The policy context now (notifications.js decide): Dnd, Focus, the active monitor's fullscreen
    // and notch.overFullscreen, the allowlist, the muted apps.
    function _context(): var { throw new Error("not implemented"); }
    // A record through the policy: Today, held, progress or a toast (live: the Notification or null).
    function _receive(record: var, live: var): void { throw new Error("not implemented"); }
    // Post or update the toast of a record (stack, replaces_id).
    function _toast(record: var, priority: int): void { throw new Error("not implemented"); }
    // The hold ended: one summary toast for the held notifications.
    function _releaseHeld(): void { throw new Error("not implemented"); }
    // The history changed: recount unread, write the state file (debounced).
    function _changed(): void { throw new Error("not implemented"); }
}
