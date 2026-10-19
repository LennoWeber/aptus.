import QtQuick
import Quickshell

// Settings app window.
// Phase 2/3/4 skeleton. Body comes in phase 7.
FloatingWindow {
    // TODO(phase 7): own window: sidebar with categories, search on top, page on the right, change bar at the bottom.
    // TODO(phase 7): calm layout; advanced entries stay hidden until Show advanced is on.

    property var appState  // SettingsAppState
    property var categories  // list of SettingsCategory
    property var entries  // list of SettingEntry

    function showWindow(): void {
        throw new Error("not implemented")
    }

    function hideWindow(): void {
        throw new Error("not implemented")
    }
}
