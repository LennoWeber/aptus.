import QtQuick

// One notification.
// Phase 2/3/4 skeleton. Body comes in phase 7.
Item {
    // TODO(phase 7): app name small, summary in weight, body in two lines; urgency colour only for critical.

    property var item  // NotificationItem
    signal dismissed()
    signal actionInvoked(string actionId)
}
