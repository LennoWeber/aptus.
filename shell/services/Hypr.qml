pragma Singleton
// Hypr: monitors, workspaces, toplevels, active window, fullscreen, urgent, special, submap.
// Owner: S1 (core, window actions), S3 (workspaces, urgent, special, icons). Stub until its stage fills it.
import QtQuick
import Quickshell

Singleton {
    id: root

    // Hyprland monitors: [{ name, x, y, width, height, scale, focused, activeWorkspace }]
    property var monitors: []
    // name of the focused monitor
    property string focusedMonitor: ""
    // { address, class, title, monitor, workspace, floating, pinned, fullscreen } or null
    property var activeWindow: null
    // monitor name → true while its active workspace has a fullscreen window
    property var fullscreenMonitors: ({})
    // every mapped toplevel: { address, class, title, monitor, workspace, x, y, width, height, floating, pinned, fullscreen, focusHistoryId }
    property var windows: []
    // the current submap
    property string submap: ""
    // HYPRLAND_INSTANCE_SIGNATURE of this session
    property string signature: ""

    // [{ id, name, monitor, windows: int, urgent: bool, special: bool, active: bool, focused: bool }]
    property var workspaces: []
    // monitor name → the special workspace shown on it ("" none), e.g. "special:scratch"
    property var specialOpen: ({})
    // window addresses with the urgent flag
    property var urgent: []

    // Run a dispatcher, given as the Lua expression Hyprland 0.57 takes ("hl.dsp.focus({ window = 'address:0x…' })").
    function dispatch(lua: string): void { throw new Error("Hypr.dispatch: not implemented"); }
    // Focus a window by address (the away catcher's focus replay, Switcher, Overview).
    function focusWindow(address: string): void { throw new Error("Hypr.focusWindow: not implemented"); }
    // The topmost mapped window under a monitor-local point, or null (away catcher).
    function windowAt(monitor: string, x: real, y: real): var { throw new Error("Hypr.windowAt: not implemented"); }
    // The monitor record for a name, or null.
    function monitor(name: string): var { throw new Error("Hypr.monitor: not implemented"); }
    // Window actions (Spotlight §5.1, Overview, menus); address "" = the active window.
    function closeWindow(address: string): void { throw new Error("Hypr.closeWindow: not implemented"); }
    // Force quit (risk): kill the window's process.
    function killWindow(address: string): void { throw new Error("Hypr.killWindow: not implemented"); }
    function toggleFloating(address: string): void { throw new Error("Hypr.toggleFloating: not implemented"); }
    function toggleFullscreen(address: string): void { throw new Error("Hypr.toggleFullscreen: not implemented"); }
    function moveToWorkspace(address: string, workspace: string): void { throw new Error("Hypr.moveToWorkspace: not implemented"); }
    function focusWorkspace(workspace: string): void { throw new Error("Hypr.focusWorkspace: not implemented"); }
    function renameWorkspace(id: int, name: string): void { throw new Error("Hypr.renameWorkspace: not implemented"); }
    // hyprctl reload (Spotlight "Reload Hyprland").
    function reload(): void { throw new Error("Hypr.reload: not implemented"); }
}
