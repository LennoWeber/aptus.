pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.models

// Signatures only. Bodies come in phase 7.
Singleton {
    // Views of Quickshell.Hyprland (Hyprland.workspaces, activeToplevel, toplevels); the shell never talks to hyprctl for reading.
    // Workspaces that exist (they appear with their first window, as in the user's Hyprland rules), sorted by id.
    // Array.from: the model's list is array-like, not guaranteed to have the array methods.
    property var workspaceList: Array.from(Hyprland.workspaces.values)
        .filter(ws => ws.id > 0)
        .sort((a, b) => a.id - b.id)
        .map(ws => ({ id: ws.id, name: ws.name, active: ws.focused, urgent: ws.urgent, occupied: ws.toplevels.values.length > 0 }))
    property string activeTitle: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
    property var clientList          // open windows

    function focusWorkspace(workspaceId: int): void {
        if (!Number.isInteger(workspaceId) || workspaceId < 1) throw new Error("invariant: Compositor.focusWorkspace: workspace id must be an integer >= 1")
        const existing = Array.from(Hyprland.workspaces.values).find(ws => ws.id === workspaceId)
        if (existing) {
            existing.activate()
        } else {
            // A workspace that has no window yet is not in the list; the compositor creates it on request.
            dispatch(Hyprland.usingLua ? "hl.dsp.focus({ workspace = " + workspaceId + " })" : "workspace " + workspaceId)
        }
    }

    function focusWindow(address: string): void {
        if (!address) throw new Error("invariant: Compositor.focusWindow: empty window address")
        throw new Error("not implemented")
    }

    // Hyprland dispatcher (Hyprland.dispatch).
    function dispatch(command: string): void {
        if (!command) throw new Error("invariant: Compositor.dispatch: empty dispatcher command")
        if (/suspend|hibernate|hybrid-sleep|systemctl\s+sleep/i.test(command)) throw new Error("invariant: Compositor.dispatch: suspend or hibernate is never allowed")
        Hyprland.dispatch(command)
    }

    function launch(command: string): void {
        if (!command) throw new Error("invariant: Compositor.launch: empty command")
        if (/suspend|hibernate|hybrid-sleep|systemctl\s+sleep/i.test(command)) throw new Error("invariant: Compositor.launch: suspend or hibernate is never allowed")
        // Run through a shell so that the user can put arguments into a command setting; callers that build a command
        // from untrusted text (web search) must use Quickshell.execDetached with an argument list instead.
        Quickshell.execDetached(["sh", "-c", command])
    }

    // Enums.Orientation.
    function setMonitorTransform(orientation: int): void {
        if (orientation < Enums.Orientation.Landscape || orientation > Enums.Orientation.PortraitFlipped) throw new Error("invariant: Compositor.setMonitorTransform: unknown orientation")
        // TODO(phase 7): Hyprland monitor transform for the given orientation.
        throw new Error("not implemented")
    }
}
