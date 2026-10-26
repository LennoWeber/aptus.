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

    property string pendingHoverScreen: ""

    signal alertShown(var alert)
    signal opened(string screenName, int view)
    signal closed()

    // Open the island on a screen, showing view (Enums.IslandView). Does nothing while the bar is shown.
    function open(screenName: string, view: int): void {
        if (!enabled) return
        hoverIn.stop()
        hoverOut.stop()
        openScreen = screenName
        root.view = view
        stage = Enums.IslandStage.Open
        hold.stop()
        opened(screenName, view)
    }

    // Back to rest, or to the alert that waits.
    function close(): void {
        if (stage !== Enums.IslandStage.Open && stage !== Enums.IslandStage.Hover) return
        hoverIn.stop()
        hoverOut.stop()
        openScreen = ""
        view = Enums.IslandView.Home
        stage = alert ? Enums.IslandStage.Alert : Enums.IslandStage.Rest
        if (alert) hold.restart()
        closed()
    }

    // Close when this screen's island shows that view, else open it.
    function toggle(screenName: string, view: int): void {
        if (stage === Enums.IslandStage.Open && openScreen === screenName && root.view === view) close()
        else open(screenName, view)
    }

    // Change the view of the opened island.
    function showView(view: int): void {
        if (stage !== Enums.IslandStage.Open) throw new Error("invariant: IslandState.showView: the island is not open")
        root.view = view
    }

    // The pointer rests on the island of that screen. Only has an effect while hoverEnabled and nothing is open.
    function hoverEnter(screenName: string): void {
        if (!enabled || !hoverEnabled || morph !== Enums.MorphTarget.None) return
        hoverOut.stop()
        if (stage === Enums.IslandStage.Open) return
        if (stage === Enums.IslandStage.Hover && openScreen === screenName) return
        pendingHoverScreen = screenName
        hoverIn.restart()
    }

    // The pointer left the island of that screen.
    function hoverLeave(screenName: string): void {
        hoverIn.stop()
        if (stage === Enums.IslandStage.Hover && openScreen === screenName) hoverOut.restart()
    }

    // severity: Enums.Severity. Critical goes first; the rest waits its turn (at most queueDepth, oldest dropped).
    function pushAlert(id: string, text: string, detail: string, severity: int, tileId: int): void {
        if (!enabled || !alertsEnabled) return
        const a = { id: id, text: text, detail: detail, severity: severity, tileId: tileId, holdMs: alertHoldMs }
        if (alert && alert.id === id) { alert = a; if (stage === Enums.IslandStage.Alert) hold.restart(); return }
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
            if (stage === Enums.IslandStage.Alert) stage = Enums.IslandStage.Rest
        }
    }

    // Show an alert on the pill (an alert is: id, text, detail, severity, tileId, holdMs).
    function show(a: var): void {
        alert = a
        if (stage !== Enums.IslandStage.Open && stage !== Enums.IslandStage.Hover) {
            stage = Enums.IslandStage.Alert
            hold.interval = a.holdMs
            hold.restart()
        }
        alertShown(a)
    }

    // Enums.MorphTarget: the launcher or the control center takes the stage / gives it back.
    function setMorph(target: int): void {
        morph = target
        if (target !== Enums.MorphTarget.None) close()
    }

    Timer { id: hold; onTriggered: root.dismissAlert() }
    // Resting 280 ms on the island shows the hover panel; leaving it for 320 ms takes it back.
    Timer {
        id: hoverIn
        interval: 280
        onTriggered: {
            root.openScreen = root.pendingHoverScreen
            root.view = Enums.IslandView.Home
            root.stage = Enums.IslandStage.Hover
            hold.stop()
        }
    }
    Timer { id: hoverOut; interval: 320; onTriggered: root.close() }

    onEnabledChanged: if (!enabled) { hold.stop(); hoverIn.stop(); hoverOut.stop(); alert = null; queue = []; openScreen = ""; view = Enums.IslandView.Home; stage = Enums.IslandStage.Rest; morph = Enums.MorphTarget.None }
}
