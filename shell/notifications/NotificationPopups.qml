import QtQuick
import Quickshell

// Popup notifications.
// Phase 2/3/4 skeleton. Body comes in phase 7.
PanelWindow {
    // TODO(phase 7): opaque cards under the bar, newest on top; held back while do-not-disturb is on.

    property var items  // list of NotificationItem
    property int position  // top-right | top-left | top-center
    property int durationSec

    function showItem(item: var): void {
        if (!item) throw new Error("invariant: NotificationPopups.showItem: no notification")
        throw new Error("not implemented")
    }

    function dismiss(notificationId: int): void {
        throw new Error("not implemented")
    }
}
