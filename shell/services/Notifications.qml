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
    // held by DND, focus or a fullscreen window, for the summary toast (those still in the
    // history: one the sender closed meanwhile is not summarised)
    readonly property int held: _heldIds.length
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
    // Record id → the passive entry id of its toast (replaces_id updates it in place); an entry
    // leaves it when SurfaceManager reports it gone (passiveGone).
    property var _toasts: ({})
    // The stack toast being built (notifications.js stack record) or null; null again once its
    // entry is gone.
    property var _stack: null
    // The stack for `shell state` (the e2e tests): null or { count, apps } (app names, no bodies).
    readonly property var stackInfo: _stack ? ({ count: _stack.count, apps: _stack.apps }) : null
    // Found in review: the record ids in the stack toast (a replace of one updates the stack's
    // newest line instead of joining again).
    property var _stackIds: []
    // The id of the next injected notification (counts down from -1; IPC `notch toast`).
    property int _injectSerial: -1
    // Wave-2 review: the records held since the last summary (ids; _setHistory keeps only those
    // still in the history). The summary is worded by the reason that held most of them
    // (notifications.js heldReason over their `held`), whatever was on at the shell's start.
    property var _heldIds: []
    // Source path → the confirmed copy of a notification image { dst, stamp } (stamp: the source's
    // "size mtime" when copied); a replace with an unchanged source reuses it.
    property var _copies: ({})
    // The image copies running (Runs of copyComponent; one per source at a time).
    property var _copyJobs: []

    // Found by the probe (phase 5):
    // The history limits (settings notifications.historyMax, notifications.historyDays).
    readonly property int _max: Config.get("notifications.historyMax") || 200
    readonly property int _days: Config.get("notifications.historyDays") || 7

    onHoldingChanged: {
        // Later, not here: one hold can end as another begins in the same turn (focus ends, DND
        // stays on); only a hold still ended after the turn releases.
        if (holding === "" && held > 0) Qt.callLater(() => { if (root.holding === "") root._releaseHeld(); });
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
        if (h !== history) _setHistory(h);
    }
    function markAllRead(): void { _setHistory(N.markAllRead(history)); }
    function remove(id: int): void {
        const live = _live[id];
        if (live) live.dismiss();
        _drop(id);
        _closeToast(id);
        _setHistory(N.removeRecord(history, id));
    }
    // Wave-2 review: the cleared records' toasts (and the stack toast) close, their progress
    // items go, and the held count ends (no summary of cleared notifications later).
    function clearAll(): void {
        for (const id in _toasts) _closeToast(Number(id));
        if (_stack) SurfaceManager.dismiss(_stack.passiveId);
        for (const it of Progress.items.slice()) if (it.source === "notification") Progress.remove(it.id);
        for (const id in _live) _live[id].dismiss();
        _live = {};
        _heldIds = [];
        _setHistory([]);
    }
    // A toast's passive entry left the notch (timed out, dismissed, aged out in the queue, its
    // monitor removed): SurfaceManager.passiveGone.
    function _toastGone(passiveId: int): void {
        const t = Object.assign({}, _toasts);
        let hit = false;
        for (const k in t) if (t[k] === passiveId) { delete t[k]; hit = true; }
        if (hit) _toasts = t;
        if (_stack && _stack.passiveId === passiveId) { _stack = null; _stackIds = []; }
    }
    Connections {
        target: SurfaceManager
        function onPassiveGone(monitor: string, id: int, kind: string, key: string): void {
            if (kind === "toast") root._toastGone(id);
        }
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
        if (h.length !== history.length) _setHistory(h);
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
            if (!history.some(x => x.id === record.id)) _heldIds = _heldIds.concat([record.id]);
        }
        const old = history.find(x => x.id === record.id);
        if (old && old.read && d.show !== "toast") record.read = true;
        record.image = _cacheImage(record, live);
        _setHistory(N.addToHistory(history, record, _max, _days, Date.now()));
        if (d.show === "toast" || d.show === "progress") _toast(record, d.priority, live);
    }
    // Post or update the toast of a record (stack, replaces_id).
    function _toast(record: var, priority: int, live: var): void {
        const t = Tokens.surfaces.toast;
        const timeout = N.toastTimeout(record, Config.get("notifications.timeout") || "auto", t);
        const payload = N.toastPayload(record, timeout, t.maxActions);
        const shown = live ? N.liveImage(live.image) : "";
        if (shown !== "") payload.image = shown;                 // the live image (image-data too)
        const mon = SurfaceManager.activeMonitor;
        if (_stack && _stack.count >= 2 && _stackIds.indexOf(record.id) >= 0) {
            SurfaceManager.update(_stack.passiveId, N.stackPayload(_stack, record, timeout));
            return;
        }
        const existing = _toasts[record.id];
        if (existing) {
            SurfaceManager.update(existing, payload);
            return;
        }
        if (priority < N.CRITICAL_PRIORITY) {
            const win = (Config.get("notifications.stackWindow") || 0) * 1000;
            const s = N.stackStep(_stack, record, 0, mon, Date.now(), win);
            if (s.joins) {
                _stack = s.stack;
                const tt = Object.assign({}, _toasts), ids = _stackIds.concat([record.id]);
                for (const k in tt) if (tt[k] === s.stack.passiveId) { delete tt[k]; if (ids.indexOf(Number(k)) < 0) ids.push(Number(k)); }
                _toasts = tt;
                _stackIds = ids;
                SurfaceManager.update(s.stack.passiveId, N.stackPayload(s.stack, record, timeout), mon);
                return;
            }
            const id = SurfaceManager.post("toast", payload, priority, mon, "n:" + record.id);
            s.stack.passiveId = id;
            _stack = id > 0 ? s.stack : null;          // a refused post (locked) starts no stack
            _stackIds = [record.id];
            _setToast(record.id, id);
            return;
        }
        _setToast(record.id, SurfaceManager.post("toast", payload, priority, mon, "n:" + record.id));
    }
    // The hold ended: one summary toast for the held notifications, worded by why they were held.
    function _releaseHeld(): void {
        const counts = {};
        for (const r of history) if (_heldIds.indexOf(r.id) >= 0 && r.held !== "") counts[r.held] = (counts[r.held] || 0) + 1;
        const n = held, reason = N.heldReason(counts);
        _heldIds = [];
        if (n <= 0) return;
        SurfaceManager.post("toast", N.heldPayload(n, reason, Tokens.surfaces.toast.minTimeoutMs), 0, "", "held");
    }
    // Copy the record's image into Paths.notifCache (today.md §6: it survives the sender's temp
    // files and a restart); image-data (image://qsimage) lives only with the notification, so the
    // history keeps no image for it. Returns the record's image for the history now: the confirmed
    // copy of the same source, or "" until a copy is confirmed (_copied sets it then).
    function _cacheImage(record: var, live: var): string {
        // Wave-2 review: a malformed escape in a sender's file:// URL is no image (it threw).
        const path = N.imagePath(record.image);
        record.imageSource = path;                  // not stored (N.FIELDS): which copy belongs here
        if (path === "") return "";
        if (_inCache(path)) return path;
        if (path.indexOf(Paths.notifCache + "/") === 0) return "";       // "…/notif/../x": not ours
        const known = _copies[path];
        if (!_copyJobs.some(j => j.source === path)) {
            const ext = (/\.(png|jpe?g|svg|webp|gif)$/i.exec(path) || [".png"])[0];
            const job = copyComponent.createObject(root, {
                source: path, known: known ? known.dst : "", stamp: known ? known.stamp : "",
                dst: Paths.notifCache + "/" + Math.abs(record.id) + "-" + Date.now() + ext
            });
            _copyJobs = _copyJobs.concat([job]);
        }
        return known ? known.dst : "";
    }
    // A copy job ended (its stdout: "ok", the stamp, the copy's path; nothing when it failed): the
    // records of that source get the copy, or no image when it failed.
    function _copied(job: var, text: string): void {
        _copyJobs = _copyJobs.filter(j => j !== job);
        const lines = String(text || "").split("\n");
        const ok = lines[0] === "ok" && lines[2] !== "" && (lines[2] === job.dst || lines[2] === job.known);
        const c = Object.assign({}, _copies);
        if (ok) c[job.source] = { dst: lines[2], stamp: lines[1] }; else delete c[job.source];
        _copies = c;
        const image = ok ? lines[2] : "";
        if (history.some(r => r.imageSource === job.source && r.image !== image))
            _setHistory(history.map(r => r.imageSource === job.source && r.image !== image ? Object.assign({}, r, { image: image }) : r));
        if (ok && !history.some(r => r.image === image)) _dropCopy(image);   // its records left meanwhile
        job.destroy();
    }
    // Delete one of our copies (no record uses it any more) and forget it as a source's copy.
    function _dropCopy(path: string): void {
        if (!_inCache(path)) return;
        Quickshell.execDetached(["rm", "-f", "--", path]);
        let c = null;
        for (const src in _copies) if (_copies[src].dst === path) { c = c || Object.assign({}, _copies); delete c[src]; }
        if (c) _copies = c;
    }
    // Found in review: every history change goes through here. A record that leaves (trimmed,
    // removed, replaced) takes its live Notification along (dismissed: the sender learns it is
    // gone) and its image copy (unless another record still uses it).
    function _setHistory(h: var): void {
        const kept = {}, used = {};
        for (const r of h) { kept[r.id] = true; if (r.image) used[r.image] = true; }
        let live = null;
        for (const r of history) {
            if (!kept[r.id] && _live[r.id] !== undefined) {
                live = live || Object.assign({}, _live);
                const n = live[r.id];
                delete live[r.id];
                n.dismiss();
            }
            if (r.image && !used[r.image]) _dropCopy(r.image);
        }
        if (live) _live = live;
        if (_heldIds.some(id => !kept[id])) _heldIds = _heldIds.filter(id => kept[id]);
        history = h;
        _changed();
    }
    // A file directly in Paths.notifCache (one of our copies; a sender's "…/notif/../x" is not).
    function _inCache(path: string): bool {
        const i = path.lastIndexOf("/");
        return i > 0 && path.substring(0, i) === Paths.notifCache && path.length > i + 1 && path.charAt(i + 1) !== ".";
    }
    // The history changed: recount unread, write the state file (debounced).
    function _changed(): void {
        const u = N.unreadInfo(history, Config.get("notifications.allowlist") || []);
        unread = u.unread;
        unreadAllowlisted = u.allowlisted;
        saveTimer.restart();
    }

    // The toast of a record is now the passive entry `passiveId` (0: the post was refused).
    function _setToast(recordId: int, passiveId: int): void {
        if (passiveId <= 0) return;
        const t = Object.assign({}, _toasts);
        t[recordId] = passiveId;
        _toasts = t;
    }
    // Close a record's toast (sender close, activation, dismissal); the record stays in history.
    function _closeToast(recordId: int): void {
        const p = _toasts[recordId];
        if (p !== undefined) SurfaceManager.dismiss(p);
    }
    // Forget a record's live Notification (the sender closed it, or it was dismissed): the record
    // stays in the history without actions.
    function _drop(id: int): void {
        if (_live[id] === undefined) return;
        const live = Object.assign({}, _live);
        delete live[id];
        _live = live;
        history = history.map(r => r.id === id && r.live ? Object.assign({}, r, { live: false }) : r);
    }

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

    // One image copy (_cacheImage). An unchanged source whose copy is still there is reused (no
    // copy); a source that vanished keeps the copy made of it; otherwise only a regular file of at
    // most IMAGE_MAX_BYTES is copied, for a few seconds at most (any session-bus client names the
    // path: no device, FIFO or huge file). Prints "ok", the stamp and the copy's path.
    Component {
        id: copyComponent
        Run {
            id: job
            property string source
            property string known
            property string stamp
            property string dst
            command: ["sh", "-c",
                'mkdir -p "$1" || exit 1; s=""; [ -f "$2" ] && s=$(stat -L -c "%s %Y" -- "$2"); '
                + 'if [ -n "$3" ] && [ -f "$3" ] && { [ -z "$s" ] || [ "$s" = "$4" ]; }; then printf "ok\\n%s\\n%s\\n" "$4" "$3"; exit 0; fi; '
                + '[ -n "$s" ] && [ "${s%% *}" -le "$6" ] && timeout 5 cp -f -- "$2" "$5" && printf "ok\\n%s\\n%s\\n" "$s" "$5" && exit 0; '
                + 'rm -f -- "$5"; exit 1',
                "sh", Paths.notifCache, source, known, stamp, dst, String(N.IMAGE_MAX_BYTES)]
            // a run that could not start is a failed copy ("")
            onFinished: (stdout, stderr, code) => root._copied(job, stdout)
            Component.onCompleted: start()
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
            // image copies older than the history's days belong to no record any more
            Quickshell.execDetached(["sh", "-c", '[ -d "$1" ] && find "$1" -maxdepth 1 -type f -mtime "+$2" -delete',
                                     "sh", Paths.notifCache, String(root._days)]);
        }
    }
    // P-20: who owns org.freedesktop.Notifications on this session bus.
    Run {
        id: whoOwns
        command: ["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications", "--object-path",
            "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.GetServerInformation"]
        onFinished: (stdout, stderr, code) => {
            if (code < 0) return;                       // no gdbus: nothing known
            root.serverActive = /quickshell/i.test(stdout);
            if (!root.serverActive) Log.warn("service.notifications", "another server owns org.freedesktop.Notifications: " + stdout.trim());
        }
    }
    Timer { interval: 1500; running: true; onTriggered: whoOwns.start() }
}
