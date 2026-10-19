import QtQuick
import qs.services

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
    property string defaultProviderId  // settings ai.defaultProvider
    property string activeProviderId  // AI provider used in AI mode
    property var chatMessages: []  // AI mode: { fromUser, text, streaming, error }, cleared on close
    property bool busy           // async search or AI request running
    readonly property bool docked: open && mode === Enums.LauncherMode.Ai  // AI mode: panel at a screen edge, no blur, screen stays readable

    Component.onCompleted: {
        AiProviders.chunk.connect(text => {
            if (chatMessages.length === 0) return
            const last = chatMessages[chatMessages.length - 1]
            last.text += (last.text === "" ? "" : "\n") + text
            chatMessages = chatMessages.slice()
        })
        AiProviders.finished.connect((ok, error) => {
            busy = false
            if (chatMessages.length === 0) return
            const last = chatMessages[chatMessages.length - 1]
            last.streaming = false
            if (!ok) last.error = error
            chatMessages = chatMessages.slice()
        })
    }

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
        chatMessages = []
        open = true
        if (newMode === Enums.LauncherMode.Ai) pickProvider()
        if (newMode === Enums.LauncherMode.Clipboard) Clipboard.refresh()
    }

    function hide(): void {
        if (!open) return
        open = false
        switching = false
        query = ""
        results = []
        selectedIndex = 0
        AiProviders.cancel()
        busy = false
        chatMessages = []
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
        previousMode = mode
        mode = newMode
        switching = true
        selectedIndex = 0
        if (newMode === Enums.LauncherMode.Ai) pickProvider()
        if (newMode === Enums.LauncherMode.Clipboard) Clipboard.refresh()
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

    // The provider AI mode starts with: the one in use, else the default from the settings, else the first enabled one.
    function pickProvider(): void {
        const list = AiProviders.enabledProviders()
        if (list.some(p => p.id === activeProviderId)) return
        const wanted = [defaultProviderId, AiProviders.defaultId].find(id => list.some(p => p.id === id))
        activeProviderId = wanted || (list.length > 0 ? list[0].id : "")
    }

    // AI mode provider.
    function setProvider(providerId: string): void {
        if (providerId === "") throw new Error("invariant: LauncherState.setProvider: empty provider id")
        if (!AiProviders.enabledProviders().some(p => p.id === providerId)) throw new Error("invariant: LauncherState.setProvider: unknown or disabled provider")
        activeProviderId = providerId
    }

    // Alt+Left / Alt+Right.
    function cycleProvider(step: int): void {
        if (step !== 1 && step !== -1) throw new Error("invariant: LauncherState.cycleProvider: step must be 1 or -1")
        if (mode !== Enums.LauncherMode.Ai) throw new Error("invariant: LauncherState.cycleProvider: provider switch outside AI mode")
        const list = AiProviders.enabledProviders()
        if (list.length === 0 || busy) return
        const at = list.findIndex(p => p.id === activeProviderId)
        setProvider(list[((at < 0 ? 0 : at) + step + list.length) % list.length].id)
    }

    // Short question or follow-up in AI mode. The CLIs answer one-shot, so earlier turns travel along in the prompt.
    function askAi(question: string): void {
        if (mode !== Enums.LauncherMode.Ai) throw new Error("invariant: LauncherState.askAi: askAi outside AI mode")
        if (typeof question !== "string" || question.trim() === "") throw new Error("invariant: LauncherState.askAi: empty question")
        if (activeProviderId === "") throw new Error("invariant: LauncherState.askAi: no AI provider selected")
        if (busy) throw new Error("invariant: LauncherState.askAi: a request is still running")
        const q = question.trim()
        const earlier = chatMessages.filter(m => !m.error).map(m => (m.fromUser ? "User: " : "Assistant: ") + m.text).join("\n")
        const prompt = "You answer short questions from a desktop launcher. Reply briefly in plain text, without tools.\n\n" + (earlier ? earlier + "\n" : "") + "User: " + q
        chatMessages = chatMessages.concat([{ fromUser: true, text: q, streaming: false, error: "" }, { fromUser: false, text: "", streaming: true, error: "" }])
        busy = true
        AiProviders.ask(activeProviderId, prompt)
    }

    function clearChat(): void {
        AiProviders.cancel()
        busy = false
        chatMessages = []
    }
}
