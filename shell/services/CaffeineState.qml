import QtQuick

// Caffeine: keeps the screen awake. Changes only when the user switches it manually.
QtObject {
    property bool active: Idle.caffeine   // blocks auto-lock and screen off while on

    // Manual only, never switches itself.
    function setActive(on: bool): void {
        Idle.setCaffeine(on)
    }

    function toggle(): void {
        setActive(!active)
    }
}
