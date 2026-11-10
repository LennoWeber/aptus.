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
    // TODO(phase): S1 hand-off: no eager map; _rebuildWindows sets it, coalesced, when a
    //   toplevel's lastIpcObject changes (refreshes update objects in place) or one comes or goes.
    property var windows: Hyprland.toplevels.values.map(t => _client(t)).filter(w => w.address !== "")
    // the current submap
    property string submap: ""
    // HYPRLAND_INSTANCE_SIGNATURE of this session
    property string signature: String(Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "")

    // Workspace records (hypr.js): [{ id, name, label, monitor, windows, apps, urgent, special,
    // active, focused }], normal workspaces in id order, then the special ones.
    // TODO(phase): set by _rebuildWorkspaces (and specialOpen, urgent with it).
    property var workspaces: []
    // monitor name → the special workspace shown on it ("" none), e.g. "special:scratch"
    property var specialOpen: ({})
    // window addresses with the urgent flag
    property var urgent: []

    // The service works (S3): workspaces, urgent, special and the title patching are live.
    // TODO(phase): true.
    readonly property bool available: false
    // A screencast (screen sharing) is running (`screencast` event; Privacy reads it).
    property bool screencast: false
    // The active keyboard layout's name (`activelayout`; the layout OSD).
    property string layout: ""
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
    // One monitor's strip (hypr.js stripFor with bar.workspaces.show).
    function stripFor(monitor: string): var { throw new Error("not implemented"); }
    // The workspace record of an id, or null.
    function workspace(id: int): var { throw new Error("not implemented"); }
    // Name a workspace ("" removes the name, ≤ surfaces.bar.workspaceNameMaxChars): written to
    // Paths.workspacesState and applied with renameWorkspace (bar.md §8).
    function setWorkspaceName(id: int, name: string): void { throw new Error("not implemented"); }
    // The pill menu's "Move workspace to ▸" and "Close all windows…" (bar.md §3).
    function moveWorkspaceToMonitor(id: int, monitor: string): void { throw new Error("not implemented"); }
    function closeWorkspaceWindows(id: int): void { throw new Error("not implemented"); }
    // The window menu (bar.md §4); address "" = the active window.
    function togglePin(address: string): void { throw new Error("not implemented"); }
    function moveToMonitor(address: string, monitor: string): void { throw new Error("not implemented"); }
    // The scratch pill (bar.md §3): show or hide special:scratch on the focused monitor.
    function toggleScratch(): void { throw new Error("not implemented"); }
    // The window of an app (a toast without a default action focuses it, notch.md §6): by the
    // desktop entry (Apps.entryFor of each window's class), else by class = app name; most
    // recently focused first; null when none.
    function windowForApp(desktopEntry: string, appName: string): var { throw new Error("not implemented"); }
    // Focus the next (+1) / previous (-1) window on the focused workspace (wheel on the title).
    function cycleFocus(direction: int): void { throw new Error("not implemented"); }
    // The Caps Lock OSD (shortcuts capslock-on / capslock-off; the bind reads the keyboard state).
    function showCapsLock(on: bool): void { throw new Error("not implemented"); }

    // A `windowtitlev2` event: patch the title in place (no refresh), or refresh when unknown.
    function _onTitle(data: string): void { throw new Error("not implemented"); }
    // An `urgent` event: mark the window's workspace; toast when that workspace is not shown.
    function _onUrgent(address: string): void { throw new Error("not implemented"); }
    // `activewindowv2` (address): the focus order for the pills' MRU apps (hypr.js bumpFocus).
    function _onActiveWindow(address: string): void { throw new Error("not implemented"); }
    // `activespecialv2` ("id,name,monitor"): specialOpen of that monitor.
    function _onActiveSpecial(data: string): void { throw new Error("not implemented"); }
    // `screencast` ("state,owner"): screencast.
    function _onScreencast(data: string): void { throw new Error("not implemented"); }
    // `activelayout` ("keyboard,layout"): layout, and the layout OSD (levels.js layoutOsd) when
    // the main keyboard's layout changed (not at start).
    function _onLayout(data: string): void { throw new Error("not implemented"); }
    // Rebuild `windows` from the toplevels (after a toplevel refresh only).
    function _rebuildWindows(): void { throw new Error("not implemented"); }
    // Rebuild `workspaces` from Hyprland's workspaces, the windows and the focus order.
    function _rebuildWorkspaces(): void { throw new Error("not implemented"); }
    // Read the workspace names file's text and apply the names.
    function _loadNames(text: string): void { throw new Error("not implemented"); }

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
    // TODO(phase): S1 hand-off: drop windowtitle/windowtitlev2 here (a terminal retitles many
    //   times a second); windowtitlev2 goes to _onTitle instead.
    readonly property var _windowEvents: ["openwindow", "closewindow", "movewindow", "movewindowv2", "windowtitle",
        "windowtitlev2", "changefloatingmode", "fullscreen", "pin", "activewindowv2", "workspacev2", "resizewindow"]
    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            // TODO(phase): windowtitlev2 → _onTitle; urgent → _onUrgent; activespecialv2 →
            //   _onActiveSpecial; screencast → _onScreencast; activelayout → _onLayout;
            //   activewindowv2 → _onActiveWindow; workspace/window events → _rebuildWorkspaces once
            //   the refresh lands (lastIpcObjectChanged of the objects, coalesced; renames too).
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
    // TODO(phase): a FileView on Paths.workspacesState (names, _loadNames; watched), and the
    //   first _rebuildWindows/_rebuildWorkspaces once the first refreshes land (07 §6: a lazy
    //   singleton never relies on on<Prop>Changed for its first value).
    Component.onCompleted: _refresh(["monitors", "toplevels"])

    // Found by the probe (phase 5):
    // Events after which the workspace list (names, monitors) is stale.
    // TODO(phase): createworkspacev2, destroyworkspacev2, renameworkspace, moveworkspacev2,
    //   focusedmonv2, monitoraddedv2, monitorremovedv2; any of them restarts one coalescing
    //   rebuild Timer (several events per change make one rebuild), and an Instantiator over the
    //   toplevels rebuilds when a window's lastIpcObject changes.
    readonly property var _workspaceEvents: []
}
