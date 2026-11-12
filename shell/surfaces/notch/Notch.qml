pragma ComponentBehavior: Bound
// The notch: clock at rest, compact activities, toasts, OSD, events, cards; hosts the notch modes from NotchModes (surfaces/notch.md).
// Owner: S3.
import QtQuick
import qs.core
import qs.services
import qs.components
import "js/notch.js" as NJ

Item {
    id: root

    property MonitorState monitor
    // 0 → 1 during the session intro (M-01); 1 otherwise.
    property real introProgress: 1
    // Notch-mode id → Component (from qs.registry NotchModes, passed in by MonitorShell so the
    // notch never imports the registry).
    property var modeComponents: ({})
    // Activity id → Component and card id → Component (qs.registry Activities, via MonitorShell).
    property var activityComponents: ({})
    property var cardComponents: ({})
    // The notch's part of the frame shape: dock top, centred, the size of the current layer (0 at
    // rest) on spring.notch; coves 0 → Tokens.cove over toast.coveGrow (M-06).
    readonly property BulgeSpec bulge: BulgeSpec {
        shown: root._bulgeW > 0.5 && root._bulgeH > 0.5
        dock: "top"
        x: (root.width - root._bulgeW) / 2
        width: root._bulgeW
        height: root._bulgeH
        cove: root._cove
        radius: Tokens.surfaceRadius
        // part of the frame at rest; floats above a fullscreen window (M-31) and casts one then
        shadow: root.hide > 0.5
    }
    // The rest clock's rectangle in monitor coordinates (M-20 hand-off to Today).
    readonly property rect clockRect: Qt.rect(centre.x + rest.x + rest.clockRect.x, centre.y + rest.clockRect.y,
                                              rest.clockRect.width, rest.clockRect.height)
    // Width the notch occupies inside the bar at rest (the bar keeps its zones clear of it).
    readonly property real restWidth: centre.width
    // The item whose area takes pointer input (bar band part plus the bulge), for the input mask:
    // the centre group and the bulge; under `hide` only the bulge; while a card is pinned the
    // whole monitor (the outside catcher).
    readonly property Item maskItem: maskArea

    // How far the frame is slid out under a fullscreen window (Frame.hide, M-31): the rest group
    // leaves with the bar; passive content the arbitration allows stays above the window.
    property real hide: 0
    // The quiet bar (M-31b) and a narrow monitor (bar.md §7, §9) hide the date (MonitorShell
    // passes the Bar's own values).
    property bool quiet: false
    property bool narrow: false

    // Found by the probe (phase 5):
    // This monitor's name.
    readonly property string _name: monitor ? monitor.name : ""
    // What the notch shows now (notch.js view): rest, hidden, toast, osd, event, card, result, mode.
    // Only SurfaceManager's state goes in (a hover card is its `card:` notch too; a toast with its
    // reply field open stays above an OSD there): _sync writes the Notch's own fields while this
    // binding notifies, so it must not read them.
    readonly property var view: monitor ? NJ.viewOf({ notch: monitor.notch, passiveTop: monitor.passiveTop })
                                        : { kind: "rest", key: "", entry: null, activity: "", mode: "" }
    // The layers on screen: the current one and those still fading out (notch.js layer records).
    property var _layers: []
    property int _layerSerial: 0
    // The activity whose card is open by hover ("" none): a `card:` notch without `pinned`.
    readonly property string _hoverCard: monitor && monitor.notch.indexOf("card:") === 0 && !monitor.notchArgs.pinned
                                         ? monitor.notch.slice(5) : ""
    // The pointer is over the bulge (the source for the toast countdown pause, the pinned-card
    // timeout and the hover collapse; a content item's own `hovered` only drives its looks).
    property bool _bulgeHovered: false
    // Toast countdowns by passive entry id (notch.js countdown records). A replace or a stack join
    // changes the entry in place (a new `rev`) and restarts its countdown (notch.md §6).
    property var _countdowns: ({})
    // The event entry shown now and since when (ms): it leaves surfaces.event.ms after it first
    // showed. (The OSD collapses osd.collapseAfter after its entry's `born`, which every post with
    // its key resets, so it needs no field here.)
    property int _eventId: 0
    property real _eventShownAt: 0
    // Activity id → this monitor's Activity object (one per registered activity).
    property var _activities: ({})
    // The live activities in pager order (by priority).
    readonly property var _live: {
        const out = [];
        for (const id in _activities) if (_activities[id] && _activities[id].live) out.push(_activities[id]);
        out.sort((a, b) => b.priority - a.priority);
        return out;
    }
    // The compact slots after arbitration (notch.js slot assignment): none while an interactive
    // mode, Overview or Capture is open; under `hide` only an activity above fullscreen
    // (recording, notch.md §2, §9).
    readonly property var _slots: {
        if (view.kind === "mode" || (monitor && (monitor.overview || monitor.capture !== null)))
            return { left: "", right: "", waiting: [] };
        const cands = _live.filter(a => hide < 0.5 || a.aboveFullscreen)
                           .map(a => ({ id: a.activity, slot: a.slot, priority: a.priority, width: _widths[a.activity] || 0 }));
        return NJ.assignSlots(cands, rest.implicitWidth, Tokens.gapBarItem, Tokens.surfaces.notch.centreGroupMaxWidth);
    }
    // The interactive mode whose back handler is registered ("" none).
    property string _mode: ""
    // Activity id → the compact look's width (the slot reports it; assignSlots measures with it).
    property var _widths: ({})
    // When the pointer last left a pinned card (0: not pinned, or under the pointer).
    property real _pinnedSince: 0
    // The content of the current (not leaving) layer, or null.
    property var _currentContent: null
    // The current (not leaving) layer and its content item, or null.
    property NotchLayer _currentLayer: null

    // The bar band's height now (slides with the intro and `hide`).
    readonly property real _barNow: Tokens.barHeight * introProgress * (1 - hide)
    // The bulge's animated size and cove.
    readonly property real _targetW: view.kind === "rest" || view.kind === "hidden" || !_currentLayer ? 0 : _currentLayer.bulgeWidth
    readonly property real _targetH: view.kind === "rest" || view.kind === "hidden" || !_currentLayer ? 0 : _currentLayer.bulgeHeight
    property real _bulgeW: _targetW
    property real _bulgeH: _targetH
    property real _cove: _targetH > 0 ? Tokens.cove : 0
    Behavior on _bulgeW { SpringAnimation { spring: Motion.springs.notch.spring; damping: Motion.springs.notch.damping; mass: Motion.springs.notch.mass; epsilon: Motion.springs.notch.epsilon } }
    Behavior on _bulgeH { SpringAnimation { spring: Motion.springs.notch.spring; damping: Motion.springs.notch.damping; mass: Motion.springs.notch.mass; epsilon: Motion.springs.notch.epsilon } }
    Behavior on _cove { NumberAnimation { duration: Motion.catalogueMs("toast.coveGrow", false) } }

    onViewChanged: _sync()
    on_BulgeHoveredChanged: _sync()
    // Found in review: a pinned card is what shows (not covered by an OSD, toast or event): only
    // then the outside catcher and the whole-monitor mask are up (rules.js pinnedShown).
    readonly property bool _pinnedShown: monitor !== null && monitor.pinnedShown
    // The pointer is over the bulge or a compact slot: a hover card stays; it collapses
    // activityHover.leave after the pointer left both.
    readonly property bool _pointerIn: _bulgeHovered || leftSlot.hovered || rightSlot.hovered
    on_PointerInChanged: if (!_pointerIn && _hoverCard !== "") leaveTimer.restart(); else leaveTimer.stop();
    Component.onCompleted: _sync()
    Connections {
        target: root.monitor
        function onPassiveChanged(): void { root._expire(); }
    }

    // The view changed: update the layers (notch.js nextLayers) and the timers of what shows.
    function _sync(): void {
        if (!monitor) return;
        const r = NJ.nextLayers(_layers, view, _layerSerial);
        _layers = r.layers;
        _layerSerial = r.serial;
        for (const l of _layers) {
            let at = -1;
            for (let i = 0; i < layerModel.count; i++) if (layerModel.get(i).uid === l.uid) { at = i; break; }
            const roles = { uid: l.uid, kind: l.kind, key: l.key, entryId: l.entryId, activity: l.activity, mode: l.mode, leaving: l.leaving };
            if (at < 0) layerModel.append(roles);
            else layerModel.set(at, roles);
        }
        if (view.kind === "event" && view.entry && view.entry.id !== _eventId) { _eventId = view.entry.id; _eventShownAt = Date.now(); }
        else if (view.kind !== "event") { _eventId = 0; _eventShownAt = 0; }
        const pinned = monitor.notch.indexOf("card:") === 0 && !!monitor.notchArgs.pinned;
        _pinnedSince = pinned && !_bulgeHovered ? (_pinnedSince || Date.now()) : 0;
        // Later, not here: _sync runs inside `view`'s change notification, and both may dismiss an
        // entry, which changes `view` again (a binding loop would leave it stale).
        Qt.callLater(root._countdownTick);
        Qt.callLater(root._expire);
    }
    // A layer finished fading out.
    function _layerGone(uid: int): void {
        _layers = NJ.dropLayer(_layers, uid);
        for (let i = 0; i < layerModel.count; i++) if (layerModel.get(i).uid === uid) { layerModel.remove(i); break; }
    }
    // Open an activity's card: by hover (transient, no keyboard) or by click (pinned).
    function _openCard(activity: string, pinned: bool): void {
        // by hover only from rest or another hover card (the pager), never over a mode or a pinned card
        // by hover only on the active monitor (05 §7; a click makes its monitor the active one)
        if (!pinned && (!Config.get("notch.hoverExpand") || (monitor.notch !== "rest" && _hoverCard === "")
                        || SurfaceManager.activeMonitor !== _name)) return;
        SurfaceManager.open("card:" + activity, { pinned: pinned }, _name);
    }
    // Close the transient (hover) card.
    function _closeHoverCard(): void {
        if (_hoverCard !== "") SurfaceManager.close("card:" + _hoverCard, _name);
    }
    // A passive entry is done (timeout, dismissal); its owner and the countdowns learn it from
    // SurfaceManager.passiveGone.
    function _dismissEntry(entry: var): void {
        if (entry) SurfaceManager.dismiss(entry.id, _name);
    }
    Connections {
        target: SurfaceManager
        function onPassiveGone(monitor: string, id: int, kind: string, key: string): void {
            if (monitor !== root._name || root._countdowns[id] === undefined) return;
            const c = Object.assign({}, root._countdowns);
            delete c[id];
            root._countdowns = c;
        }
    }
    // A toast's inputs (notch.md §6).
    function _toastActivated(entry: var, action: string): void {
        const p = entry.payload || {};
        if (p.opens === "today") {
            _dismissEntry(entry);
            SurfaceManager.open("today", {}, _name);
        } else if (p.nid) Notifications.activate(p.nid, action);
        else _dismissEntry(entry);
    }
    function _toastDismissed(entry: var): void {
        const p = entry.payload || {};
        if (p.nid) Notifications.dismiss(p.nid);
        else _dismissEntry(entry);
    }
    function _toastMenu(entry: var, x: real, y: real): void {
        const p = entry.payload || {};
        const rows = [];
        if (p.appName) rows.push({ id: "mute", label: "Mute " + p.appName + " for 1 hour", glyph: "notifications_off" });
        rows.push({ id: "dnd", label: "Turn on Do not disturb", glyph: "do_not_disturb_on", enabled: !Dnd.on });
        rows.push({ separator: true });
        rows.push({ id: "settings", label: "Notification settings", glyph: "settings" });
        SurfaceManager.openMenu(_name, { anchorX: x, anchorY: y, model: rows, owner: "notch:toast",
                                         onTriggered: row => root._toastMenuTriggered(entry, row) });
    }
    // The inline reply was sent: Notifications.reply, then the toast closes.
    function _toastReplied(entry: var, text: string): void {
        const p = entry.payload || {};
        if (p.nid) Notifications.reply(p.nid, text);
        else _dismissEntry(entry);
    }
    // The toast menu's rows: Mute <App> for 1 hour, Turn on Do not disturb, Notification settings.
    function _toastMenuTriggered(entry: var, row: var): void {
        const id = row ? row.id : "";
        if (id === "mute") { Notifications.muteApp(entry.payload.appName); _toastDismissed(entry); }
        else if (id === "dnd") Dnd.turnOn();
        else if (id === "settings") SurfaceManager.open("settings", { page: "notch" }, _name);   // notifications.* live there
    }
    // A compact activity's right-click menu (notch.md §4): the activity's own rows plus
    // "Open in Today", which the Notch handles; the others go to Activity.menuTriggered.
    function _activityMenu(activity: string, x: real, y: real): void {
        const a = _activities[activity];
        if (!a) return;
        const rows = (a.menu || []).slice();
        if (rows.length > 0) rows.push({ separator: true });
        rows.push({ id: "__today", label: "Open in Today", glyph: "today" });
        SurfaceManager.openMenu(_name, { anchorX: x, anchorY: y, model: rows, owner: "notch:activity",
                                         onTriggered: row => root._activityMenuTriggered(activity, row) });
    }
    function _activityMenuTriggered(activity: string, row: var): void {
        if (row && row.id === "__today") SurfaceManager.open("today", { activity: activity }, _name);
        else if (_activities[activity]) _activities[activity].menuTriggered(row);
    }
    // The toast countdown of the shown toast: run, pause (hover, covered), expire.
    function _countdownTick(): void {
        if (!monitor) return;
        const now = Date.now();
        const shown = (view.kind === "toast" || view.kind === "result") && view.entry ? view.entry : null;
        const c = {};
        for (const id in _countdowns)
            c[id] = !shown || Number(id) !== shown.id ? NJ.countdownPause(_countdowns[id], now) : _countdowns[id];
        let left = Infinity;
        if (shown) {
            const rev = shown.rev || 0;
            if (c[shown.id] && c[shown.id].rev !== rev) delete c[shown.id];       // changed in place
            let cd = c[shown.id] || NJ.countdownStart(shown.payload ? Number(shown.payload.timeout) || 0 : 0, now, rev);
            const held = _bulgeHovered || !!shown.replying;
            cd = held ? NJ.countdownPause(cd, now) : NJ.countdownResume(cd, now, Tokens.surfaces.toast.resumeMinMs);
            c[shown.id] = cd;
            left = held ? Infinity : NJ.countdownLeft(cd, now);
        }
        _countdowns = c;
        if (shown && left <= 0) { _dismissEntry(shown); return; }
        if (left !== Infinity) { toastTimer.interval = Math.max(1, left); toastTimer.restart(); }
        else toastTimer.stop();
    }
    // The passive timers (notch.js dueEntries): OSD collapse, event time, pinned-card timeout;
    // dismisses what is due and arms the timer for the next deadline.
    function _expire(): void {
        if (!monitor) return;
        const now = Date.now();
        const shownId = view.entry ? view.entry.id : 0;
        const d = NJ.dueEntries(monitor.passive, shownId, _eventShownAt, _pinnedSince, now, {
            osdMs: Motion.catalogueMs("osd.collapseAfter", false), eventMs: Tokens.surfaces.event.ms,
            pinnedMs: Tokens.surfaces.notch.pinnedCardTimeoutMs });
        // The timer first: a dismissal below changes the passive list and the view, which run
        // _expire again for what shows next (an event after an OSD); this call's `next` is older.
        if (d.next > 0) { expireTimer.interval = Math.max(1, d.next - now); expireTimer.restart(); }
        else expireTimer.stop();
        for (const id of d.due) SurfaceManager.dismiss(id, _name);
        if (d.card && monitor.notch.indexOf("card:") === 0) SurfaceManager.close(monitor.notch, _name);
    }
    // A press outside a pinned card (the Notch's own catcher, 07 §5): close the card and replay
    // focus to the window under the pointer (Hypr.windowAt, focusWindow).
    function _outsideClicked(x: real, y: real): void {
        if (monitor.notch.indexOf("card:") === 0) SurfaceManager.close(monitor.notch, _name);
        if (y < _barNow) return;                     // the bar takes the press itself
        const w = Hypr.windowAt(_name, x, y);
        if (w) Hypr.focusWindow(w.address);
    }
    // An interactive mode entered / left the notch (registerBack / unregisterBack, Esc ladder).
    function _modeEntered(mode: string, item: var): void {
        if (_mode !== "" && _mode !== mode) _modeLeft(_mode);
        _mode = mode;
        SurfaceManager.registerBack(_name, mode, () => item && item.back ? item.back() : false);
    }
    function _modeLeft(mode: string): void {
        if (_mode !== mode) return;
        SurfaceManager.unregisterBack(_name, mode);
        _mode = "";
    }
    // The payload of a passive entry of this monitor ({} when gone: the layer keeps its last).
    function _entry(id: int): var {
        if (!monitor) return null;
        for (const e of monitor.passive) if (e.id === id) return e;
        return null;
    }

    Timer { id: toastTimer; onTriggered: root._countdownTick() }
    Timer { id: expireTimer; onTriggered: root._expire() }
    Timer {
        id: leaveTimer
        interval: Motion.catalogueMs("activityHover.leave", false)
        onTriggered: if (!root._pointerIn) root._closeHoverCard()
    }

    // One Activity per registered activity on this monitor.
    Instantiator {
        model: Object.keys(root.activityComponents)
        delegate: QtObject {
            id: holder
            required property string modelData
            property var object: null
            Component.onCompleted: {
                const c = root.activityComponents[modelData];
                object = c ? c.createObject(root, { monitorName: root._name }) : null;
                const a = Object.assign({}, root._activities);
                a[modelData] = object;
                root._activities = a;
            }
            Component.onDestruction: {
                const a = Object.assign({}, root._activities);
                delete a[modelData];
                root._activities = a;
                if (object) object.destroy();
            }
        }
    }

    // The outside catcher while a pinned card shows. A press on the bar band closes the card and
    // goes on to the bar below (not accepted); elsewhere focus replays to the window (05 §3).
    MouseArea {
        anchors.fill: parent
        enabled: root._pinnedShown
        acceptedButtons: Qt.AllButtons
        onPressed: m => {
            root._outsideClicked(m.x, m.y);
            if (m.y < root._barNow) m.accepted = false;
        }
    }

    // The input area (mask).
    Item {
        id: maskArea
        readonly property bool _all: root._pinnedShown
        // the centre group takes input unless it left with the bar (under `hide` only a slot that
        // stays, i.e. recording, keeps it)
        readonly property bool _centre: root.hide <= 0.5 || root._slots.left !== "" || root._slots.right !== ""
        x: _all ? 0 : Math.min(_centre ? centre.x : root.width, (root.width - root._bulgeW) / 2)
        width: _all ? root.width : Math.max(_centre ? centre.x + centre.width : 0, (root.width + root._bulgeW) / 2) - x
        y: 0
        height: _all ? root.height : Math.max(root._barNow + root._bulgeH, _centre && root.hide > 0.5 ? centre.y + centre.height : 0)
    }

    // The centre group: compact slots and the rest clock. Each part slides out and fades with the
    // bar under a fullscreen window (M-31), except a slot showing recording (notch.md §2).
    // TODO(S9): where the recording compact sits when a bulge (OSD, critical toast) shows above
    // a fullscreen window.
    Row {
        id: centre
        anchors.horizontalCenter: parent.horizontalCenter
        y: (Tokens.barHeight - height) / 2 - Tokens.barHeight * (1 - root.introProgress)
        height: Tokens.barHeight
        spacing: Tokens.gapBarItem
        opacity: root.introProgress
        CompactSlot {
            id: leftSlot
            readonly property real _leave: activity && activity.aboveFullscreen ? 0 : root.hide
            opacity: 1 - _leave
            transform: Translate { y: -Tokens.barHeight * leftSlot._leave }
            side: "left"
            monitorName: root._name
            activity: root._slots.left !== "" ? root._activities[root._slots.left] || null : null
            onOpenWidthChanged: if (activity) root._noteWidth(activity.activity, openWidth)
            onHoverRested: if (activity) root._openCard(activity.activity, false)
            onClicked: if (activity) root._openCard(activity.activity, true)
            onMiddleClicked: if (activity) activity.middleClick()
            onRightClicked: (x, y) => { const p = mapToItem(null, x, y); if (activity) root._activityMenu(activity.activity, p.x, p.y); }
        }
        RestGroup {
            id: rest
            opacity: 1 - root.hide
            transform: Translate { y: -Tokens.barHeight * root.hide }
            monitorName: root._name
            showDate: !!Config.get("bar.clock.showDate") && !root.narrow && !root.quiet
            unread: Notifications.unread > 0
            unreadAllowlisted: Notifications.unreadAllowlisted
            clockTaken: root._currentContent !== null && root._currentContent.takesClock === true
        }
        CompactSlot {
            id: rightSlot
            readonly property real _leave: activity && activity.aboveFullscreen ? 0 : root.hide
            opacity: 1 - _leave
            transform: Translate { y: -Tokens.barHeight * rightSlot._leave }
            side: "right"
            monitorName: root._name
            activity: root._slots.right !== "" ? root._activities[root._slots.right] || null : null
            onOpenWidthChanged: if (activity) root._noteWidth(activity.activity, openWidth)
            onHoverRested: if (activity) root._openCard(activity.activity, false)
            onClicked: if (activity) root._openCard(activity.activity, true)
            onMiddleClicked: if (activity) activity.middleClick()
            onRightClicked: (x, y) => { const p = mapToItem(null, x, y); if (activity) root._activityMenu(activity.activity, p.x, p.y); }
        }
    }
    // A compact slot reports its activity's width (into _widths, later: _slots reads _widths, and
    // a slot's width follows _slots). Found in review: both slots can report in one turn, and
    // Qt.callLater keeps only the last arguments of one function, so the reports are collected.
    property var _pendingWidths: ({})
    function _noteWidth(id: string, w: real): void {
        if (w <= 0) return;
        const p = Object.assign({}, _pendingWidths);
        p[id] = w;
        _pendingWidths = p;
        Qt.callLater(root._flushWidths);
    }
    function _flushWidths(): void {
        let m = null;
        for (const id in _pendingWidths) if (_widths[id] !== _pendingWidths[id]) { m = m || Object.assign({}, _widths); m[id] = _pendingWidths[id]; }
        _pendingWidths = {};
        if (m) _widths = m;
    }

    // The bulge's content: one NotchLayer per layer record.
    ListModel { id: layerModel }
    Item {
        id: bulgeBox
        x: (root.width - root._bulgeW) / 2
        y: root._barNow
        width: root._bulgeW
        height: root._bulgeH
        clip: true
        HoverHandler { onHoveredChanged: root._bulgeHovered = hovered }
        Repeater {
            id: layerRep
            model: layerModel
            delegate: NotchLayer {
                id: layer
                required property int uid
                required property string kind
                required property string key
                required property int entryId
                required property string activity
                required property string mode
                required property bool leaving
                // the content keeps its own size; the bulge clips it while the spring runs
                x: (root._bulgeW - width) / 2
                width: bulgeWidth > 0 ? bulgeWidth : root._bulgeW
                height: bulgeHeight > 0 ? bulgeHeight : root._bulgeH
                record: ({ uid: uid, kind: kind, key: key, entryId: entryId, activity: activity, mode: mode, leaving: leaving })
                shown: !leaving
                monitorName: root._name
                readonly property var _e: root._entry(entryId)
                property var _lastPayload: ({})
                payload: _e ? _e.payload : _lastPayload
                on_EChanged: if (_e) _lastPayload = _e.payload
                component: kind === "mode" ? (root.modeComponents[mode] || null)
                         : kind === "result" && _e && _e.payload ? (root.cardComponents[_e.payload.card] || null) : null
                args: kind === "mode" && root.monitor ? root.monitor.notchArgs : ({})
                activities: root._live
                pinned: kind === "card" && root.monitor !== null && !!root.monitor.notchArgs.pinned
                onGoneChanged: if (gone) {
                    if (kind === "mode") root._modeLeft(mode);
                    if (layer._e && layer._e.replying) SurfaceManager.setReplying(entryId, false, root._name);
                    root._layerGone(uid);
                }
                onShownChanged: root._pickCurrent()
                onContentChanged: {
                    root._pickCurrent();
                    if (kind === "mode" && content) {
                        if ("clockRect" in content) content.clockRect = Qt.binding(() => root.clockRect);
                        root._modeEntered(mode, content);
                    }
                }
                Component.onCompleted: root._pickCurrent()
                Connections {
                    target: layer.content
                    ignoreUnknownSignals: true
                    function onActivated(action: string): void { if (layer._e) root._toastActivated(layer._e, action); }
                    function onDismissed(): void { if (layer._e) root._toastDismissed(layer._e); }
                    function onReplied(text: string): void { if (layer._e) root._toastReplied(layer._e, text); }
                    function onRightClicked(x: real, y: real): void {
                        const p = layer.content.mapToItem(null, x, y);
                        if (layer._e) root._toastMenu(layer._e, p.x, p.y);
                    }
                    function onPicked(activity: string): void { root._openCard(activity, !!root.monitor.notchArgs.pinned); }
                    function onCloseRequested(): void {
                        if (layer.kind === "mode") SurfaceManager.close(layer.mode, root._name);
                        else if (layer._e) root._dismissEntry(layer._e);
                    }
                    function onReplyingChanged(): void {
                        if (layer._e) SurfaceManager.setReplying(layer.entryId, layer.content.replying, root._name);
                        root._countdownTick();
                    }
                }
            }
        }
    }
    // Find the current layer's item after the layers changed (_currentLayer, _currentContent).
    function _pickCurrent(): void {
        let cur = null;
        for (let i = 0; i < layerRep.count; i++) {
            const l = layerRep.itemAt(i) as NotchLayer;
            if (l && l.shown) cur = l;
        }
        _currentLayer = cur;
        _currentContent = cur ? cur.content : null;
    }
}
