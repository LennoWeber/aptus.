import QtQuick
import Quickshell
import Quickshell.Io

// State of the settings app window.
//
// Flow: edit (draft) -> Save -> a backup of the settings file is made and the draft is applied -> 15 s to
// confirm -> confirmed = kept, otherwise the old values are restored. After a revert the draft stays in the
// form as unsaved changes. A watchdog outside the shell restores the file even if the shell hangs.
Scope {
    id: root

    property var appSettings         // AppSettings
    property bool open
    property string activeCategoryId: "appearance"
    property string query
    property bool showAdvanced       // off by default to keep the view calm
    property string focusedEntryId   // entry to scroll to and highlight (from launcher search)
    property string notice           // short result of export, import and similar actions

    property var categories: []      // { id, title, iconName }
    property var entries: []         // schema entries, plain objects
    property var draftValues: ({})   // map entryId -> value typed, not yet applied (only values that differ)
    readonly property var changedEntryIds: Object.keys(draftValues)
    readonly property bool hasUnsavedChanges: changedEntryIds.length > 0

    property int phase               // Enums.ApplyPhase
    property var previousTree        // settings tree from before the pending change
    property string snapshotId
    property int confirmSecondsLeft

    readonly property string rootDir: Quickshell.env("APTUS_ROOT") || Quickshell.shellPath("..")
    readonly property string exportPath: Quickshell.env("HOME") + "/aptus-settings.json"

    FileView {
        id: schemaFile
        path: root.rootDir + "/config/settings-schema.json"
        blockLoading: true
    }

    FileView {
        id: exportFile
        path: root.exportPath
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: {
        try {
            const schema = JSON.parse(schemaFile.text())
            categories = schema.categories || []
            entries = schema.entries || []
        } catch (e) {
            console.warn("aptus: settings-schema.json not readable: " + e)
        }
    }

    // One tick per second while a change waits for confirmation.
    Timer {
        interval: 1000
        repeat: true
        running: root.phase === Enums.ApplyPhase.AwaitingConfirm
        onTriggered: root.tick()
    }

    // Value in effect, default, and what the form shows.
    function appliedOf(entry: var): var { return entry.path ? appSettings.get(entry.path) : undefined }
    function defaultOf(entry: var): var {
        if (!entry.path) return undefined
        return entry.path.split(".").reduce((node, key) => (node === undefined || node === null ? undefined : node[key]), appSettings.defaults)
    }
    function valueOf(entry: var): var { return entry.id in draftValues ? draftValues[entry.id] : appliedOf(entry) }
    function isDefault(entry: var): bool { return JSON.stringify(valueOf(entry)) === JSON.stringify(defaultOf(entry)) }
    function editable(entry: var): bool { return ["toggle", "choice", "slider", "number", "text", "list", "location", "tileList", "keyMap"].indexOf(entry.kind) >= 0 }

    // Entries of the current page or search, hiding advanced ones unless asked for.
    function visibleEntries(): var {
        const q = query.trim().toLowerCase()
        return entries.filter(e => {
            // TODO(phase 7, Bild-Theming): honour `visibleWhen` of an entry ({ path, notEquals }), so appearance.style and bar.tone are hidden while appearance.themeSource is standard.
            if (e.advanced && !showAdvanced) return false
            if (q === "") return e.category === activeCategoryId
            return matches(e, q)
        })
    }

    // Search in title, description and keywords.
    function matches(entry: var, text: string): bool {
        const q = text.toLowerCase()
        return entry.title.toLowerCase().indexOf(q) >= 0 || (entry.description || "").toLowerCase().indexOf(q) >= 0
            || (entry.keywords || []).some(k => k.toLowerCase().indexOf(q) >= 0)
    }

    function openWindow(categoryId: string): void {
        if (categoryId && categories.some(c => c.id === categoryId)) activeCategoryId = categoryId
        open = true
    }

    function closeWindow(): void {
        open = false
    }

    // Jump to an entry (from launcher search).
    function focusEntry(entryId: string): void {
        const entry = entries.find(e => e.id === entryId)
        if (!entry) throw new Error("invariant: SettingsAppState.focusEntry: unknown settings entry")
        query = ""
        if (entry.advanced) showAdvanced = true
        activeCategoryId = entry.category
        focusedEntryId = entryId
        open = true
    }

    function setCategory(categoryId: string): void {
        if (!categories.some(c => c.id === categoryId)) throw new Error("invariant: SettingsAppState.setCategory: unknown category")
        activeCategoryId = categoryId
        query = ""
    }

    function setQuery(text: string): void {
        query = text
    }

    function setDraft(entryId: string, value: var): void {
        if (phase === Enums.ApplyPhase.AwaitingConfirm) throw new Error("invariant: SettingsAppState.setDraft: editing while a change waits for confirmation")
        const entry = entries.find(e => e.id === entryId)
        if (!entry || !editable(entry)) throw new Error("invariant: SettingsAppState.setDraft: unknown or read-only settings entry")
        const next = Object.assign({}, draftValues)
        if (JSON.stringify(value) === JSON.stringify(appliedOf(entry))) delete next[entryId]
        else next[entryId] = value
        draftValues = next
        if (phase === Enums.ApplyPhase.Reverted) phase = Enums.ApplyPhase.Clean
    }

    // Reset the draft to the values currently in effect.
    function discardDraft(): void {
        if (phase === Enums.ApplyPhase.AwaitingConfirm) throw new Error("invariant: SettingsAppState.discardDraft: discard while a change waits for confirmation")
        draftValues = ({})
        if (phase === Enums.ApplyPhase.Reverted) phase = Enums.ApplyPhase.Clean
    }

    // Reset one entry to its default (as a draft; Save applies it).
    function resetEntry(entryId: string): void {
        if (phase === Enums.ApplyPhase.AwaitingConfirm) throw new Error("invariant: SettingsAppState.resetEntry: reset while a change waits for confirmation")
        const entry = entries.find(e => e.id === entryId)
        if (!entry) throw new Error("invariant: SettingsAppState.resetEntry: unknown settings entry")
        if (editable(entry)) setDraft(entryId, defaultOf(entry))
    }

    // Back up the settings file, then apply the draft and start the confirmation countdown.
    function save(): void {
        if (!hasUnsavedChanges) throw new Error("invariant: SettingsAppState.save: save without unsaved changes")
        if (phase === Enums.ApplyPhase.AwaitingConfirm || prepareProcess.running) throw new Error("invariant: SettingsAppState.save: second save while the first still waits (would overwrite the backup)")
        confirmSecondsLeft = appSettings.settingsConfirmTimeoutSec > 0 ? appSettings.settingsConfirmTimeoutSec : 15
        snapshotId = String(Date.now())
        previousTree = appSettings.values
        // The watchdog must have backed the file up before the new values are written.
        prepareProcess.command = ["aptus-settings-watchdog", "prepare", snapshotId, String(confirmSecondsLeft)]
        prepareProcess.running = true
    }

    Process {
        id: prepareProcess
        // The exit status enum of Process is not known to qmllint.
        // qmllint disable signal-handler-parameters
        onExited: code => {
            if (code !== 0) {
                root.notice = "Could not back up the settings, nothing was changed."
                return
            }
            root.applyDraft()
        }
        // qmllint enable signal-handler-parameters
    }

    function applyDraft(): void {
        for (const id in draftValues) {
            const entry = entries.find(e => e.id === id)
            if (entry) appSettings.set(entry.path, draftValues[id])
        }
        appSettings.writeUserConfig()
        phase = Enums.ApplyPhase.AwaitingConfirm
    }

    // Keep the applied values.
    function confirm(): void {
        if (phase !== Enums.ApplyPhase.AwaitingConfirm) throw new Error("invariant: SettingsAppState.confirm: confirm without a pending change")
        Quickshell.execDetached(["aptus-settings-watchdog", "confirm", snapshotId])
        draftValues = ({})
        previousTree = null
        phase = Enums.ApplyPhase.Clean
    }

    // Restore the old values, keep the draft in the form.
    function revertNow(): void {
        if (phase !== Enums.ApplyPhase.AwaitingConfirm) throw new Error("invariant: SettingsAppState.revertNow: revert without a pending change")
        if (!previousTree) throw new Error("invariant: SettingsAppState.revertNow: revert without a backup (nothing to restore)")
        appSettings.restoreValues(previousTree)
        appSettings.writeUserConfig()
        Quickshell.execDetached(["aptus-settings-watchdog", "restore", snapshotId])
        previousTree = null
        phase = Enums.ApplyPhase.Reverted
    }

    // One second of the countdown.
    function tick(): void {
        if (phase !== Enums.ApplyPhase.AwaitingConfirm) throw new Error("invariant: SettingsAppState.tick: tick outside the confirmation phase")
        if (confirmSecondsLeft <= 0) throw new Error("invariant: SettingsAppState.tick: tick after the countdown ended")
        confirmSecondsLeft -= 1
        if (confirmSecondsLeft === 0) revertNow()
    }

    // Writes the overrides to ~/aptus-settings.json, without the private calendar addresses.
    function exportSettings(): void {
        let tree = ({})
        try { tree = JSON.parse(appSettings.userConfigText()) || ({}) } catch (e) { tree = ({}) }
        if (tree.calendar) { delete tree.calendar.sources; delete tree.calendar.icsUrl }
        exportFile.setText(JSON.stringify(tree, null, 2) + "\n")
        notice = "Exported to " + exportPath
    }

    // Reads ~/aptus-settings.json into the draft; nothing is applied until Save.
    function importSettings(): void {
        if (phase === Enums.ApplyPhase.AwaitingConfirm) throw new Error("invariant: SettingsAppState.importSettings: import while a change waits for confirmation")
        let tree
        try { tree = JSON.parse(exportFile.text()) } catch (e) { notice = "Nothing to import at " + exportPath; return }
        let count = 0
        const next = Object.assign({}, draftValues)
        for (const entry of entries) {
            if (!editable(entry)) continue
            const v = entry.path.split(".").reduce((node, key) => (node === undefined || node === null ? undefined : node[key]), tree)
            if (v === undefined) continue
            if (JSON.stringify(v) === JSON.stringify(appliedOf(entry))) delete next[entry.id]
            else { next[entry.id] = v; count++ }
        }
        draftValues = next
        notice = count + " value(s) imported into the draft. Save to apply."
    }

    // Every editable entry back to its default, as a draft.
    function resetAll(): void {
        if (phase === Enums.ApplyPhase.AwaitingConfirm) throw new Error("invariant: SettingsAppState.resetAll: reset all while a change waits for confirmation")
        const next = {}
        for (const entry of entries) {
            if (!editable(entry)) continue
            if (JSON.stringify(defaultOf(entry)) !== JSON.stringify(appliedOf(entry))) next[entry.id] = defaultOf(entry)
        }
        draftValues = next
        notice = "All settings set to their defaults in the draft. Save to apply."
    }

    // Action entries: export, import, reset. Others are not wired yet.
    signal wallpaperRequested()

    function runAction(entry: var): void {
        if (entry.id === "appearance.wallpaper") { wallpaperRequested(); return }
        if (entry.id === "about.export") exportSettings()
        else if (entry.id === "about.import") importSettings()
        else if (entry.id === "about.reset") resetAll()
        else notice = "This action comes with a later section."
    }
}
