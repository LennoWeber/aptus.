pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.models

// Notification server and history. Only ONE shell may own the D-Bus name org.freedesktop.Notifications;
// shell-switch stops the other shell first and checks the name after the start.
// Items are plain objects: { id, appName, summary, body, icon, image, urgency, severity, timestamp, actions, read }.
Singleton {
    id: root

    property var items: []           // the history, newest first (at most 100)
    property var popupItems: []      // the cards shown on screen (at most 4), newest first
    readonly property int unreadCount: items.filter(i => !i.read).length
    property bool doNotDisturb       // mirrors FocusState.active
    property int suppressedCount     // held back while do-not-disturb is on
    property int popupDurationSec: 5
    property int hoveredId: -1       // a hovered popup does not time out
    property bool showLockContent    // AppSettings.lockShowNotificationContent
    readonly property int maxPopups: 4
    readonly property int maxHistory: 100

    // The live server objects by id (needed for actions and dismissing).
    property var live: ({})

    onDoNotDisturbChanged: if (!doNotDisturb) suppressedCount = 0

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        onNotification: n => {
            n.tracked = true
            root.receive(n)
        }
    }

    function receive(n: var): void {
        const urgency = n.urgency
        const critical = urgency === NotificationUrgency.Critical
        const actions = []
        for (const a of n.actions) actions.push({ id: a.identifier, label: a.text })
        const item = {
            id: n.id,
            appName: n.appName,
            summary: n.summary,
            body: n.body,
            icon: n.appIcon,
            image: n.image,
            urgency: urgency,
            severity: critical ? Enums.Severity.Critical : Enums.Severity.Neutral,
            timestamp: new Date(),
            actions: actions,
            read: false,
            shownUntil: n.expireTimeout === 0 || critical ? Infinity : Date.now() + (n.expireTimeout > 0 ? n.expireTimeout : popupDurationSec * 1000)
        }
        const l = live
        l[n.id] = n
        live = l
        n.closed.connect(() => root.remove(item.id))
        notify(item)
    }

    function notify(item: var): void {
        if (!item) throw new Error("invariant: Notifications.notify: no notification")
        items = [item].concat(items.filter(x => x.id !== item.id)).slice(0, maxHistory)
        // Do-not-disturb keeps the popup away, except for critical messages.
        if (doNotDisturb && item.severity !== Enums.Severity.Critical) {
            suppressedCount += 1
            return
        }
        popupItems = [item].concat(popupItems.filter(x => x.id !== item.id)).slice(0, maxPopups)
    }

    // The popup goes, the history entry stays.
    function hidePopup(notificationId: int): void {
        popupItems = popupItems.filter(x => x.id !== notificationId)
        if (hoveredId === notificationId) hoveredId = -1
    }

    function setHovered(notificationId: int, hovered: bool): void {
        if (hovered) hoveredId = notificationId
        else if (hoveredId === notificationId) hoveredId = -1
    }

    // Remove from the lists only (the sender already closed it).
    function remove(notificationId: int): void {
        items = items.filter(x => x.id !== notificationId)
        hidePopup(notificationId)
        const l = live
        delete l[notificationId]
        live = l
    }

    function dismiss(notificationId: int): void {
        if (!Number.isInteger(notificationId)) throw new Error("invariant: Notifications.dismiss: notification id must be an integer")
        const n = live[notificationId]
        remove(notificationId)
        if (n) n.dismiss()
    }

    function clearAll(): void {
        for (const i of items.slice()) dismiss(i.id)
        popupItems = []
    }

    function markAllRead(): void {
        if (unreadCount === 0) return
        items = items.map(i => Object.assign({}, i, { read: true }))
    }

    function invoke(notificationId: int, actionId: string): void {
        if (!Number.isInteger(notificationId)) throw new Error("invariant: Notifications.invoke: notification id must be an integer")
        if (!actionId) throw new Error("invariant: Notifications.invoke: empty action id")
        const n = live[notificationId]
        if (n) {
            const a = n.actions.find(x => x.identifier === actionId)
            if (a) a.invoke()
        }
        dismiss(notificationId)
    }

    Timer {
        interval: 250
        repeat: true
        running: root.popupItems.length > 0 && root.hoveredId < 0
        onTriggered: {
            const now = Date.now()
            const keep = root.popupItems.filter(p => p.shownUntil > now)
            if (keep.length !== root.popupItems.length) root.popupItems = keep
        }
    }
}
