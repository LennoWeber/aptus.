pragma Singleton
// Settings (07-architecture §8, 10-settings): defaults from shell/config/settings-schema.json,
// overrides from ~/.config/aptus/settings.json (only values that differ from the defaults).
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // The parsed schema: { version, pages, templates, keys, rules }.
    property var schema: ({})
    // key → default value.
    property var defaults: ({})
    // key → effective value (default unless overridden and valid).
    property var values: ({})
    // key → value from settings.json that differs from the default and is valid.
    property var overrides: ({})
    // Keys in settings.json that the schema does not know; kept on every write.
    property var unknown: ({})
    // Bumped on every change of `values`; Config.get() reads it so bindings follow.
    property int revision: 0
    // True once schema and settings file were read (also when the file is missing).
    property bool loaded: false
    // The last problem with settings.json ("" when fine), for the settings window banner.
    property string fileError: ""

    signal settingChanged(string key)
    signal settingInvalid(string key, string message)
}
