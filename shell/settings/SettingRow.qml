import QtQuick

// One setting with its editor.
// Phase 2/3/4 skeleton. Body comes in phase 7.
Item {
    // TODO(phase 7): editor by entry kind (toggle, choice, slider, number, text, action); secret values are masked.

    property var entry  // SettingEntry
    property var draftValue
    property bool changed
    signal valueEdited(var value)
    signal resetRequested()
}
