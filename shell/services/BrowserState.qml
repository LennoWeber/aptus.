import QtQuick
import Quickshell
import Quickshell.Hyprland

// Zen browser state, used by the launcher's web mode.
QtObject {
    property string command          // "zen"
    property string windowClass      // Hyprland window class used for detection
    property bool running
    property string windowAddress    // Hyprland address of the browser window
    property int workspaceId         // workspace the browser window lives on
    property string searchUrlTemplate  // e.g. "https://duckduckgo.com/?q={query}"

    // Is Zen running, and where?
    function detect(): void {
        running = false
        windowAddress = ""
        workspaceId = 0
        const cls = windowClass.toLowerCase()
        for (const t of Array.from(Hyprland.toplevels.values)) {
            const info = t.lastIpcObject
            if (!info || !info.class || info.class.toLowerCase() !== cls) continue
            running = true
            windowAddress = t.address
            workspaceId = t.workspace ? t.workspace.id : 0
            return
        }
    }

    // New tab in running Zen (switch workspace), or start Zen.
    function search(query: string): void {
        if (command === "") throw new Error("invariant: BrowserState.search: no browser command configured")
        const url = searchUrlTemplate.replace("{query}", encodeURIComponent(query))
        detect()
        // `zen --new-tab URL` opens the tab in the running instance, or starts Zen with it.
        Quickshell.execDetached([command, "--new-tab", url])
        if (running && workspaceId > 0) Compositor.focusWorkspace(workspaceId)
    }

    function focusWindow(): void {
        throw new Error("not implemented")
    }
}
