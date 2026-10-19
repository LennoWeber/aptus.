import QtQuick

// Focus / do not disturb. Held-back notifications are counted by the notification server (next section).
QtObject {
    property bool active
    property var allowedApps: []     // app names whose notifications still pass
    property int suppressedCount     // notifications held back while active

    function setActive(on: bool): void {
        active = on
        if (!on) suppressedCount = 0
    }

    function toggle(): void {
        setActive(!active)
    }
}
