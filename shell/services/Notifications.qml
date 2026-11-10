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
    // TODO(phase): true once the server and the policy run (Ipc `notch toast` then answers ok).
    readonly property bool available: false

    // TODO(phase): the NotificationServer (actions, images, body markup and hyperlinks, inline
    //   reply, persistence, extraHints ["value"] for progressOf; keepOnReload true) → _arrive.
    // TODO(phase): an Instantiator over its tracked notifications: property changes of a replace
    //   (replaces_id) → _arrive, coalesced; `closed` by the sender → _senderClosed.
    // TODO(phase): a FileView on Paths.notificationsState, written 2 s after a change (_changed).
    // TODO(phase): `holding` from Focus.running, Dnd.on and the active monitor's fullscreen
    //   (unless notch.overFullscreen is "all"); when it clears with held > 0 → _releaseHeld.

    // Today's list, newest first (≤ notifications.historyMax): notifications.js records
    property var history: []
    property int unread: 0
    // an unread one is from an allowlisted app
    property bool unreadAllowlisted: false
    // held by DND, focus or a fullscreen window, for the summary toast
    property int held: 0
    // aptus owns org.freedesktop.Notifications
    // TODO(phase): NotificationServer reports no ownership: a one-shot GetServerInformation call
    //   (gdbus) after start; true when the answer names Quickshell (P-20).
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
    // TODO(phase): only under Paths.test (07 §7: test only); a record from the JSON fields
    //   (appName, summary, body, urgency, actions, image) with the next _injectSerial id, through
    //   _receive with no live object.
    function inject(payload: var): void {
        // Invariant (phase 6): fake notifications exist only in a test shell.
        if (!Paths.test) { Log.warn("service.notifications", "inject refused outside the test"); return; }
        Log.info("service.notifications", "inject: not available yet");
    }

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
    // Copy the record's image into Paths.notifCache (today.md §6: it survives the sender's temp
    // files and a restart); image-data (image://qsimage) is grabbed to a PNG there.
    function _cacheImage(record: var, live: var): void { throw new Error("not implemented"); }
    // The history changed: recount unread, write the state file (debounced).
    function _changed(): void { throw new Error("not implemented"); }

    // Found by the probe (phase 5):
    // The history limits (settings notifications.historyMax, notifications.historyDays).
    // TODO(phase): Config.get with these defaults until Config has loaded.
    readonly property int _max: 200
    readonly property int _days: 7
    // The toast of a record is now the passive entry `passiveId` (posted or updated in place).
    function _setToast(recordId: int, passiveId: int): void { throw new Error("not implemented"); }
    // Close a record's toast (sender close, activation, dismissal); the record stays in history.
    function _closeToast(recordId: int): void { throw new Error("not implemented"); }
    // Forget a record (history trim, removeRecord): its toast and its image copy too.
    function _drop(id: int): void { throw new Error("not implemented"); }
    // The monitor holding a passive entry ("" none).
    function _monitorOf(passiveId: int): string { throw new Error("not implemented"); }
    // The passive entry still exists (rules.expire can drop a toast entry without telling us).
    function _alive(passiveId: int): bool { throw new Error("not implemented"); }
    // TODO(phase): image-data hints (image://qsimage) have no file to copy: the toast shows the
    //   live image, the history keeps no image for them (today.md §6).
}
