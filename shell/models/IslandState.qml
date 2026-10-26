import QtQuick
import Quickshell

// State of the island (the alternative to the bar): which stage shows, what the opened island shows, the alert on the
// pill and the alerts waiting behind it, and where the island grows to while the launcher or control center is open.
// Sources push alerts in; the windows only read.
Scope {
    id: root

    // Settings (island.alerts, island.alertSeconds, island.mediaWings, island.hoverOpen).
    property bool enabled                // the island is the shown top element
    property bool alertsEnabled: true
    property int alertHoldMs: 4000
    property bool mediaWingsEnabled: true
    property bool hoverEnabled: true

    // Stage and view.
    property int stage: Enums.IslandStage.Rest
    property int view: Enums.IslandView.Home
    property string openScreen: ""       // name of the screen whose island is open or hovered, "" when none

    // Alerts.
    property var alert: null             // { id, text, detail, severity, tileId, holdMs } or null
    property var queue: []               // alerts waiting, oldest first
    property int queueDepth: 3

    // Enums.MorphTarget: set while the launcher or the control center is shown.
    property int morph: Enums.MorphTarget.None

    // The screen whose hover is about to start (set when the pointer arrives, read when the delay is over).
    property string pendingHoverScreen: ""

    signal alertShown(var alert)
    signal opened(string screenName, int view)
    signal closed()

    // Delays: the alert stays for alertHoldMs; hover starts after resting on the island and ends a moment after leaving it.
    Timer { id: hold }
    Timer { id: hoverIn; interval: 280 }
    Timer { id: hoverOut; interval: 320 }

    // Open the island on a screen, showing view (Enums.IslandView). Does nothing while the bar is shown.
    function open(screenName: string, view: int): void {
        throw new Error("not implemented")
    }

    // Back to rest, or to the alert that waits.
    function close(): void {
        throw new Error("not implemented")
    }

    // Close when this screen's island shows that view, else open it.
    function toggle(screenName: string, view: int): void {
        throw new Error("not implemented")
    }

    // Change the view of the opened island.
    function showView(view: int): void {
        throw new Error("not implemented")
    }

    // The pointer rests on the island of that screen. Only has an effect while hoverEnabled and nothing is open.
    function hoverEnter(screenName: string): void {
        throw new Error("not implemented")
    }

    // The pointer left the island of that screen.
    function hoverLeave(screenName: string): void {
        throw new Error("not implemented")
    }

    // severity: Enums.Severity. Critical goes first; the rest waits its turn (at most queueDepth, oldest dropped).
    function pushAlert(id: string, text: string, detail: string, severity: int, tileId: int): void {
        throw new Error("not implemented")
    }

    function dismissAlert(): void {
        throw new Error("not implemented")
    }

    // Show an alert on the pill (an alert is: id, text, detail, severity, tileId, holdMs).
    function show(a: var): void {
        throw new Error("not implemented")
    }

    // Enums.MorphTarget: the launcher or the control center takes the stage / gives it back.
    function setMorph(target: int): void {
        throw new Error("not implemented")
    }
}
