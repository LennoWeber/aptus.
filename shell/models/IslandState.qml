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
    property string openScreen: ""       // name of the screen whose island is open, "" when none

    // Hover: the pointer resting on the island opens Home; leaving closes it again unless the card was used.
    property string pendingHoverScreen: ""
    property bool openedByHover          // the open island was opened by the pointer and nothing was clicked in it yet
    property int hoverInMs: 90           // how long the pointer rests on the island before it opens
    property int hoverOutMs: 260         // how long it must be away before it closes

    // The on-screen indicator (volume, brightness, ...): shown as a stage of the island.
    property var osd: null               // { kind (Enums.OsdKind), level (0..1), muted, label } or null
    property int osdHoldMs: 1400

    // Alerts.
    property var alert: null             // { id, text, detail, severity, tileId, holdMs } or null
    property var queue: []               // alerts waiting, oldest first
    property int queueDepth: 3

    // Enums.MorphTarget: set while the launcher or the control center is shown.
    property int morph: Enums.MorphTarget.None

    signal alertShown(var alert)
    signal osdShown(var osd)
    signal opened(string screenName, int view)
    signal closed()

    // Open the island on a screen, showing view (Enums.IslandView). Does nothing while the bar is shown.
    function open(screenName: string, view: int): void {
        if (!enabled) return
        openScreen = screenName
        root.view = view
        // TODO(phase 7): open(): stop hoverIn/hoverOut/osdHold, clear openedByHover (a click or key opened it), clear osd.
        stage = Enums.IslandStage.Open
        hold.stop()
        opened(screenName, view)
    }

    // Back to rest, or to the alert that waits.
    function close(): void {
        // TODO(phase 7): close(): also stop hoverIn/hoverOut and clear openedByHover.
        if (stage !== Enums.IslandStage.Open) return
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

    // Show the on-screen indicator on the pill: kind is Enums.OsdKind, level 0..1, label replaces the bar when not empty.
    function showOsd(kind: int, level: real, muted: bool, label: string): void {
        throw new Error("not implemented")
    }

    // The indicator ends: back to the alert that waits, else to rest.
    function endOsd(): void {
        throw new Error("not implemented")
    }

    // The pointer rests on the island of that screen: open Home after hoverInMs (only while hoverEnabled and at rest).
    function hoverEnter(screenName: string): void {
        throw new Error("not implemented")
    }

    // The pointer left the island of that screen: close after hoverOutMs when it was opened by hover and not used.
    function hoverLeave(screenName: string): void {
        throw new Error("not implemented")
    }

    // The card of that screen was used (a click, a section opened): it stays until Esc or a click elsewhere.
    function keepOpen(screenName: string): void {
        throw new Error("not implemented")
    }

    // severity: Enums.Severity. Critical goes first; the rest waits its turn (at most queueDepth, oldest dropped).
    function pushAlert(id: string, text: string, detail: string, severity: int, tileId: int): void {
        if (!enabled || !alertsEnabled) return
        const a = { id: id, text: text, detail: detail, severity: severity, tileId: tileId, holdMs: alertHoldMs }
        // TODO(phase 7): pushAlert: while stage is Osd keep the alert queued; it shows when the indicator ends (see osdHold).
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
            // TODO(phase 7): dismissAlert: leave Osd alone, only end the Alert stage.
            if (stage === Enums.IslandStage.Alert) stage = Enums.IslandStage.Rest
        }
    }

    // Show an alert on the pill (an alert is: id, text, detail, severity, tileId, holdMs).
    function show(a: var): void {
        alert = a
        // TODO(phase 7): show(): do not take the stage while it is Osd or Open.
        if (stage !== Enums.IslandStage.Open) {
            stage = Enums.IslandStage.Alert
            hold.interval = a.holdMs
            hold.restart()
        }
        alertShown(a)
    }

    // Enums.MorphTarget: the launcher or the control center takes the stage / gives it back.
    // TODO(phase 7): setMorph: a morph also ends hover and the indicator.
    function setMorph(target: int): void {
        morph = target
        if (target !== Enums.MorphTarget.None) close()
    }

    Timer { id: hold; onTriggered: root.dismissAlert() }
    // TODO(phase 7): hoverIn: onTriggered opens Home on pendingHoverScreen with openedByHover = true; hoverOut: onTriggered closes when openedByHover; osdHold: onTriggered ends the Osd stage (to Alert when one waits, else Rest).
    Timer { id: hoverIn; interval: root.hoverInMs }
    Timer { id: hoverOut; interval: root.hoverOutMs }
    Timer { id: osdHold; interval: root.osdHoldMs }

    // TODO(phase 7): reset also stops hoverIn/hoverOut/osdHold and clears openedByHover and osd.
    onEnabledChanged: if (!enabled) { hold.stop(); alert = null; queue = []; openScreen = ""; view = Enums.IslandView.Home; stage = Enums.IslandStage.Rest; morph = Enums.MorphTarget.None }
}
