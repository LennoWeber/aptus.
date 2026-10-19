import QtQuick

// Copy of the settings taken right before new ones are applied.
// A watchdog outside the shell restores it if the change is not confirmed.
QtObject {
    property string id
    property var createdAt           // Date
    property string settingsPath     // backup of the user's settings file
    property string hotkeysPath      // backup of the hotkeys file
    property string providersPath    // backup of the user's AI providers
    property bool restoreRequested

    // Back up the current settings, hotkeys and providers.
    function create(): void {
        if (id !== "") throw new Error("invariant: SettingsSnapshot.create: a snapshot already exists; restore or discard it first")
        throw new Error("not implemented")
    }

    function restore(): void {
        if (id === "") throw new Error("invariant: SettingsSnapshot.restore: restore without a snapshot")
        throw new Error("not implemented")
    }

    function discard(): void {
        throw new Error("not implemented")
    }
}
