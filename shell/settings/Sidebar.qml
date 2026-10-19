import QtQuick

// Category list.
// Phase 2/3/4 skeleton. Body comes in phase 7.
Item {
    // TODO(phase 7): ten categories, icon and name; the active one is marked by weight, not colour.

    property var categories  // list of SettingsCategory
    property string activeCategoryId
    signal categorySelected(string categoryId)

    function select(categoryId: string): void {
        throw new Error("not implemented")
    }
}
