import QtQuick
import Quickshell

// State of the notch (the alternative to the bar): which of its three stages shows, the alert on the pill and the
// alerts waiting behind it. Sources push alerts in; the windows only read.
Scope {
    id: root

    // Settings (notch.alerts, notch.alertSeconds, notch.mediaWings).
    property bool enabled                // the notch is the shown top element
    property bool alertsEnabled: true
    property int alertHoldMs: 4000
    property bool mediaWingsEnabled: true

    // Stage and alerts.
    property int stage: Enums.NotchStage.Rest
    property string openScreen: ""       // name of the screen whose notch is open, "" when none
    property var alert: null             // { id, text, detail, severity, tileId, holdMs } or null
    property var queue: []               // alerts waiting, oldest first
    property int queueDepth: 3

    signal alertShown(var alert)
    signal opened(string screenName)
    signal closed()

    function open(screenName: string): void {
        if (!enabled) return
        openScreen = screenName
        stage = Enums.NotchStage.Open
        hold.stop()
        opened(screenName)
    }

    function close(): void {
        if (stage !== Enums.NotchStage.Open) return
        openScreen = ""
        stage = alert ? Enums.NotchStage.Alert : Enums.NotchStage.Rest
        if (alert) hold.restart()
        closed()
    }

    function toggle(screenName: string): void {
        if (stage === Enums.NotchStage.Open && openScreen === screenName) close()
        else open(screenName)
    }

    // severity: Enums.Severity. Critical goes first; the rest waits its turn (at most queueDepth, oldest dropped).
    function pushAlert(id: string, text: string, detail: string, severity: int, tileId: int): void {
        if (!enabled || !alertsEnabled) return
        const a = { id: id, text: text, detail: detail, severity: severity, tileId: tileId, holdMs: alertHoldMs }
        if (alert && alert.id === id) { alert = a; if (stage === Enums.NotchStage.Alert) hold.restart(); return }
        if (!alert) { show(a); return }
        if (severity === Enums.Severity.Critical && alert.severity !== Enums.Severity.Critical) {
            queue = [alert].concat(queue).slice(0, queueDepth)
            show(a)
            return
        }
        queue = queue.filter(q => q.id !== id).concat([a])
        if (queue.length > queueDepth) queue = queue.slice(queue.length - queueDepth)
    }

    function dismissAlert(): void {
        hold.stop()
        if (queue.length > 0) {
            const next = queue[0]
            queue = queue.slice(1)
            show(next)
        } else {
            alert = null
            if (stage === Enums.NotchStage.Alert) stage = Enums.NotchStage.Rest
        }
    }

    function show(a: var): void {
        alert = a
        if (stage !== Enums.NotchStage.Open) {
            stage = Enums.NotchStage.Alert
            hold.interval = a.holdMs
            hold.restart()
        }
        alertShown(a)
    }

    Timer { id: hold; onTriggered: root.dismissAlert() }

    onEnabledChanged: if (!enabled) { hold.stop(); alert = null; queue = []; openScreen = ""; stage = Enums.NotchStage.Rest }
}
