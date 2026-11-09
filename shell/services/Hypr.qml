pragma Singleton
pragma ComponentBehavior: Bound
// Hypr: monitors, workspaces, toplevels, active window, fullscreen, urgent, special, submap.
// Owner: S1 (core, window actions; built), S3 (workspaces, urgent, special, icons).
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.core

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
    property var windows: Hyprland.toplevels.values.map(t => _client(t)).filter(w => w.address !== "")
    // the current submap
    property string submap: ""
    // HYPRLAND_INSTANCE_SIGNATURE of this session
    property string signature: String(Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "")

    // [{ id, name, monitor, windows: int, urgent: bool, special: bool, active: bool, focused: bool }]
    property var workspaces: []
    // monitor name → the special workspace shown on it ("" none), e.g. "special:scratch"
    property var specialOpen: ({})
    // window addresses with the urgent flag
    property var urgent: []

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
    readonly property var _windowEvents: ["openwindow", "closewindow", "movewindow", "movewindowv2", "windowtitle",
        "windowtitlev2", "changefloatingmode", "fullscreen", "pin", "activewindowv2", "workspacev2", "resizewindow"]
    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "submap") root.submap = event.data;
            else if (root._windowEvents.indexOf(event.name) >= 0) root._refresh(["toplevels", "workspaces"]);
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
            if (root._pending.length === 0) stop();
        }
    }
    Component.onCompleted: _refresh(["monitors", "toplevels"])
}
