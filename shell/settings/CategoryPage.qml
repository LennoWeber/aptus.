import QtQuick

// Page with the entries of one category.
// Phase 2/3/4 skeleton. Body comes in phase 7.
Item {
    // TODO(phase 7): group entries with calm headings; changed entries are marked and can be reset one by one.

    property var entries  // list of SettingEntry
    property bool showAdvanced
    property var draftValues
    signal draftChanged(string entryId, var value)

    // Jump from launcher search.
    function scrollToEntry(entryId: string): void {
        // TODO(phase 7): highlight the entry briefly.
        throw new Error("not implemented")
    }
}
