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
    // TODO(phase): dock top, centred, size of the current layer (0 at rest) on spring.notch, or the
    //   mode's sizeSpring; coves 0 → Tokens.cove over toast.coveGrow (M-06); stays under `hide`.
    readonly property BulgeSpec bulge: BulgeSpec {}
    // The rest clock's rectangle in monitor coordinates (M-20 hand-off to Today).
    // TODO(phase): the RestGroup's clockRect.
    readonly property rect clockRect: Qt.rect(0, 0, 0, 0)
    // Width the notch occupies inside the bar at rest (the bar keeps its zones clear of it).
    // TODO(phase): the rest group's width with the compact slots (≤ centreGroupMaxWidth).
    readonly property real restWidth: 0
    // The item whose area takes pointer input (bar band part plus the bulge), for the input mask.
    // TODO(phase): covers the centre group and the bulge; under `hide` only a bulge the arbitration
    //   allows (the rest group is gone); while a card is pinned the whole monitor (catcher).
    readonly property Item maskItem: null

    // How far the frame is slid out under a fullscreen window (Frame.hide, M-31): the rest group
    // leaves with the bar; passive content the arbitration allows stays above the window.
    property real hide: 0
    // The quiet bar (M-31b) and a narrow monitor (bar.md §7, §9) hide the date (MonitorShell
    // passes the Bar's own values).
    property bool quiet: false
    property bool narrow: false
    // The toast's inline reply field is open and needs the keyboard (notch.md §6): MonitorShell
    // grants it like a pinned card's.
    // TODO(phase): the shown toast's `replying`.
    readonly property bool wantsKeyboard: false

    // What the notch shows now (notch.js view): rest, hidden, toast, osd, event, card, result, mode.
    // TODO(phase): notch.js viewOf(monitor's state, _hoverCard, active monitor); changes → _sync.
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
    // TODO(phase): notch.js assignSlots of the live _activities (cached compact widths); none
    //   while an interactive mode is open; under `hide` only recording (notch.md §2, §9).
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
    // The inline reply was sent: Notifications.reply, then the toast closes.
    function _toastReplied(entry: var, text: string): void { throw new Error("not implemented"); }
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

    // TODO(phase): an Instantiator over activityComponents filling _activities (monitorName set).
    // TODO(phase): the RestGroup: monitorName, showDate = bar.clock.showDate && !narrow && !quiet,
    //   unread/unreadAllowlisted from Notifications, clockTaken = the mode's takesClock; slides
    //   out with `hide` and fades in with introProgress (M-01).
    // TODO(phase): CompactSlot left/right of the clock: hover rest → _openCard(id, false) only
    //   with notch.hoverExpand; leave → activityHover.leave Timer → _closeHoverCard; click →
    //   _openCard(id, true); middle → Activity.middleClick; right → _activityMenu.
    // TODO(phase): a Repeater of NotchLayer over _layers (gone → _layerGone): toast signals →
    //   _toastActivated/_toastDismissed/_toastReplied/_toastMenu; result card closeRequested →
    //   _dismissEntry, its hovered pauses the countdown; ActivityCard picked → _openCard.
    // TODO(phase): a mode layer: args = monitor.notchArgs (again on notchSerial), active false while
    //   leaving, closeRequested → SurfaceManager.close, clockRect = Notch.clockRect, scrim;
    //   _modeEntered/_modeLeft.
    // TODO(phase): a HoverHandler on the bulge → _bulgeHovered.
    // TODO(phase): a single-shot Timer at the shown toast's countdownLeft → _countdownTick, and
    //   one at dueEntries' next → _expire (no polling).
    // TODO(phase): the outside catcher (a MouseArea below the bar band while a card is pinned) →
    //   _outsideClicked.

    // Found by the probe (phase 5):
    // This monitor's name, and whether it is the active one (passive content and hover cards
    // show there).
    // TODO(phase): monitor.name; SurfaceManager.activeMonitor === _name.
    readonly property string _name: ""
    readonly property bool _isActive: false
    // The live activities in pager order (by priority).
    // TODO(phase): the _activities with `live`, by priority.
    readonly property var _live: []
    // Activity id → the compact look's width (the slot reports it; assignSlots measures with it).
    property var _widths: ({})
    // When the pointer last left a pinned card (0: not pinned, or under the pointer).
    property real _pinnedSince: 0
    // The current (not leaving) layer and its content item, or null.
    property NotchLayer _currentLayer: null
    property var _currentContent: null
    // The bar band's height now (slides with the intro and `hide`).
    // TODO(phase): Tokens.barHeight × introProgress × (1 − hide).
    readonly property real _barNow: 0
    // The bulge's target size (the current layer's content size; 0 at rest and hidden), its
    // animated size (spring.notch, or the mode's sizeSpring) and cove (0 → Tokens.cove).
    readonly property real _targetW: 0
    readonly property real _targetH: 0
    property real _bulgeW: 0
    property real _bulgeH: 0
    property real _cove: 0
    // The payload of a passive entry of this monitor ({} when gone: the layer keeps its last).
    function _entry(id: int): var { throw new Error("not implemented"); }
    // A compact slot reports its activity's width (into _widths).
    function _noteWidth(id: string, w: real): void { throw new Error("not implemented"); }
    // Find the current layer's item after the layers changed (_currentLayer, _currentContent).
    function _pickCurrent(): void { throw new Error("not implemented"); }
    // TODO(phase): the layers also live in a ListModel the Repeater uses, updated in place by uid
    //   (a Repeater over a JS array recreates every delegate on each change).
    // TODO(phase): slot width changes reach _noteWidth through Qt.callLater (a direct call loops
    //   _slots ↔ the slot's width).
    // TODO(phase): a layer delegate's x comes from the bulge width, not from anchors (its parent
    //   is null while the Repeater removes it).
}
