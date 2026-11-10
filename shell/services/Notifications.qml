pragma Singleton
pragma ComponentBehavior: Bound
// Notifications: server, toasts, history, held queue, interruption policy.
// Owner: S3.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.core
import "js/notifications.js" as N

Singleton {
    id: root

    // The policy and the history work; Ipc `notch toast` answers ok.
    readonly property bool available: true

    // Today's list, newest first (≤ notifications.historyMax): notifications.js records
    property var history: []
    property int unread: 0
    // an unread one is from an allowlisted app
    property bool unreadAllowlisted: false
    // held by DND, focus or a fullscreen window, for the summary toast
    property int held: 0
    // aptus owns org.freedesktop.Notifications: NotificationServer reports no ownership, so a
    // one-shot GetServerInformation call after start answers it (P-20).
    property bool serverActive: false

    // What holds toasts now: "" | "dnd" | "focus" | "fullscreen" (the summary's wording).
    readonly property string holding: {
        if (Focus.running) return "focus";
        if (Dnd.on) return "dnd";
        const a = SurfaceManager.monitorState(SurfaceManager.activeMonitor);
        if (a && a.fullscreen && Config.get("notch.overFullscreen") !== "all") return "fullscreen";
        return "";
    }
    // App name → muted until (ms since the epoch), "Mute App for 1 hour" (notch.md §6).
    property var muted: ({})

    // Record id → the live Quickshell Notification (actions, reply, dismiss); dropped when the
    // sender closes it or the record leaves the history.
    property var _live: ({})
    // Record id → the passive entry id of its toast (replaces_id updates it in place).
    property var _toasts: ({})
    // The stack toast being built (notifications.js stack record) or null.
    property var _stack: null
    // The id of the next injected notification (counts down from -1; IPC `notch toast`).
    property int _injectSerial: -1
    // The held summary's hold reason when it started (the toast's wording when it ends).
    property string _heldReason: ""

    // Found by the probe (phase 5):
    // The history limits (settings notifications.historyMax, notifications.historyDays).
    readonly property int _max: Config.get("notifications.historyMax") || 200
    readonly property int _days: Config.get("notifications.historyDays") || 7

    onHoldingChanged: {
        if (holding !== "" && _heldReason === "") _heldReason = holding;
        else if (holding === "") {
            // Later, not here: `holding` changes while SurfaceManager applies a rules.js result
            // (the monitor's fullscreen), and a post from inside that would be overwritten by the
            // rest of the same apply (its passive list).
            const reason = _heldReason;
            if (held > 0) Qt.callLater(() => root._releaseHeld(reason));
            _heldReason = "";
        }
    }

    // IPC `notch toast <json>` (test only, 07 §7): a fake notification through the real policy.
    function inject(payload: var): void {
        if (!Paths.test) {
            Log.warn("service.notifications", "inject refused outside the test");
            return;
        }
        const p = payload || {};
        const src = { id: _injectSerial, appName: p.appName, appIcon: p.appIcon, summary: p.summary, body: p.body,
                      urgency: p.urgency === undefined ? N.NORMAL : p.urgency, image: p.image,
                      actions: p.actions || [], hints: p.hints || {}, desktopEntry: p.desktopEntry };
        _injectSerial--;
        _receive(N.makeRecord(src, Date.now()), null);
    }

    // The toast's actions (notch.md §6): the default action ("") or a button; dismisses unless
    // the notification is resident. Without a default action: focus the app's window.
    function activate(id: int, action: string): void {
        const r = history.find(x => x.id === id);
        const live = _live[id];
        if (action === "" && !(r && r.hasDefault)) {
            const w = r ? Hypr.windowForApp(r.desktopEntry, r.appName) : null;
            if (w) Hypr.focusWindow(w.address);
        } else if (live) {
            const a = (live.actions || []).find(x => x.identifier === (action === "" ? "default" : action));
            if (a) a.invoke();
        }
        if (!(r && r.resident)) _closeToast(id);
        markRead(id);
    }
    // ✕ or middle click: the toast closes, the record stays in Today as read.
    function dismiss(id: int): void {
        _closeToast(id);
        markRead(id);
    }
    // The inline reply was sent.
    function reply(id: int, text: string): void {
        const live = _live[id];
        if (live && live.hasInlineReply) live.sendInlineReply(text);
        _closeToast(id);
        markRead(id);
    }
    // "Mute <App> for 1 hour".
    function muteApp(appName: string): void {
        const m = Object.assign({}, muted);
        m[appName] = Date.now() + N.MUTE_MS;
        muted = m;
    }
    // Today (S4) and the toast: read state and removal.
    function markRead(id: int): void {
        const h = N.markRead(history, id);
        if (h !== history) { history = h; _changed(); }
    }
    function markAllRead(): void { history = N.markAllRead(history); _changed(); }
    function remove(id: int): void {
        const live = _live[id];
        if (live) live.dismiss();
        _drop(id);
        _closeToast(id);
        history = N.removeRecord(history, id);
        _changed();
    }
    function clearAll(): void {
        for (const id in _live) _live[id].dismiss();
        _live = {};
        history = [];
        _changed();
    }
    // The Notch tells that a toast's passive entry left the notch (timed out or dismissed).
    function toastGone(passiveId: int): void {
        const t = Object.assign({}, _toasts);
        let hit = false;
        for (const k in t) if (t[k] === passiveId) { delete t[k]; hit = true; }
        if (hit) _toasts = t;
        if (_stack && _stack.passiveId === passiveId) _stack = null;
    }

    // A notification arrived from the server (a Quickshell Notification), or was replaced in place.
    function _arrive(n: var): void {
        if (!n || !n.tracked) return;
        const live = Object.assign({}, _live);
        live[n.id] = n;
        _live = live;
        const r = N.makeRecord({
            id: n.id, appName: n.appName, appIcon: n.appIcon, desktopEntry: n.desktopEntry, summary: n.summary,
            body: n.body, image: n.image, urgency: n.urgency, resident: n.resident, hasInlineReply: n.hasInlineReply,
            hints: n.hints, live: true, actions: (n.actions || []).map(a => ({ id: a.identifier, text: a.text }))
        }, Date.now());
        _receive(r, n);
    }
    // The sender closed a notification (CloseNotification, or it expired on the sender's side):
    // its toast goes, its progress item goes (Progress.remove), the record leaves the history.
    function _senderClosed(id: int): void {
        _drop(id);
        _closeToast(id);
        Progress.remove("n:" + id);
        const h = N.removeRecord(history, id);
        if (h.length !== history.length) { history = h; _changed(); }
    }
    // The policy context now (notifications.js decide): Dnd, Focus, the active monitor's fullscreen
    // and notch.overFullscreen, the allowlist, the muted apps.
    function _context(): var {
        const a = SurfaceManager.monitorState(SurfaceManager.activeMonitor);
        return { dnd: Dnd.on, focus: Focus.running, fullscreen: !!(a && a.fullscreen),
                 overFullscreen: Config.get("notch.overFullscreen") || "critical",
                 allowlist: Config.get("notifications.allowlist") || [], muted: muted, now: Date.now() };
    }
    // A record through the policy: Today, held, progress or a toast (live: the Notification or null).
    function _receive(record: var, live: var): void {
        const d = N.decide(record, _context());
        if (d.show === "progress" && Progress.fromRecord(record)) return;
        if (d.show !== "progress") Progress.remove("n:" + record.id);
        if (d.show === "held") {
            record.held = d.reason;
            if (!history.some(x => x.id === record.id)) held++;
        }
        const old = history.find(x => x.id === record.id);
        if (old && old.read && d.show !== "toast") record.read = true;
        record.image = _cacheImage(record, live);
        history = N.addToHistory(history, record, _max, _days, Date.now());
        _changed();
        if (d.show === "toast" || d.show === "progress") _toast(record, d.priority, live);
    }
    // Post or update the toast of a record (stack, replaces_id).
    function _toast(record: var, priority: int, live: var): void {
        const t = Tokens.surfaces.toast;
        const timeout = N.toastTimeout(record, Config.get("notifications.timeout") || "auto", t);
        const payload = N.toastPayload(record, timeout, t.maxActions);
        if (live && live.image) payload.image = live.image;     // the live image (image-data too)
        const mon = SurfaceManager.activeMonitor;
        const existing = _toasts[record.id];
        if (existing && _alive(existing)) {
            SurfaceManager.update(existing, payload, _monitorOf(existing));
            return;
        }
        if (priority < N.CRITICAL_PRIORITY) {
            const win = (Config.get("notifications.stackWindow") || 0) * 1000;
            const stack = _stack && _alive(_stack.passiveId) ? _stack : null;
            const s = N.stackStep(stack, record, 0, mon, Date.now(), win);
            if (s.joins) {
                _stack = s.stack;
                const tt = Object.assign({}, _toasts);
                for (const k in tt) if (tt[k] === s.stack.passiveId) delete tt[k];
                _toasts = tt;
                SurfaceManager.update(s.stack.passiveId, N.stackPayload(s.stack, record, timeout), mon);
                return;
            }
            const id = SurfaceManager.post("toast", payload, priority, mon, "n:" + record.id);
            s.stack.passiveId = id;
            _stack = s.stack;
            _setToast(record.id, id);
            return;
        }
        _setToast(record.id, SurfaceManager.post("toast", payload, priority, mon, "n:" + record.id));
    }
    // The hold ended: one summary toast for the held notifications, worded by why they were held.
    function _releaseHeld(reason: string): void {
        const n = held;
        if (n <= 0) return;
        held = 0;
        SurfaceManager.post("toast", N.heldPayload(n, reason || "dnd", Tokens.surfaces.toast.minTimeoutMs), 0, "", "held");
    }
    // Copy the record's image into Paths.notifCache (today.md §6: it survives the sender's temp
    // files and a restart); image-data (image://qsimage) lives only with the notification, so the
    // history keeps no image for it. Returns the record's image for the history.
    function _cacheImage(record: var, live: var): string {
        const src = String(record.image || "");
        if (src === "" || src.indexOf("image://") === 0) return "";
        const path = src.indexOf("file://") === 0 ? decodeURIComponent(src.substring(7)) : src;
        if (path.indexOf("/") !== 0) return "";
        if (path.indexOf(Paths.notifCache + "/") === 0) return path;
        const ext = (/\.(png|jpe?g|svg|webp|gif)$/i.exec(path) || [".png"])[0];
        const dst = Paths.notifCache + "/" + Math.abs(record.id) + "-" + Date.now() + ext;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && cp -f -- "$2" "$3"', "sh", Paths.notifCache, path, dst]);
        return dst;
    }
    // The history changed: recount unread, write the state file (debounced).
    function _changed(): void {
        const u = N.unreadInfo(history, Config.get("notifications.allowlist") || []);
        unread = u.unread;
        unreadAllowlisted = u.allowlisted;
        saveTimer.restart();
    }

    // The toast of a record is now the passive entry `passiveId` (posted or updated in place).
    function _setToast(recordId: int, passiveId: int): void {
        const t = Object.assign({}, _toasts);
        t[recordId] = passiveId;
        _toasts = t;
    }
    // Close a record's toast (sender close, activation, dismissal); the record stays in history.
    function _closeToast(recordId: int): void {
        const p = _toasts[recordId];
        if (p === undefined) return;
        SurfaceManager.dismiss(p, _monitorOf(p));
        toastGone(p);
    }
    // Forget a record (history trim, removeRecord): its toast and its image copy too.
    function _drop(id: int): void {
        if (_live[id] === undefined) return;
        const live = Object.assign({}, _live);
        delete live[id];
        _live = live;
        const h = history.map(r => r.id === id && r.live ? Object.assign({}, r, { live: false }) : r);
        history = h;
    }
    // The monitor holding a passive entry ("" none).
    function _monitorOf(passiveId: int): string {
        for (const name in SurfaceManager.monitors) {
            const m = SurfaceManager.monitors[name];
            if (m && m.passive.some(e => e.id === passiveId)) return name;
        }
        return "";
    }
    // The passive entry still exists (rules.expire can drop a toast entry without telling us).
    function _alive(passiveId: int): bool { return passiveId > 0 && _monitorOf(passiveId) !== ""; }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: true
        extraHints: ["value"]
        onNotification: n => {
            n.tracked = true;
            root._arrive(n);
        }
    }
    // A replace (replaces_id) changes the tracked object in place: arrive again, coalesced.
    Instantiator {
        model: server.trackedNotifications
        delegate: Connections {
            id: watch
            required property var modelData
            property bool _queued: false
            target: modelData
            function _again(): void {
                if (_queued) return;
                _queued = true;
                Qt.callLater(() => { watch._queued = false; root._arrive(watch.modelData); });
            }
            function onSummaryChanged(): void { _again(); }
            function onBodyChanged(): void { _again(); }
            function onHintsChanged(): void { _again(); }
            function onClosed(reason: int): void {
                if (reason === NotificationCloseReason.Dismissed) root._drop(modelData.id);
                else root._senderClosed(modelData.id);
            }
        }
    }

    Timer { id: saveTimer; interval: 2000; onTriggered: stateView.setText(N.serialise(root.history) + "\n") }
    FileView {
        id: stateView
        path: Paths.notificationsState
        atomicWrites: true
        printErrors: false
        blockLoading: true
        onLoaded: {
            // A reload with keepOnReload (APTUS_DEV only, P-23) keeps the server's notifications:
            // their records keep their ids and their live objects; everything else is archived.
            const tracked = server.trackedNotifications.values;
            root.history = N.parse(text(), Date.now(), root._max, root._days, tracked.map(n => n.id));
            const live = {};
            for (const n of tracked) live[n.id] = n;
            root._live = live;
            const u = N.unreadInfo(root.history, Config.get("notifications.allowlist") || []);
            root.unread = u.unread;
            root.unreadAllowlisted = u.allowlisted;
        }
    }
    // P-20: who owns org.freedesktop.Notifications on this session bus.
    Process {
        id: whoOwns
        command: ["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications", "--object-path",
            "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.GetServerInformation"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.serverActive = /quickshell/i.test(text);
                if (!root.serverActive) Log.warn("service.notifications", "another server owns org.freedesktop.Notifications: " + text.trim());
            }
        }
    }
    Timer { interval: 1500; running: true; onTriggered: whoOwns.running = true }
}
