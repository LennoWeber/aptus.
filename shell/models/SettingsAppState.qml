import QtQuick
import Quickshell

// State of the settings app window.
//
// Flow: edit (draft) -> Save -> values are applied and a snapshot of the old
// state is kept -> 15 s to confirm -> confirmed = kept, otherwise the old values
// are restored. After a revert the draft stays in the form as unsaved changes.
Scope {
    id: root
    property bool open
    property string activeCategoryId
    property string query
    property bool showAdvanced       // off by default to keep the view calm
    property string focusedEntryId   // entry to scroll to and highlight (from launcher search)

    // draft handling
    property var draftValues         // map entryId -> value the user typed, not yet applied
    property var appliedValues       // map entryId -> value currently in effect
    property var defaults            // map entryId -> default value, from settings-schema.json
    property var changedEntryIds     // entries whose draft differs from the applied value
    property bool hasUnsavedChanges

    // apply and confirm
    property int phase               // Enums.ApplyPhase
    property var snapshot            // SettingsSnapshot taken before applying
    property int confirmSecondsLeft  // counts down from settingsConfirmTimeoutSec
    property var confirmDeadline     // Date, also handed to the watchdog so both agree on the end

    // One tick per second while a change waits for confirmation.
    Timer {
        interval: 1000
        repeat: true
        running: root.phase === 2 // Enums.ApplyPhase.AwaitingConfirm
        onTriggered: root.tick()
        // TODO(phase 7): use the enum instead of the literal 2 (import qs.models).
    }

    function openWindow(categoryId: string): void {
        throw new Error("not implemented")
    }

    function closeWindow(): void {
        throw new Error("not implemented")
    }

    // Jump to an entry (from launcher search).
    function focusEntry(entryId: string): void {
        throw new Error("not implemented")
    }

    function setCategory(categoryId: string): void {
        throw new Error("not implemented")
    }

    function setQuery(text: string): void {
        throw new Error("not implemented")
    }

    function setDraft(entryId: string, value: var): void {
        if (phase === Enums.ApplyPhase.AwaitingConfirm) throw new Error("invariant: SettingsAppState.setDraft: editing while a change waits for confirmation")
        if (!defaults || !(entryId in defaults)) throw new Error("invariant: SettingsAppState.setDraft: unknown settings entry")
        throw new Error("not implemented")
    }

    // Reset the draft to the values currently in effect.
    function discardDraft(): void {
        if (phase === Enums.ApplyPhase.AwaitingConfirm) throw new Error("invariant: SettingsAppState.discardDraft: discard while a change waits for confirmation")
        throw new Error("not implemented")
    }

    // Reset one entry to its default.
    function resetEntry(entryId: string): void {
        if (phase === Enums.ApplyPhase.AwaitingConfirm) throw new Error("invariant: SettingsAppState.resetEntry: reset while a change waits for confirmation")
        if (!defaults || !(entryId in defaults)) throw new Error("invariant: SettingsAppState.resetEntry: unknown settings entry")
        throw new Error("not implemented")
    }

    // Snapshot, apply the draft and start the confirmation countdown.
    function save(): void {
        if (!hasUnsavedChanges) throw new Error("invariant: SettingsAppState.save: save without unsaved changes")
        if (phase === Enums.ApplyPhase.AwaitingConfirm) throw new Error("invariant: SettingsAppState.save: second save while the first still waits (would overwrite the snapshot)")
        if (snapshot !== null && snapshot !== undefined) throw new Error("invariant: SettingsAppState.save: a snapshot already exists")
        // TODO(phase 7): SettingsSnapshot.create(), apply the draft, start aptus-settings-watchdog, phase = AwaitingConfirm,
        // TODO(phase 7): confirmSecondsLeft from AppSettings.settingsConfirmTimeoutSec.
        throw new Error("not implemented")
    }

    // Keep the applied values.
    function confirm(): void {
        if (phase !== Enums.ApplyPhase.AwaitingConfirm) throw new Error("invariant: SettingsAppState.confirm: confirm without a pending change")
        if (!snapshot) throw new Error("invariant: SettingsAppState.confirm: confirm without a snapshot")
        // TODO(phase 7): tell the watchdog to confirm, discard the snapshot, phase = Clean.
        throw new Error("not implemented")
    }

    // Restore the snapshot, keep the draft in the form.
    function revertNow(): void {
        if (phase !== Enums.ApplyPhase.AwaitingConfirm) throw new Error("invariant: SettingsAppState.revertNow: revert without a pending change")
        if (!snapshot) throw new Error("invariant: SettingsAppState.revertNow: revert without a snapshot (nothing to restore)")
        // TODO(phase 7): restore the snapshot, reload Hyprland if hotkeys changed, keep draftValues, phase = Reverted.
        throw new Error("not implemented")
    }

    // One second of the countdown.
    function tick(): void {
        if (phase !== Enums.ApplyPhase.AwaitingConfirm) throw new Error("invariant: SettingsAppState.tick: tick outside the confirmation phase")
        if (confirmSecondsLeft <= 0) throw new Error("invariant: SettingsAppState.tick: tick after the countdown ended")
        // TODO(phase 7): at 0 call revertNow(); the watchdog restores even if the shell hangs.
        throw new Error("not implemented")
    }

    function exportTo(path: string): void {
        if (!path) throw new Error("invariant: SettingsAppState.exportTo: empty path")
        throw new Error("not implemented")
    }

    function importFrom(path: string): void {
        if (!path) throw new Error("invariant: SettingsAppState.importFrom: empty path")
        if (phase === Enums.ApplyPhase.AwaitingConfirm) throw new Error("invariant: SettingsAppState.importFrom: import while a change waits for confirmation")
        throw new Error("not implemented")
    }

    function resetAll(): void {
        if (phase === Enums.ApplyPhase.AwaitingConfirm) throw new Error("invariant: SettingsAppState.resetAll: reset all while a change waits for confirmation")
        throw new Error("not implemented")
    }
}
