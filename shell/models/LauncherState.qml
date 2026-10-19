import QtQuick

// State of the launcher pill (open/closed, mode, query, results).
QtObject {
    property var shellState      // ShellState, so showing the launcher can close dropdowns and take the overlay
    property bool open
    property int mode            // Enums.LauncherMode
    property int previousMode    // used by the mode-switch animation
    property bool switching      // true while the icon merges into the pill
    property string query
    property var results         // list of SearchResult
    property int selectedIndex
    property var recentApps      // optional small row when query is empty
    property var openWindows     // optional narrow cards when query is empty
    property string activeProviderId  // AI provider used in AI mode
    property var chatMessages    // short question/answer exchange in AI mode, cleared on close
    property bool busy           // async search or AI request running
    property bool docked         // AI mode: pill sits at a screen edge, no blur, screen stays readable
    property int dockEdge        // Enums.DockEdge
    property real dockProgress   // 0 = centered, 1 = docked (drives the move animation)

    // Open the launcher in a mode (Enums.LauncherMode).
    function show(newMode: int): void {
        if (newMode < Enums.LauncherMode.Apps || newMode > Enums.LauncherMode.Clipboard) throw new Error("invariant: LauncherState.show: unknown launcher mode")
        // The launcher takes the overlay and closes dropdowns first: a dropdown never opens over it.
        if (shellState) shellState.openOverlay(Enums.Overlay.Launcher)
        if (open) {
            setMode(newMode)
            return
        }
        previousMode = newMode
        mode = newMode
        switching = false
        query = ""
        results = []
        selectedIndex = 0
        busy = false
        open = true
    }

    function hide(): void {
        if (!open) return
        open = false
        switching = false
        query = ""
        results = []
        selectedIndex = 0
        busy = false
        if (shellState && shellState.activeOverlay === Enums.Overlay.Launcher) shellState.closeAll()
    }

    // Same hotkey closes an already open mode.
    function toggle(newMode: int): void {
        if (newMode < Enums.LauncherMode.Apps || newMode > Enums.LauncherMode.Clipboard) throw new Error("invariant: LauncherState.toggle: unknown launcher mode")
        if (open && mode === newMode) hide()
        else show(newMode)
    }

    // Switch mode and start the merge animation.
    function setMode(newMode: int): void {
        if (newMode < Enums.LauncherMode.Apps || newMode > Enums.LauncherMode.Clipboard) throw new Error("invariant: LauncherState.setMode: unknown launcher mode")
        if (!open) throw new Error("invariant: LauncherState.setMode: setMode on a closed launcher")
        if (newMode === mode) return
        // TODO(phase 7, section 5): AI mode -> dock() and blur out; any other mode -> undock().
        previousMode = mode
        mode = newMode
        switching = true
        selectedIndex = 0
    }

    // Tab and Shift+Tab.
    function cycleMode(step: int): void {
        if (step !== 1 && step !== -1) throw new Error("invariant: LauncherState.cycleMode: step must be 1 or -1")
        if (!open) throw new Error("invariant: LauncherState.cycleMode: cycleMode on a closed launcher")
        setMode((mode + step + 5) % 5)
    }

    function setQuery(text: string): void {
        if (!open) throw new Error("invariant: LauncherState.setQuery: setQuery on a closed launcher")
        if (typeof text !== "string") throw new Error("invariant: LauncherState.setQuery: query must be a string")
        query = text
        selectedIndex = 0
    }

    function moveSelection(delta: int): void {
        if (!open) throw new Error("invariant: LauncherState.moveSelection: moveSelection on a closed launcher")
        if (!Number.isInteger(delta)) throw new Error("invariant: LauncherState.moveSelection: delta must be an integer")
        const count = results ? results.length : 0
        if (count === 0) return
        selectedIndex = ((selectedIndex + delta) % count + count) % count
    }

    // Enter.
    function activateSelected(): void {
        if (!open) throw new Error("invariant: LauncherState.activateSelected: activateSelected on a closed launcher")
        if (!results || results.length === 0) throw new Error("invariant: LauncherState.activateSelected: nothing to activate")
        if (selectedIndex < 0 || selectedIndex >= results.length) throw new Error("invariant: LauncherState.activateSelected: selected index out of range")
        // Close first (instant feedback), then run the action. Web results go through BrowserState.search (set up by the search backend).
        const picked = results[selectedIndex]
        hide()
        picked.activate()
    }

    // AI mode provider.
    function setProvider(providerId: string): void {
        if (providerId === "") throw new Error("invariant: LauncherState.setProvider: empty provider id")
        throw new Error("not implemented")
    }

    // Alt+Left / Alt+Right.
    function cycleProvider(step: int): void {
        if (step !== 1 && step !== -1) throw new Error("invariant: LauncherState.cycleProvider: step must be 1 or -1")
        if (mode !== Enums.LauncherMode.Ai) throw new Error("invariant: LauncherState.cycleProvider: provider switch outside AI mode")
        throw new Error("not implemented")
    }

    // Short question or follow-up in AI mode.
    function askAi(question: string): void {
        if (mode !== Enums.LauncherMode.Ai) throw new Error("invariant: LauncherState.askAi: askAi outside AI mode")
        if (typeof question !== "string" || question.trim() === "") throw new Error("invariant: LauncherState.askAi: empty question")
        if (activeProviderId === "") throw new Error("invariant: LauncherState.askAi: no AI provider selected")
        if (busy) throw new Error("invariant: LauncherState.askAi: a request is still running")
        // TODO(phase 7): run AiProvider.buildCommand off the UI thread and append streaming output to chatMessages.
        throw new Error("not implemented")
    }

    function clearChat(): void {
        throw new Error("not implemented")
    }

    // Move the pill to the screen edge and fade the blur out.
    function dock(): void {
        if (!open) throw new Error("invariant: LauncherState.dock: dock on a closed launcher")
        if (mode !== Enums.LauncherMode.Ai) throw new Error("invariant: LauncherState.dock: only AI mode docks")
        // TODO(phase 7): panel at AppSettings.aiDockEdge with width aiDockWidthPx; input only on the panel so other windows stay usable.
        throw new Error("not implemented")
    }

    function undock(): void {
        throw new Error("not implemented")
    }
}
