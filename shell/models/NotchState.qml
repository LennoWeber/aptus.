import QtQuick
import Quickshell

// State of the notch (the alternative to the bar): which of its three stages shows, the alert on the pill and the
// alerts waiting behind it. The pieces of the system it reports on are set from shell.qml.
Scope {
    id: root

    // What the notch reports on.
    property var battery        // BatteryState
    property var timer          // TimerState
    property var media          // MediaState
    property var capture        // CaptureState
    property var contextItems   // list from ContextState: { id, text, severity, priority, tileId }

    // Settings (notch.alerts, notch.alertSeconds, notch.mediaWings).
    property bool enabled       // the notch is the shown top element (bar.style is "notch" and it loaded)
    property bool alertsEnabled: true
    property int alertHoldMs: 4000
    property bool mediaWingsEnabled: true

    // Stage and alerts.
    property int stage                   // Enums.NotchStage
    property string openScreen           // name of the screen whose notch is open, "" when none
    property var alert                   // the alert on the pill: { id, text, severity, tileId, holdMs }, or null
    property var queue: []               // alerts waiting, oldest first
    property int queueDepth: 3

    // Bookkeeping to tell what is new.
    property int lastPopupId: -1         // newest notification popup already announced
    property string lastTrackKey: ""     // "title|artist" of the track already announced
    property bool batteryAnnounced       // the low-battery alert was given for this discharge
    property bool mediaWingsOn           // wings show while playing and stay a few seconds after a pause

    signal alertShown(var alert)
    signal opened(string screenName)
    signal closed()
}
