pragma Singleton
// Progress: progress activities (downloads, copies) from notification hints.
// Owner: S3.
import QtQuick
import Quickshell
import "js/notifications.js" as N

Singleton {
    id: root

    // [{ id, name, fraction: 0..1 | -1 (unknown), rate: string, remaining: string, cancellable: bool,
    //    cancelAction: string, source }]
    // id "n:<notification id>" for items from a notification's progress hint (source "notification");
    // cancelAction: the notification's own identifier of its cancel action ("" none).
    property var items: []
    // The service works (S3).
    readonly property bool available: true
    // A notification item is cancelled through its "cancel" action (if it offers one,
    // `cancellable`), then removed.
    function cancel(id: string): void {
        const it = items.find(i => i.id === id);
        if (!it) return;
        // Wave-2 review: the action is matched case-insensitively, so invoke the sender's own id.
        if (it.source === "notification" && it.cancellable) Notifications.activate(Number(id.substring(2)), it.cancelAction);
        remove(id);
    }
    // A notification record with a progress hint (notch.md §6 rule 4): add or update its item;
    // false once it completed (value 100) or lost the hint, so the caller toasts it.
    function fromRecord(record: var): bool {
        const id = "n:" + record.id;
        if (record.progress < 0 || record.progress >= 100) {
            remove(id);
            return false;
        }
        const cancel = record.actions.find(a => String(a.id).toLowerCase() === "cancel");
        const item = {
            id: id, name: record.summary || record.appName, fraction: record.progress / 100,
            rate: "", remaining: N.plainText(record.body), source: "notification",
            cancellable: cancel !== undefined, cancelAction: cancel !== undefined ? String(cancel.id) : ""
        };
        const list = items.slice();
        const at = list.findIndex(i => i.id === id);
        if (at >= 0) list[at] = item; else list.push(item);
        items = list;
        return true;
    }
    // Drop an item (the sender closed the notification).
    function remove(id: string): void {
        if (items.some(i => i.id === id)) items = items.filter(i => i.id !== id);
    }
}
