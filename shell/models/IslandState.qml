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

    signal alertShown(var alert)
    signal opened(string screenName, int view)
    signal closed()
}
