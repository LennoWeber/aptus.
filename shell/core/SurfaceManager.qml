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
    // Timing limits for rules.js, from Tokens (toast.staleMs, event.maxAgeMs).
    readonly property var limits: {
        const t = Tokens.surfaces;
        return { toastStale: t.toast ? t.toast.staleMs : 30000, eventMaxAge: t.event ? t.event.maxAgeMs : 4000,
                 pinnedCardTimeout: t.notch ? t.notch.pinnedCardTimeoutMs : 8000 };
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
    // Asks the settings window to focus itself (open but not focused, settings.md §2).
    signal settingsFocusRequested()

    // ── API (07 §5; also over IPC). Optional parameters are `var` and may be omitted: an
    // omitted typed string parameter would arrive as "undefined" (Qt 6.11, phase-3 probe).
    // `monitor` omitted or "" means the active monitor; `args` omitted means {}. ─────────────
    // Open a surface: a notch mode id, "card:<activity>", "deck", "overview", "capture",
    // "settings". Returns false when refused (locked) or queued (polkit open).
    function open(surface: string, args: var, monitor: var): bool {
        const s = _snapshot();
        const r = Rules.open(s.monitors, s.global, { op: "open", surface: surface, args: args || {}, monitor: _monitorFor(monitor) }, Date.now());
        _apply(r);
        return r.effects.some(e => e.kind === "opened" || e.kind === "settingsFocus");
    }
    function close(surface: string, monitor: var): void {
        const s = _snapshot();
        _apply(Rules.close(s.monitors, s.global, { op: "close", surface: surface, monitor: _monitorFor(monitor) }, Date.now()));
    }
    // Its own key again closes it (05 §3 way out 3); the settings window is focused when open but
    // not focused (settings.md §2).
    function toggle(surface: string, args: var, monitor: var): bool {
        const s = _snapshot();
        _apply(Rules.toggle(s.monitors, s.global, { op: "toggle", surface: surface, args: args || {}, monitor: _monitorFor(monitor) }, Date.now()));
        return isOpen(surface, monitor);
    }
    // The Esc ladder (05 §3): the menu, then the top surface's back handler, then the surface.
    function back(monitor: var): void {
        const name = _monitorFor(monitor);
        const m = monitors[name];
        if (!m) return;
        const t = m.top;
        let stepped = false;
        if (t !== "" && t !== "menu" && !(t === "deck" && m.deckPages.length > 1)) {
            const fn = backHandlers[name + "|" + t];
            if (fn) {
                try { stepped = !!fn(); } catch (e) { Log.warn("surface", t + " back handler: " + e); }
            }
        }
        const s = _snapshot();
        _apply(Rules.back(s.monitors, s.global, name, stepped, Date.now()));
    }
    // Passive content for the notch: kind "toast" | "osd" | "event". A non-empty key replaces the
    // entry with the same key in place (one OSD per kind, replaces_id). Returns the entry id.
    // priority defaults to 0 (critical toasts pass 2, as notification urgency).
    function post(kind: string, payload: var, priority: var, monitor: var, key: var): int {
        const s = _snapshot();
        const r = Rules.post(s.monitors, s.global, kind, payload === undefined ? {} : payload, Number(priority) || 0,
                             _monitorFor(monitor), key ? String(key) : "", Date.now());
        _apply(r);
        return r.id;
    }
    // Change a passive entry's payload in place (stack toast growing, OSD value change).
    function update(id: int, payload: var, monitor: var): void {
        const s = _snapshot();
        _apply(Rules.update(s.monitors, s.global, monitor ? String(monitor) : "", id, payload, Date.now()));
    }
    // Remove a passive entry (toast timed out or dismissed, OSD faded).
    function dismiss(id: int, monitor: var): void {
        const s = _snapshot();
        _apply(Rules.dismiss(s.monitors, s.global, monitor ? String(monitor) : "", id, Date.now()));
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
            m.interactive = monitors[n].interactive; m.keyboard = monitors[n].keyboard; m.top = monitors[n].top;
        }
        s.global.activeMonitor = activeMonitor;
        return JSON.stringify(s);
    }
    function isOpen(surface: string, monitor: var): bool {
        return Rules.isOpen(monitors[_monitorFor(monitor)] || null, { settingsOpen: settingsOpen }, surface);
    }
    function monitorState(name: string): MonitorState { return monitors[name] || null; }

    // Menus (03 §9): one per monitor, above every surface, closed first by Esc.
    function openMenu(monitor: string, menu: var): void {
        const s = _snapshot();
        _apply(Rules.openMenu(s.monitors, s.global, _monitorFor(monitor), menu, Date.now()));
    }
    function closeMenu(monitor: string): void {
        const s = _snapshot();
        _apply(Rules.closeMenu(s.monitors, s.global, _monitorFor(monitor), Date.now()));
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
        const s = _snapshot();
        _apply(Rules.setSettingsFocused(s.monitors, s.global, focused, Date.now()));
    }

    // ── Internal ──────────────────────────────────────────────────────────────────────────
    // Keep `monitors` in step with Hypr.monitors (create, remove without animation).
    function syncMonitors(names: var): void {
        const want = Array.from(names || []).map(String);
        for (const n of want) if (!monitors[n]) {
            const s = _snapshot();
            _apply(Rules.addMonitor(s.monitors, s.global, n, Date.now()));
        }
        for (const n in monitors) if (want.indexOf(n) < 0) {
            const s = _snapshot();
            _apply(Rules.removeMonitor(s.monitors, s.global, n, Date.now()));
        }
        _syncActive();
        _syncFullscreen();
    }
    // Copy a rules.js result into the MonitorState objects and emit the signals of its effects.
    function _apply(result: var): void {
        const g = result.global;
        _lastActive = g.activeMonitor;
        _lastLocked = g.locked;
        if (polkitMonitor !== g.polkitMonitor) polkitMonitor = g.polkitMonitor;
        pending = g.pending;
        if (previousWindow !== g.previousWindow) previousWindow = g.previousWindow;
        if (settingsArgs !== g.settingsArgs) settingsArgs = g.settingsArgs;
        if (settingsFocused !== g.settingsFocused) settingsFocused = g.settingsFocused;
        if (settingsOpen !== g.settingsOpen) settingsOpen = g.settingsOpen;
        passiveSerial = g.passiveSerial;
        let map = monitors, changed = false;
        for (const n in result.monitors) {
            let m = map[n];
            if (!m) {
                m = stateComp.createObject(root, { name: n });
                if (!changed) { map = Object.assign({}, map); changed = true; }
                map[n] = m;
            }
            const src = result.monitors[n];
            // args before the mode, so a surface reacting to `notch` sees its new args
            for (const f of _fields) if (m[f] !== src[f]) m[f] = src[f];
        }
        for (const n in map) if (!(n in result.monitors)) {
            if (!changed) { map = Object.assign({}, map); changed = true; }
            map[n].destroy();
            delete map[n];
        }
        if (changed) monitors = map;
        for (const e of result.effects) {
            if (e.kind === "opened") surfaceOpened(e.monitor, e.surface);
            else if (e.kind === "closed") surfaceClosed(e.monitor, e.surface);
            else if (e.kind === "settingsFocus") settingsFocusRequested();
            else Log.info("surface", e.kind + " " + e.surface + (e.monitor ? " on " + e.monitor : ""));
        }
    }
    // Plain-object snapshot of the current state for rules.js.
    function _snapshot(): var {
        const ms = {};
        for (const n in monitors) {
            const m = monitors[n], o = { name: n };
            for (const f of _fields) o[f] = m[f];
            o.interactive = m.interactive; o.keyboard = m.keyboard; o.top = m.top;
            o.passive = Array.from(m.passive);
            o.deckPages = Array.from(m.deckPages);
            ms[n] = o;
        }
        return { monitors: ms, global: {
            activeMonitor: _lastActive, locked: _lastLocked, polkitMonitor: polkitMonitor, pending: Array.from(pending),
            previousWindow: previousWindow, currentWindow: currentWindow, settingsOpen: settingsOpen,
            settingsArgs: settingsArgs, settingsFocused: settingsFocused, passiveSerial: passiveSerial, limits: limits,
            overFullscreen: Config.loaded ? Config.get("notch.overFullscreen") : "critical"
        } };
    }
    function _monitorFor(monitor: var): string {
        return monitor === undefined || monitor === null || monitor === "" || monitor === "undefined" ? activeMonitor : String(monitor);
    }

    // The active monitor as rules.js last saw it (the Spotlight rule needs the old one).
    property string _lastActive: ""
    // The lock state as rules.js last saw it: `locked` has already changed when onLockedChanged
    // runs, and the snapshot must still be the state before (setLocked closes the menus).
    property bool _lastLocked: false
    // The MonitorState fields copied from a rules.js result, in order (_apply).
    readonly property var _fields: ["instant", "hero", "notchArgs", "notchSerial", "deckPages", "deckArgs",
        "overviewArgs", "menu", "capture", "fullscreen", "passive", "notch", "deck", "overview", "passiveTop"]
    // Any monitor has passive content (runs the expiry tick only then).
    readonly property bool _hasPassive: {
        for (const n in monitors) if (monitors[n].passive.length > 0) return true;
        return false;
    }

    // Tell rules.js about a new active monitor (setActive) when it differs from _lastActive.
    function _syncActive(): void {
        if (activeMonitor === "" || activeMonitor === _lastActive || !monitors[activeMonitor]) return;
        const s = _snapshot();
        _apply(Rules.setActive(s.monitors, s.global, activeMonitor, Date.now()));
    }

    Component {
        id: stateComp
        MonitorState {}
    }
    // Events and waiting toasts age out without an operation (notch.md §7, 07 §5).
    Timer {
        interval: 500
        repeat: true
        running: root._hasPassive
        onTriggered: {
            const s = root._snapshot();
            root._apply(Rules.tick(s.monitors, s.global, Date.now()));
        }
    }
    onActiveMonitorChanged: _syncActive()
    onLockedChanged: {
        const s = _snapshot();
        _apply(Rules.setLocked(s.monitors, s.global, locked, Date.now()));
    }
    onFullscreenMonitorsChanged: _syncFullscreen()
    // A monitor's fullscreen flag follows fullscreenMonitors (also for a monitor added later).
    function _syncFullscreen(): void {
        for (const n in monitors) {
            const fs = fullscreenMonitors.indexOf(n) >= 0;
            if (monitors[n].fullscreen !== fs) {
                const s = _snapshot();
                _apply(Rules.setFullscreen(s.monitors, s.global, n, fs, Date.now()));
            }
        }
    }
    Connections {
        target: Config
        function onSettingChanged(key: string): void {
            if (key !== "notch.overFullscreen") return;
            const s = root._snapshot();
            root._apply(Rules.tick(s.monitors, s.global, Date.now()));
        }
    }
}
