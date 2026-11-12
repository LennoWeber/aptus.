pragma Singleton
pragma ComponentBehavior: Bound
// Hypr: monitors, workspaces, toplevels, active window, fullscreen, urgent, special, submap.
// Owner: S1 (core, window actions; built), S3 (workspaces, urgent, special, icons).
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.core
import Quickshell.Io
import "js/hypr.js" as H
import "js/levels.js" as L
import "js/notifications.js" as N

Singleton {
    id: root

    // Hyprland monitors: [{ name, x, y, width, height, scale, focused, activeWorkspace }]
    property var monitors: Hyprland.monitors.values.map(m => ({
        name: m.name, x: m.x, y: m.y, width: m.width, height: m.height, scale: m.scale, focused: Hyprland.focusedMonitor === m,
        activeWorkspace: m.activeWorkspace ? m.activeWorkspace.id : -1
    }))
    // name of the focused monitor
    property string focusedMonitor: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    // { address, class, title, monitor, workspace, floating, pinned, fullscreen } or null
    property var activeWindow: Hyprland.activeToplevel ? _client(Hyprland.activeToplevel) : null
    // names of the monitors whose active workspace has a fullscreen window (SurfaceManager input)
    property var fullscreenMonitors: Hyprland.monitors.values.filter(m => m.activeWorkspace && m.activeWorkspace.hasFullscreen).map(m => m.name)
    // every mapped toplevel: { address, class, title, monitor, workspace, x, y, width, height, floating, pinned, fullscreen, focusHistoryId }
    // Set by _rebuildWindows, coalesced, when a toplevel's lastIpcObject changes (refreshes update
    // objects in place) or one comes or goes; titles are patched in place (_onTitle).
    property var windows: []
    // the current submap
    property string submap: ""
    // HYPRLAND_INSTANCE_SIGNATURE of this session
    property string signature: String(Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "")

    // Workspace records (hypr.js): [{ id, name, label, monitor, windows, apps, urgent, special,
    // active, focused }], normal workspaces in id order, then the special ones.
    property var workspaces: []
    // monitor name → the special workspace shown on it ("" none), e.g. "special:scratch"
    property var specialOpen: ({})
    // window addresses with the urgent flag
    property var urgent: []

    // The service works (S3): workspaces, urgent, special and the title patching are live.
    readonly property bool available: true
    // A screencast (screen sharing) is running (`screencast` event; Privacy reads it).
    property bool screencast: false
    // The active keyboard layout's name (`activelayout`; the layout OSD).
    property string layout: ""
    // Found in phase 7: the last layout per keyboard name (_onLayout).
    property var _layouts: ({})
    // Workspace id → name from Paths.workspacesState (applied with renameWorkspace).
    property var workspaceNames: ({})

    // Window addresses, most recently focused first (MRU app order on the pills).
    property var _focusOrder: []
    // Urgent workspaces already told about with a toast (once per urgency).
    property var _urgentToasted: ({})

    // Run a dispatcher, given as the Lua expression Hyprland 0.57 takes ("hl.dsp.focus({ window = 'address:0x…' })").
    function dispatch(lua: string): void {
        Log.debug("service.hypr", "dispatch " + lua);
        Hyprland.dispatch(lua);
    }
    // Focus a window by address (the away catcher's focus replay, Switcher, Overview).
    function focusWindow(address: string): void {
        if (address) dispatch(`hl.dsp.focus({ window = "address:${address}" })`);
    }
    // The topmost mapped window under a monitor-local point, or null (away catcher).
    function windowAt(monitor: string, x: real, y: real): var {
        const m = root.monitor(monitor);
        if (!m) return null;
        const gx = m.x + x, gy = m.y + y;
        let best = null;
        for (const w of windows) {
            if (w.hidden || (w.monitor !== m.name && !w.pinned)) continue;
            if (!w.pinned && w.workspace !== m.activeWorkspace) continue;
            if (gx < w.x || gy < w.y || gx >= w.x + w.width || gy >= w.y + w.height) continue;
            // floating windows lie above tiled ones; among them the most recently focused is on top
            if (!best || (w.floating && !best.floating)
                    || (w.floating === best.floating && w.focusHistoryId < best.focusHistoryId)) best = w;
        }
        return best;
    }
    // The monitor record for a name, or null.
    function monitor(name: string): var {
        for (const m of monitors) if (m.name === name) return m;
        return null;
    }
    // Window actions (Spotlight §5.1, Overview, menus); address "" = the active window.
    function closeWindow(address: string): void { dispatch(`hl.dsp.window.close(${_target(address)})`); }
    // Force quit (risk): kill the window's process.
    function killWindow(address: string): void { dispatch(`hl.dsp.window.kill(${_target(address)})`); }
    function toggleFloating(address: string): void { dispatch(`hl.dsp.window.float(${_target(address, "action = \"toggle\"")})`); }
    function toggleFullscreen(address: string): void { dispatch(`hl.dsp.window.fullscreen(${_target(address, "action = \"toggle\"")})`); }
    function moveToWorkspace(address: string, workspace: string): void {
        dispatch(`hl.dsp.window.move(${_target(address, `workspace = ${JSON.stringify(workspace)}, follow = false`)})`);
    }
    function focusWorkspace(workspace: string): void { dispatch(`hl.dsp.focus({ workspace = ${JSON.stringify(workspace)} })`); }
    function renameWorkspace(id: int, name: string): void {
        dispatch(`hl.dsp.workspace.rename({ id = ${id}, name = ${JSON.stringify(name)} })`);
    }
    // hyprctl reload (Spotlight "Reload Hyprland").
    function reload(): void { dispatch("hl.dsp.reload_config()"); }

    // ── S3: the bar's workspace actions and model ──────────────────────────────────────────
    function stripFor(monitor: string): var {
        return H.stripFor(workspaces, monitor, Config.get("bar.workspaces.show") || "used",
                          monitors.map(m => m.name), specialOpen);
    }
    // The workspace record of an id, or null.
    function workspace(id: int): var {
        for (const w of workspaces) if (w.id === id) return w;
        return null;
    }
    // Name a workspace ("" removes the name, ≤ surfaces.bar.workspaceNameMaxChars): written to
    // Paths.workspacesState and applied with renameWorkspace (bar.md §8).
    function setWorkspaceName(id: int, name: string): void {
        const n = String(name || "").trim().substring(0, Tokens.surfaces.bar.workspaceNameMaxChars);
        const names = Object.assign({}, workspaceNames);
        if (n === "") delete names[id]; else names[id] = n;
        workspaceNames = names;
        namesView.setText(JSON.stringify({ v: 1, names: names }, null, 2) + "\n");
        renameWorkspace(id, n === "" ? String(id) : n);
        _rebuildWorkspaces();
    }
    // The pill menu's "Move workspace to ▸" and "Close all windows…" (bar.md §3).
    function moveWorkspaceToMonitor(id: int, monitor: string): void {
        dispatch(`hl.dsp.workspace.move({ workspace = ${id}, monitor = ${JSON.stringify(monitor)} })`);
    }
    function closeWorkspaceWindows(id: int): void {
        for (const w of windows) if (w.workspace === id) closeWindow(w.address);
    }
    // The window menu (bar.md §4); address "" = the active window.
    function togglePin(address: string): void { dispatch(`hl.dsp.window.pin(${_target(address, "action = \"toggle\"")})`); }
    function moveToMonitor(address: string, monitor: string): void {
        dispatch(`hl.dsp.window.move(${_target(address, `monitor = ${JSON.stringify(monitor)}, follow = false`)})`);
    }
    // The scratch pill (bar.md §3): show or hide special:scratch on the focused monitor.
    function toggleScratch(): void { dispatch(`hl.dsp.workspace.toggle_special("scratch")`); }
    // The window of an app (a toast without a default action focuses it, notch.md §6): by the
    // desktop entry (Apps.entryFor of each window's class), else by class = app name; most
    // recently focused first; null when none.
    function windowForApp(desktopEntry: string, appName: string): var {
        const want = String(desktopEntry || "").toLowerCase(), app = String(appName || "").toLowerCase();
        let best = null;
        for (const w of windows) {
            const e = Apps.entryFor(w["class"]);
            const match = (want !== "" && e && String(e.id).toLowerCase().replace(/\.desktop$/, "") === want)
                       || (app !== "" && String(w["class"]).toLowerCase() === app);
            if (match && (!best || w.focusHistoryId < best.focusHistoryId)) best = w;
        }
        return best;
    }
    // Focus the next (+1) / previous (-1) window on the focused workspace (wheel on the title).
    function cycleFocus(direction: int): void {
        dispatch(direction > 0 ? "hl.dsp.window.cycle_next()" : "hl.dsp.window.cycle_next({ previous = true })");
    }
    // The Caps Lock OSD (shortcuts capslock-on / capslock-off; the bind reads the keyboard state).
    function showCapsLock(on: bool): void {
        SurfaceManager.post("osd", L.capsOsd(on), 0, "", "caps");
    }

    // A `windowtitlev2` event: patch the title in place (no refresh), or refresh when unknown.
    function _onTitle(data: string): void {
        const e = H.parseTitleEvent(data);
        if (!H.isAddress(e.address)) return;                    // malformed event data
        const patched = H.patchTitle(windows, e.address, e.title);
        if (patched) windows = patched;
        else _refresh(["toplevels"]);
    }
    // An `urgent` event: mark the window's workspace; toast when that workspace is not shown.
    function _onUrgent(address: string): void {
        const a = H.address(address);
        if (urgent.indexOf(a) < 0) urgent = urgent.concat([a]);
        _rebuildWorkspaces();
        const w = windows.find(x => x.address === a);
        if (!w) return;
        const ws = workspace(w.workspace);
        if (!ws || ws.active || _urgentToasted[ws.id]) return;
        const t = Object.assign({}, _urgentToasted); t[ws.id] = true; _urgentToasted = t;
        const app = Apps.nameFor(w["class"]);
        SurfaceManager.post("toast", N.systemToast(app + " needs attention on " + ws.label, "", "notifications_active", false,
                            Tokens.surfaces.toast.minTimeoutMs), 0, "", "urgent:" + ws.id);
    }
    // `activewindowv2` (address): the focus order for the pills' MRU apps (hypr.js bumpFocus).
    function _onActiveWindow(address: string): void {
        const a = H.address(address);
        if (!H.isAddress(a)) return;                            // "": no window is focused
        _focusOrder = H.bumpFocus(_focusOrder, a);
        if (urgent.indexOf(a) >= 0) urgent = urgent.filter(x => x !== a);
    }
    // `activespecialv2` ("id,name,monitor"): specialOpen of that monitor.
    function _onActiveSpecial(data: string): void {
        const p = H.splitEvent(data, 3);
        const s = Object.assign({}, specialOpen);
        s[p[2]] = p[1];
        specialOpen = s;
    }
    // `screencast` ("state,owner"): screencast.
    function _onScreencast(data: string): void { screencast = H.splitEvent(data, 2)[0] === "1"; }
    // `activelayout` ("keyboard,layout"): layout, and the layout OSD (levels.js layoutOsd) when a
    // keyboard's own layout changed. Another keyboard becoming active (each has its layout; a
    // virtual one such as wtype's) is no change, nor is Hyprland's "error" for an unnamed keymap.
    function _onLayout(data: string): void {
        const p = H.splitEvent(data, 2);
        if (p[1] === "error") return;
        const before = _layouts[p[0]];
        const m = Object.assign({}, _layouts);
        m[p[0]] = p[1];
        _layouts = m;
        layout = p[1];
        if (before !== undefined && before !== p[1]) SurfaceManager.post("osd", L.layoutOsd(p[1]), 0, "", "layout");
    }
    // Wave-2 review: the keyboards' layouts at start (`hyprctl -j devices`, hypr.js
    // layoutsFromDevices), so the first switch per keyboard after a start shows the OSD; the start
    // itself shows none. A keyboard an `activelayout` event already named keeps that (newer) one.
    function _loadLayouts(text: string): void {
        const d = H.layoutsFromDevices(text);
        _layouts = Object.assign({}, d.layouts, _layouts);
        if (layout === "") layout = d.main;
    }
    // Rebuild `windows` from the toplevels (after a toplevel refresh only).
    function _rebuildWindows(): void {
        windows = Hyprland.toplevels.values.map(t => _client(t)).filter(w => w.address !== "");
        // Found in review: a closed window leaves the urgent list.
        const open = urgent.filter(a => windows.some(w => w.address === a));
        if (open.length !== urgent.length) urgent = open;
        _rebuildWorkspaces();
    }
    // Rebuild `workspaces` from Hyprland's workspaces, the windows and the focus order.
    function _rebuildWorkspaces(): void {
        const ws = Hyprland.workspaces.values.map(w => ({ id: w.id, name: w.name, monitor: w.monitor ? w.monitor.name : "" }));
        workspaces = H.workspaceRecords(ws, windows, monitors, focusedMonitor, _focusOrder, urgent, workspaceNames,
                                        Tokens.surfaces.bar.workspaceNameMaxChars);
        // Found in review: a workspace may toast again once it was shown or has no urgent window.
        let t = null;
        for (const id in _urgentToasted) {
            const w = workspaces.find(x => String(x.id) === id);
            if (!w || w.active || !w.urgent) { t = t || Object.assign({}, _urgentToasted); delete t[id]; }
        }
        if (t) _urgentToasted = t;
    }
    // Read the workspace names file's text and apply the names.
    function _loadNames(text: string): void {
        try {
            const d = JSON.parse(text);
            const names = d && d.names ? d.names : {};
            workspaceNames = names;
            rebuildTimer.restart();
            for (const id in names) renameWorkspace(Number(id), names[id]);
        } catch (e) { Log.warn("service.hypr", "workspaces.json: " + e); }
    }

    // A toplevel as the plain record above (from lastIpcObject; fresh after refreshToplevels).
    function _client(t: var): var {
        const o = t.lastIpcObject || {};
        const at = o.at || [0, 0], size = o.size || [0, 0];
        const mon = Hyprland.monitors.values.find(m => m.id === o.monitor);
        return {
            address: o.address || (t.address ? "0x" + t.address : ""), "class": o["class"] || "", title: t.title || o.title || "",
            monitor: mon ? mon.name : "", workspace: o.workspace ? o.workspace.id : -1,
            x: at[0], y: at[1], width: size[0], height: size[1], floating: !!o.floating, pinned: !!o.pinned,
            fullscreen: (o.fullscreen || 0) > 0, hidden: !!o.hidden, focusHistoryId: o.focusHistoryID === undefined ? 99 : o.focusHistoryID
        };
    }
    // The Lua window selector table: the active window for "", else the address; extra fields appended.
    function _target(address: string, extra: var): string {
        const parts = [];
        if (address) parts.push(`window = "address:${address}"`);
        if (extra) parts.push(extra);
        return "{ " + parts.join(", ") + " }";
    }

    // Hyprland event names after which lastIpcObject is stale (refreshToplevels needed).
    // (Not the title events: a terminal retitles many times a second; _onTitle patches instead.)
    readonly property var _windowEvents: ["openwindow", "closewindow", "movewindow", "movewindowv2",
        "changefloatingmode", "fullscreen", "pin", "activewindowv2", "workspacev2", "resizewindow"]
    // Events after which the workspace list (names, monitors) is stale.
    readonly property var _workspaceEvents: ["createworkspacev2", "destroyworkspacev2", "renameworkspace",
        "moveworkspacev2", "activespecialv2"]
    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n === "submap") root.submap = event.data;
            else if (n === "windowtitlev2") root._onTitle(event.data);
            else if (n === "urgent") root._onUrgent(event.data);
            else if (n === "screencast") root._onScreencast(event.data);
            else if (n === "activelayout") root._onLayout(event.data);
            if (n === "activewindowv2") root._onActiveWindow(event.data);
            if (n === "activespecialv2") root._onActiveSpecial(event.data);
            if (root._windowEvents.indexOf(n) >= 0) root._refresh(["toplevels", "workspaces"]);
            else if (root._workspaceEvents.indexOf(n) >= 0) root._refresh(["workspaces"]);
            if (event.name === "fullscreen" || event.name === "workspacev2" || event.name === "monitoraddedv2"
                    || event.name === "monitorremovedv2" || event.name === "focusedmonv2") root._refresh(["monitors"]);
        }
    }
    // Quickshell 0.3.2: two refresh*() calls in the same JS turn leave every list empty, and
    // refreshMonitors() clears focusedMonitor until the next refreshWorkspaces(). So refreshes are
    // queued, run one per tick, and a monitor refresh is always followed by a workspace refresh.
    property var _pending: []
    // Queue refreshes ("monitors", "workspaces", "toplevels"); see _pending.
    function _refresh(kinds: var): void {
        for (const k of kinds) if (_pending.indexOf(k) < 0) _pending.push(k);
        if (_pending.indexOf("monitors") >= 0) {
            const w = _pending.indexOf("workspaces");
            if (w >= 0) _pending.splice(w, 1);
            _pending.push("workspaces");
        }
        if (!refreshTimer.running) refreshTimer.start();
    }
    Timer {
        id: refreshTimer
        interval: 15
        repeat: true
        onTriggered: {
            const k = root._pending.shift();
            if (k === "monitors") Hyprland.refreshMonitors();
            else if (k === "workspaces") Hyprland.refreshWorkspaces();
            else if (k === "toplevels") Hyprland.refreshToplevels();
            if (root._pending.length === 0) {
                stop();
                rebuildTimer.restart();
            }
        }
    }
    // One rebuild per burst: refreshes land as lastIpcObject changes of many objects.
    Timer {
        id: rebuildTimer
        interval: 16
        onTriggered: root._rebuildWindows()
    }
    Instantiator {
        model: Hyprland.toplevels
        delegate: Connections {
            required property var modelData
            target: modelData
            function onLastIpcObjectChanged(): void { rebuildTimer.restart(); }
        }
    }
    Connections {
        target: Hyprland.toplevels
        function onValuesChanged(): void { rebuildTimer.restart(); }
    }
    Connections {
        target: Hyprland.workspaces
        function onValuesChanged(): void { rebuildTimer.restart(); }
    }
    onMonitorsChanged: rebuildTimer.restart()
    onFocusedMonitorChanged: rebuildTimer.restart()
    FileView {
        id: namesView
        path: Paths.workspacesState
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._loadNames(text())
    }
    Run {
        id: devicesProc
        command: ["hyprctl", "-j", "devices"]
        onFinished: (stdout, stderr, code) => { if (code >= 0) root._loadLayouts(stdout); }
    }
    Component.onCompleted: {
        _refresh(["monitors", "toplevels"]);
        devicesProc.start();
    }
}
