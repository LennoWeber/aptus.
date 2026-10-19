import QtQuick

// Focus / do not disturb. The notification server holds the messages back and counts them.
QtObject {
    property bool active
    property var allowedApps: []     // reserved: app names whose notifications still pass (critical ones always pass)
    readonly property int suppressedCount: Notifications.suppressedCount

    function setActive(on: bool): void {
        active = on
    }

    function toggle(): void {
        setActive(!active)
    }
}
