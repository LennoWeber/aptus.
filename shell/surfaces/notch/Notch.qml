// The notch: clock at rest, compact activities, toasts, OSD, events, cards; hosts the notch modes from NotchModes (surfaces/notch.md).
// Owner: S3. Stub until its stage fills it.
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // TODO(S3): register the open mode's back() with SurfaceManager.registerBack(monitor.name, mode, fn)
    //   and unregister when it leaves (the host knows the surface id; the base type does not).

    property MonitorState monitor
    // 0 → 1 during the session intro (M-01); 1 otherwise.
    property real introProgress: 1
    // Notch-mode id → Component (from qs.registry NotchModes, passed in by MonitorShell so the
    // notch never imports the registry).
    property var modeComponents: ({})
    // Activity id → Component and card id → Component (qs.registry Activities, via MonitorShell).
    property var activityComponents: ({})
    property var cardComponents: ({})
    // The notch's part of the frame shape.
    readonly property BulgeSpec bulge: BulgeSpec {}
    // The rest clock's rectangle in monitor coordinates (M-20 hand-off to Today).
    readonly property rect clockRect: Qt.rect(0, 0, 0, 0)
    // Width the notch occupies inside the bar at rest (the bar keeps its zones clear of it).
    readonly property real restWidth: 0
    // The item whose area takes pointer input (bar band part plus the bulge), for the input mask.
    readonly property Item maskItem: null

    // How far the frame is slid out under a fullscreen window (Frame.hide, M-31): the rest group
    // leaves with the bar; passive content the arbitration allows stays above the window.
    property real hide: 0

    // What the notch shows now (notch.js view): rest, hidden, toast, osd, event, card, result, mode.
    readonly property var view: ({ kind: "rest", key: "", entry: null, activity: "", mode: "" })
    // The layers on screen: the current one and those still fading out (notch.js layer records).
    property var _layers: []
    property int _layerSerial: 0
    // The activity whose card is open by hover ("" none; a pinned card is monitor.notch).
    property string _hoverCard: ""
    // The pointer is over the bulge (the source for the toast countdown pause, the pinned-card
    // timeout and the hover collapse; a content item's own `hovered` only drives its looks).
    property bool _bulgeHovered: false
    // Toast countdowns by passive entry id (notch.js countdown records).
    property var _countdowns: ({})
    // The event entry shown now and since when (ms): it leaves surfaces.event.ms after it first
    // showed. (The OSD collapses osd.collapseAfter after its entry's `born`, which every post with
    // its key resets, so it needs no field here.)
    property int _eventId: 0
    property real _eventShownAt: 0
    // Activity id → this monitor's Activity object (one per registered activity).
    property var _activities: ({})
    // The compact slots after arbitration (notch.js slot assignment).
    readonly property var _slots: ({ left: "", right: "", waiting: [] })
    // The interactive mode whose back handler is registered: the one loaded now, also while it
    // still fades out after monitor.notch moved on ("" none).
    property string _mode: ""

    // The view changed: update the layers (notch.js nextLayers) and the timers of what shows.
    function _sync(): void { throw new Error("not implemented"); }
    // A layer finished fading out.
    function _layerGone(uid: int): void { throw new Error("not implemented"); }
    // Open an activity's card: by hover (transient, no keyboard) or by click (pinned).
    function _openCard(activity: string, pinned: bool): void { throw new Error("not implemented"); }
    // Close the transient (hover) card.
    function _closeHoverCard(): void { throw new Error("not implemented"); }
    // A passive entry is done (timeout, dismissal): SurfaceManager.dismiss and the toast's owner.
    function _dismissEntry(entry: var): void { throw new Error("not implemented"); }
    // A toast's inputs (notch.md §6).
    function _toastActivated(entry: var, action: string): void { throw new Error("not implemented"); }
    function _toastDismissed(entry: var): void { throw new Error("not implemented"); }
    function _toastMenu(entry: var, x: real, y: real): void { throw new Error("not implemented"); }
    // The toast menu's rows: Mute <App> for 1 hour, Turn on Do not disturb, Notification settings.
    function _toastMenuTriggered(entry: var, row: var): void { throw new Error("not implemented"); }
    // A compact activity's right-click menu (notch.md §4): the activity's own rows plus
    // "Open in Today", which the Notch handles; the others go to Activity.menuTriggered.
    function _activityMenu(activity: string, x: real, y: real): void { throw new Error("not implemented"); }
    function _activityMenuTriggered(activity: string, row: var): void { throw new Error("not implemented"); }
    // The toast countdown of the shown toast: run, pause (hover, covered), expire.
    function _countdownTick(): void { throw new Error("not implemented"); }
    // The passive timers (notch.js dueEntries): OSD collapse, event time, pinned-card timeout;
    // dismisses what is due and arms the timer for the next deadline.
    function _expire(): void { throw new Error("not implemented"); }
    // A press outside a pinned card (the Notch's own catcher, 07 §5): close the card and replay
    // focus to the window under the pointer (Hypr.windowAt, focusWindow).
    function _outsideClicked(x: real, y: real): void { throw new Error("not implemented"); }
    // An interactive mode entered / left the notch (registerBack / unregisterBack, Esc ladder).
    function _modeEntered(mode: string, item: var): void { throw new Error("not implemented"); }
    function _modeLeft(mode: string): void { throw new Error("not implemented"); }
}
