pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification server and history. Only ONE shell may own the D-Bus name org.freedesktop.Notifications;
// shell-switch stops the other shell first and checks the name after the start.
// Signatures only. Bodies come in phase 7.
Singleton {
    property var items               // list of NotificationItem, newest first (the history)
    property int unreadCount
    property bool doNotDisturb       // mirrors FocusState.active

    NotificationServer {
        id: server
        keepOnReload: false
        // TODO(phase 7): bodySupported, bodyMarkupSupported, actionsSupported, imageSupported true; onNotification -> notify().
    }

    function notify(item: var): void {
        if (!item) throw new Error("invariant: Notifications.notify: no notification")
        // TODO(phase 7): hold back while FocusState.active; hide the text on the lockscreen unless AppSettings.lockShowNotificationContent.
        throw new Error("not implemented")
    }

    function dismiss(notificationId: int): void {
        if (!Number.isInteger(notificationId)) throw new Error("invariant: Notifications.dismiss: notification id must be an integer")
        throw new Error("not implemented")
    }

    function clearAll(): void {
        throw new Error("not implemented")
    }

    function markAllRead(): void {
        throw new Error("not implemented")
    }

    function invoke(notificationId: int, actionId: string): void {
        if (!Number.isInteger(notificationId)) throw new Error("invariant: Notifications.invoke: notification id must be an integer")
        if (!actionId) throw new Error("invariant: Notifications.invoke: empty action id")
        throw new Error("not implemented")
    }
}
