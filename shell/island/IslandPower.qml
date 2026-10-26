import QtQuick
import qs.models
import qs.theme
import qs.services
import qs.components

// Power view: lock, log out, restart, shut down. Never suspend or hibernate. Restart and shut down need a second tap.
Item {
    id: power

    property var lockState  // LockState
    property string armed   // id of the action waiting for its second tap
    property int selectedIndex
    property var actions    // { id, label, glyph }
    property color ink
    property color inkSoft
    property color line

    signal closeRequested()

    readonly property var defaultActions: [
        { id: "lock", label: "Lock", glyph: "lock" },
        { id: "logout", label: "Log out", glyph: "logout" },
        { id: "restart", label: "Restart", glyph: "restart" },
        { id: "shutdown", label: "Shut down", glyph: "power" }
    ]

    // Run an action; restart and shut down need a second tap within a few seconds.
    function run(actionId: string): void {
        throw new Error("not implemented")
    }

    function moveSelection(delta: int): void {
        throw new Error("not implemented")
    }

    function activateSelected(): void {
        throw new Error("not implemented")
    }

    // Reset the armed action and the selection when the view is shown.
    function reset(): void {
        throw new Error("not implemented")
    }
}
