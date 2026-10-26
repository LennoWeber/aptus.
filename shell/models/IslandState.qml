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
    property var osd: null               // { kind (Enums.OsdKind), level (0..1), muted, label, detail } or null
    property int osdHoldMs: 1400

    // Alerts.
    // { id, kind (Enums.AlertKind), text, detail, severity, tileId, holdMs, appName, appIcon, image, body, album,
    //   actions [{ id, label }], notificationId, progress (0..1, -1 = none), playing } or null
    property var alert: null
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
        hoverIn.stop()
        hoverOut.stop()
        osdHold.stop()
        openedByHover = false
        osd = null
        openScreen = screenName
        root.view = view
        stage = Enums.IslandStage.Open
        hold.stop()
        opened(screenName, view)
    }

    // Back to rest, or to the alert that waits.
    function close(): void {
        hoverIn.stop()
        hoverOut.stop()
        if (stage !== Enums.IslandStage.Open) return
        openedByHover = false
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
    function showOsd(kind: int, level: real, muted: bool, label: string, detail: string): void {
        if (kind < Enums.OsdKind.Volume || kind > Enums.OsdKind.Caffeine) throw new Error("invariant: IslandState.showOsd: unknown OSD kind")
        if (!enabled || stage === Enums.IslandStage.Open || morph !== Enums.MorphTarget.None) return
        // TODO(phase 7, alerts): store `detail` (the device line) in the indicator data.
        osd = { kind: kind, level: Math.max(0, Math.min(1, level)), muted: muted, label: label || "" }
        hold.stop()
        hoverIn.stop()
        stage = Enums.IslandStage.Osd
        osdHold.restart()
        osdShown(osd)
    }

    // The indicator ends: back to the alert that waits, else to rest.
    function endOsd(): void {
        osdHold.stop()
        osd = null
        if (stage !== Enums.IslandStage.Osd) return
        stage = alert ? Enums.IslandStage.Alert : Enums.IslandStage.Rest
        if (alert) {
            hold.interval = alert.holdMs
            hold.restart()
        }
    }

    // The pointer rests on the island of that screen: open Home after hoverInMs (only while hoverEnabled and at rest).
    function hoverEnter(screenName: string): void {
        if (!enabled || !hoverEnabled || morph !== Enums.MorphTarget.None) return
        hoverOut.stop()
        if (stage !== Enums.IslandStage.Rest) return
        pendingHoverScreen = screenName
        hoverIn.restart()
    }

    // The pointer left the island of that screen: close after hoverOutMs when it was opened by hover and not used.
    function hoverLeave(screenName: string): void {
        hoverIn.stop()
        if (stage === Enums.IslandStage.Open && openedByHover && openScreen === screenName) hoverOut.restart()
    }

    // The card of that screen was used (a click, a section opened): it stays until Esc or a click elsewhere.
    function keepOpen(screenName: string): void {
        if (stage !== Enums.IslandStage.Open || openScreen !== screenName || !openedByHover) return
        hoverOut.stop()
        openedByHover = false
    }

    // severity: Enums.Severity. Critical goes first; the rest waits its turn (at most queueDepth, oldest dropped).
    // TODO(phase 7, alerts): build the alert as Enums.AlertKind.Plain with the new fields (appName, appIcon, image ... empty, progress -1)
    // // and hand it to the same queue as pushRichAlert.
    function pushAlert(id: string, text: string, detail: string, severity: int, tileId: int): void {
        if (!enabled || !alertsEnabled) return
        const a = { id: id, text: text, detail: detail, severity: severity, tileId: tileId, holdMs: alertHoldMs }
        // TODO(phase 7, alerts): an update of the shown alert (progress of a download, the next track) must replace its fields in place, not restart the grow.
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

    // Push an alert with a card: kind is Enums.AlertKind, data holds the fields of IslandState.alert beyond id, kind, severity and tileId
    // (text, detail, appName, appIcon, image, body, album, actions, notificationId, progress, playing, holdMs).
    function pushRichAlert(id: string, kind: int, severity: int, tileId: int, data: var): void {
        if (id === "") throw new Error("invariant: IslandState.pushRichAlert: empty alert id")
        if (severity < Enums.Severity.Neutral || severity > Enums.Severity.Critical) throw new Error("invariant: IslandState.pushRichAlert: unknown severity")
        if (data && data.progress !== undefined && (data.progress < -1 || data.progress > 1)) throw new Error("invariant: IslandState.pushRichAlert: progress must be -1 (none) or 0..1")
        if (data && data.holdMs !== undefined && !(data.holdMs > 0)) throw new Error("invariant: IslandState.pushRichAlert: holdMs must be positive")
        if (data && data.actions !== undefined && !Array.isArray(data.actions)) throw new Error("invariant: IslandState.pushRichAlert: actions must be a list")
        throw new Error("not implemented")
    }

    // The pointer is on the alert card: it stays while paused is true, and goes a moment after the pointer left.
    // TODO(phase 7, alerts): stop the hold while paused; when it is released, a short last hold (at most 1.8 s).
    function pauseAlert(paused: bool): void {
        if (typeof paused !== "boolean") throw new Error("invariant: IslandState.pauseAlert: paused must be a boolean")
        throw new Error("not implemented")
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
        if (stage !== Enums.IslandStage.Open && stage !== Enums.IslandStage.Osd) {
            stage = Enums.IslandStage.Alert
            hold.interval = a.holdMs
            hold.restart()
        }
        alertShown(a)
    }

    // Enums.MorphTarget: the launcher or the control center takes the stage / gives it back.
    function setMorph(target: int): void {
        morph = target
        if (target !== Enums.MorphTarget.None) {
            hoverIn.stop()
            if (stage === Enums.IslandStage.Osd) endOsd()
            close()
        }
    }

    // The indicator stage always has its data; the hover flag only belongs to an open island; the times are positive.
    onStageChanged: {
        if (stage === Enums.IslandStage.Osd && !osd) throw new Error("invariant: IslandState: Osd stage without osd data")
        if (stage === Enums.IslandStage.Alert && !alert) throw new Error("invariant: IslandState: Alert stage without an alert")
    }
    onOpenedByHoverChanged: if (openedByHover && stage !== Enums.IslandStage.Open) throw new Error("invariant: IslandState: openedByHover outside the Open stage")
    Component.onCompleted: if (hoverInMs <= 0 || hoverOutMs <= 0 || osdHoldMs <= 0) throw new Error("invariant: IslandState: hover and indicator times must be positive")

    Timer { id: hold; onTriggered: root.dismissAlert() }
    // Resting hoverInMs on the island opens Home; leaving it for hoverOutMs closes it again when nothing was clicked.
    Timer {
        id: hoverIn
        interval: root.hoverInMs
        onTriggered: {
            root.open(root.pendingHoverScreen, Enums.IslandView.Home)
            root.openedByHover = true
        }
    }
    Timer { id: hoverOut; interval: root.hoverOutMs; onTriggered: { if (root.openedByHover) root.close() } }
    Timer { id: osdHold; interval: root.osdHoldMs; onTriggered: root.endOsd() }

    onEnabledChanged: if (!enabled) { hold.stop(); hoverIn.stop(); hoverOut.stop(); osdHold.stop(); openedByHover = false; osd = null; alert = null; queue = []; openScreen = ""; view = Enums.IslandView.Home; stage = Enums.IslandStage.Rest; morph = Enums.MorphTarget.None }
}
