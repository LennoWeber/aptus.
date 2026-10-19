import QtQuick

// One setting as described in config/settings-schema.json.
QtObject {
    property string id
    property string categoryId
    property string title
    property string description
    property int kind                // Enums.SettingKind
    property string path             // key in settings.json
    property var defaultValue
    property var value
    property var options             // for choice entries
    property string optionsFrom      // dynamic option source, e.g. "providers"
    property real min
    property real max
    property real step
    property string unit
    property string actionId         // for action entries
    property bool advanced           // hidden until "Show advanced"
    property bool secret             // value is masked (e.g. iCal address)
    property bool confirm            // action needs confirmation
    property var keywords            // extra search terms

    function reset(): void {
        throw new Error("not implemented")
    }

    function isDefault(): bool {
        throw new Error("not implemented")
    }

    // Search in title, description and keywords.
    function matches(text: string): bool {
        throw new Error("not implemented")
    }
}
