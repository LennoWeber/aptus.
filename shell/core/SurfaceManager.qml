pragma Singleton
pragma ComponentBehavior: Bound
// The only code that opens or closes anything (07-architecture §5). Holds one MonitorState per
// monitor plus the session-wide state, enforces the transition rules, and exposes the API that
// shortcuts, IPC and surfaces call.
import QtQuick
import Quickshell
import "js/rules.js" as Rules

Singleton {
    id: root

    // Hyprland monitor name → MonitorState.
    property var monitors: ({})
    // The focused monitor (from Hypr, wired by shell.qml); notch modes, Deck, toasts open here.
    property string activeMonitor: ""
    // The focused window's address (from Hypr, wired by shell.qml).
    property string currentWindow: ""
    // Session lock (from Session, wired by shell.qml).
    property bool locked: false
    // The monitor showing the polkit prompt ("" when none); other opens queue behind it.
    property string polkitMonitor: ""
    // Requests that arrived while polkit was open: [{ op, surface, args, monitor }].
    property var pending: []
    // The window that had focus before the current interactive surface opened (address), for
    // paste-back and the away catcher's focus replay.
    property string previousWindow: ""
    // The settings window (one per session, not per monitor).
    property bool settingsOpen: false
    property var settingsArgs: ({})
    // The settings window has keyboard focus (toggle semantics of settings.md §2).
    property bool settingsFocused: false
    // Timing limits for rules.js, from Tokens (toast.staleMs, event.maxAgeMs,
    // notch.pinnedCardTimeoutMs); rules.js fills in its defaults for any that are missing.
    readonly property var limits: {
        const t = Tokens.surfaces;
        return { toastStale: t.toast?.staleMs, eventMaxAge: t.event?.maxAgeMs, pinnedCardTimeout: t.notch?.pinnedCardTimeoutMs };
    }
    // "monitor|surface" → function(): bool, registered by open surfaces for the Esc ladder.
    property var backHandlers: ({})
    // Source of passive entry ids.
    property int passiveSerial: 0
    // Hyprland monitor names with a fullscreen window on their active workspace (bound from
    // Hypr.fullscreenMonitors in shell.qml; applied through rules.setFullscreen, M-31).
    property var fullscreenMonitors: []

    signal surfaceOpened(string monitor, string surface)
    signal surfaceClosed(string monitor, string surface)
    // A passive entry left its monitor: dismissed, aged out (rules.js expiry), or the monitor was
    // removed. `kind` is the entry's ("toast" | "osd" | "event").
    signal passiveGone(string monitor, int id, string kind, string key)
    // Asks the settings window to focus itself (open but not focused, settings.md §2).
    signal settingsFocusRequested()

    // ── API (07 §5; also over IPC). Optional parameters are `var` and may be omitted: an
    // omitted typed string parameter would arrive as "undefined" (Qt 6.11, phase-3 probe).
    // `monitor` omitted or "" means the active monitor; `args` omitted means {}. ─────────────
    // Open a surface: a notch mode id, "card:<activity>", "deck", "overview", "capture",
    // "settings". Returns false when refused (locked) or queued (polkit open).
    function open(surface: string, args: var, monitor: var): bool {
        const r = _run("open", { op: "open", surface: surface, args: args || {}, monitor: _monitorFor(monitor) });
        return r.effects.some(e => e.kind === "opened" || e.kind === "settingsFocus");
    }
    function close(surface: string, monitor: var): void {
        _run("close", { op: "close", surface: surface, monitor: _monitorFor(monitor) });
    }
    // Its own key again closes it (05 §3 way out 3); the settings window is focused when open but
    // not focused (settings.md §2).
    function toggle(surface: string, args: var, monitor: var): bool {
        _run("toggle", { op: "toggle", surface: surface, args: args || {}, monitor: _monitorFor(monitor) });
        return isOpen(surface, monitor);
    }
    // The Esc ladder (05 §3): the menu, then the top surface's back handler, then the surface.
    function back(monitor: var): void {
        const name = _monitorFor(monitor);
        const m = _state.monitors[name];
        if (!m) return;
        const t = m.top;
        let stepped = false;
        if (t !== "" && t !== "menu" && !(t === "deck" && m.deckPages.length > 1)) {
            const fn = backHandlers[name + "|" + t];
            if (fn) {
                try { stepped = !!fn(); } catch (e) { Log.warn("surface", t + " back handler: " + e); }
            }
        }
        _run("back", name, stepped);
    }
    // Passive content for the notch: kind "toast" | "osd" | "event". A non-empty key replaces the
    // entry with the same key in place (one OSD per kind, replaces_id). Returns the entry id.
    // priority defaults to 0 (critical toasts pass 2, as notification urgency).
    function post(kind: string, payload: var, priority: var, monitor: var, key: var): int {
        return _run("post", kind, payload === undefined ? {} : payload, Number(priority) || 0,
                    _monitorFor(monitor), key ? String(key) : "").id;
    }
    // Change a passive entry's payload in place (stack toast growing, OSD value change). Ids are
    // unique across monitors: `monitor` omitted or "" finds the entry wherever it is.
    function update(id: int, payload: var, monitor: var): void {
        _run("update", monitor ? String(monitor) : "", id, payload);
    }
    // Remove a passive entry (toast timed out or dismissed, OSD faded); `passiveGone` follows.
    function dismiss(id: int, monitor: var): void {
        _run("dismiss", monitor ? String(monitor) : "", id);
    }
    // JSON of every MonitorState and the session-wide state (IPC `shell state`, tests).
    function state(): string {
        const s = _snapshot();
        // passive payloads stay out: they may hold notification bodies (07 §11)
        for (const n in s.monitors) {
            const m = s.monitors[n];
            m.passive = m.passive.map(e => ({ id: e.id, kind: e.kind, key: e.key, priority: e.priority, born: e.born }));
            m.passiveTop = { kind: m.passiveTop.kind, entry: m.passiveTop.entry && m.passiveTop.entry.id !== undefined ? m.passiveTop.entry.id : m.passiveTop.entry };
            m.menu = m.menu ? { owner: m.menu.owner || "" } : null;
        }
        s.global.activeMonitor = activeMonitor;
        return JSON.stringify(s);
    }
    function isOpen(surface: string, monitor: var): bool {
        return Rules.isOpen(_state.monitors[_monitorFor(monitor)] || null, _state.global, surface);
    }
    function monitorState(name: string): MonitorState { return monitors[name] || null; }

    // Menus (03 §9): one per monitor, above every surface, closed first by Esc.
    function openMenu(monitor: string, menu: var): void {
        _run("openMenu", _monitorFor(monitor), menu);
    }
    function closeMenu(monitor: string): void {
        _run("closeMenu", _monitorFor(monitor));
    }

    // Open surfaces register a back step: fn() returns true when it went back internally.
    function registerBack(monitor: string, surface: string, fn: var): void {
        const h = Object.assign({}, backHandlers);
        h[_monitorFor(monitor) + "|" + surface] = fn;
        backHandlers = h;
    }
    function unregisterBack(monitor: string, surface: string): void {
        const h = Object.assign({}, backHandlers);
        delete h[_monitorFor(monitor) + "|" + surface];
        backHandlers = h;
    }

    // The settings window reports its focus (toggle semantics of settings.md §2).
    function setSettingsFocused(focused: bool): void {
        if (focused === settingsFocused) return;
        _run("setSettingsFocused", focused);
    }

    // ── Internal ──────────────────────────────────────────────────────────────────────────
    // Keep `monitors` in step with Hypr.monitors (create, remove without animation).
    function syncMonitors(names: var): void {
        const want = Array.from(names || []).map(String);
        for (const n of want) if (!_state.monitors[n]) _run("addMonitor", n);
        for (const n in _state.monitors) if (want.indexOf(n) < 0) _run("removeMonitor", n);
        _syncActive();
        _syncFullscreen();
    }
    // Run a rules.js operation on a snapshot (its arguments between state and `now`) and apply
    // the result; returns the result.
    function _run(op: string, ...args): var {
        const s = _snapshot();
        const r = Rules[op](s.monitors, s.global, ...args, Date.now());
        _apply(r);
        return r;
    }
    // Make a rules.js result the state: it becomes `_state` at once, then the MonitorState objects
    // and the session properties follow field by field, then the signals of its effects. A
    // subscriber may run another operation from inside (a field's change handler dismisses an
    // entry, posts a toast): that one starts from `_state`, applies in full, and this apply stops
    // writing (its changes are in the newer result already); its effects are still emitted.
    function _apply(result: var): void {
        const serial = ++_applySerial;
        const g = result.global;
        _state = { monitors: result.monitors, global: g };
        // one MonitorState per monitor of the result first (a new one starts with the defaults,
        // which a nested apply then sees too), the fields after
        let map = monitors, changed = false;
        const gone = [];
        for (const n in result.monitors) if (!map[n]) {
            if (!changed) { map = Object.assign({}, map); changed = true; }
            map[n] = stateComp.createObject(root, { name: n });
        }
        for (const n in map) if (!(n in result.monitors)) {
            if (!changed) { map = Object.assign({}, map); changed = true; }
            gone.push(map[n]);
            delete map[n];
        }
        if (changed) monitors = map;
        for (const m of gone) m.destroy();
        const live = () => serial === _applySerial;
        if (live() && polkitMonitor !== g.polkitMonitor) polkitMonitor = g.polkitMonitor;
        if (live() && !_same(pending, g.pending)) pending = g.pending;
        if (live() && previousWindow !== g.previousWindow) previousWindow = g.previousWindow;
        if (live() && settingsArgs !== g.settingsArgs) settingsArgs = g.settingsArgs;
        if (live() && settingsFocused !== g.settingsFocused) settingsFocused = g.settingsFocused;
        if (live() && settingsOpen !== g.settingsOpen) settingsOpen = g.settingsOpen;
        if (live()) passiveSerial = g.passiveSerial;
        for (const n in result.monitors) {
            const m = map[n], src = result.monitors[n];
            // args before the mode, so a surface reacting to `notch` sees its new args
            for (const f of _fields) {
                if (!live()) break;
                if (!_same(m[f], src[f])) m[f] = src[f];
            }
        }
        // the next entry that ages out without an operation (rules.nextDeadline): one timer, no
        // polling (an overtaking apply has armed it for the newer state)
        if (live()) {
            const due = Rules.nextDeadline(result.monitors, g);
            if (due) { expiry.interval = Math.max(1, due - Date.now()); expiry.restart(); }
            else expiry.stop();
        }
        for (const e of result.effects) {
            if (e.kind === "opened") surfaceOpened(e.monitor, e.surface);
            else if (e.kind === "closed") surfaceClosed(e.monitor, e.surface);
            else if (e.kind === "passiveGone") passiveGone(e.monitor, e.id, e.surface, e.key);
            else if (e.kind === "settingsFocus") settingsFocusRequested();
            else Log.info("surface", e.kind + " " + e.surface + (e.monitor ? " on " + e.monitor : ""));
        }
    }
    // rules.js copies passive, deckPages and builds passiveTop anew on every operation: compare
    // plain objects and arrays by content, two levels deep (a passive entry's payload, a menu's
    // callback by reference), so an unchanged field fires no change signal.
    function _same(a: var, b: var): bool {
        return _sameAt(a, b, 2);
    }
    function _sameAt(a: var, b: var, depth: int): bool {
        if (a === b) return true;
        if (depth === 0 || !a || !b || typeof a !== "object" || typeof b !== "object"
                || Array.isArray(a) !== Array.isArray(b)) return false;
        const ka = Object.keys(a), kb = Object.keys(b);
        if (ka.length !== kb.length) return false;
        for (const k of ka) if (!(k in b) || !_sameAt(a[k], b[k], depth - 1)) return false;
        return true;
    }
    // Plain-object snapshot of the current state for rules.js: the last result (`_state`, never the
    // MonitorState objects, which may be half-written), each monitor a shallow copy.
    function _snapshot(): var {
        const ms = {};
        for (const n in _state.monitors) ms[n] = Object.assign({}, _state.monitors[n]);
        // the session state as rules.js last left it, plus the inputs that do not go through an
        // operation (the lock and the active monitor do: their change handlers run setLocked/setActive
        // on the state before)
        const g = Object.assign({}, _state.global, { pending: Array.from(_state.global.pending), currentWindow: currentWindow,
            limits: limits, overFullscreen: Config.loaded ? Config.get("notch.overFullscreen") : "critical" });
        return { monitors: ms, global: g };
    }
    function _monitorFor(monitor: var): string {
        return monitor === undefined || monitor === null || monitor === "" || monitor === "undefined" ? activeMonitor : String(monitor);
    }

    // The last rules.js result, the state every operation starts from: { monitors: { name: plain
    // monitor state }, global } (07 §5).
    property var _state: ({ monitors: {}, global: Rules.newGlobal({}) })
    // Bumped by every _apply; an apply that a nested one overtook stops writing.
    property int _applySerial: 0
    // The MonitorState fields copied from a rules.js result, in order (_apply).
    readonly property var _fields: ["instant", "hero", "notchArgs", "notchSerial", "deckPages", "deckArgs",
        "overviewArgs", "menu", "capture", "fullscreen", "passive", "notch", "deck", "overview", "passiveTop"]

    // Tell rules.js about a new active monitor (setActive) when it differs from the one it knows.
    function _syncActive(): void {
        if (activeMonitor === "" || activeMonitor === _state.global.activeMonitor || !_state.monitors[activeMonitor]) return;
        _run("setActive", activeMonitor);
    }

    Component {
        id: stateComp
        MonitorState {}
    }
    // Events age out without an operation (notch.md §7, 07 §5): armed by _apply for the next one.
    Timer {
        id: expiry
        onTriggered: root._run("tick")
    }
    onActiveMonitorChanged: _syncActive()
    onLockedChanged: _run("setLocked", locked)
    onFullscreenMonitorsChanged: _syncFullscreen()
    // A monitor's fullscreen flag follows fullscreenMonitors (also for a monitor added later).
    function _syncFullscreen(): void {
        for (const n in _state.monitors) {
            const fs = fullscreenMonitors.indexOf(n) >= 0;
            const m = _state.monitors[n];
            if (m && m.fullscreen !== fs) _run("setFullscreen", n, fs);
        }
    }
    Connections {
        target: Config
        function onSettingChanged(key: string): void {
            if (key === "notch.overFullscreen") root._run("tick");
        }
    }
}
