pragma Singleton
// Settings (07-architecture §8, 10-settings): defaults from shell/config/settings-schema.json,
// overrides from ~/.config/aptus/settings.json (only values that differ from the defaults).
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // TODO(phase): FileView on Paths.schemaFile (blockLoading) → schema, defaults; FileView on
    //   Paths.settingsFile (watchChanges) → config.js load; v1 file → backup to settings.json.v1 on first write.
    // TODO(phase): config.js migrate() on load (rewrite once when changed); keys in `pending` survive an
    //   outside change of the file (settings.md §9).
    // TODO(phase): a 300 ms Timer debounces _save() (atomic write through FileView atomicWrites).

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
    // settings.json is a v1 file (no "v"): ignored, backed up to settings.json.v1 before the first write.
    property bool v1File: false
    // Keys set in this session that are not written yet (debounce): an outside change to the file
    // does not overwrite them (settings.md §9).
    property var pending: ({})

    signal settingChanged(string key)
    signal settingInvalid(string key, string message)

    // The effective value of a key (reads `revision`, so bindings follow every change).
    function get(key: string): var { throw new Error("Config.get: not implemented"); }
    // Set and persist a value (debounced 300 ms, atomic). Returns "" or the validation message.
    function set(key: string, value: var): string { throw new Error("Config.set: not implemented"); }
    // Back to the default (removes the key from settings.json).
    function reset(key: string): void { throw new Error("Config.reset: not implemented"); }
    // Reset every key of a settings page (settings.md §4 "Reset page").
    function resetPage(page: string): void { throw new Error("Config.resetPage: not implemented"); }
    // Validate without storing: { ok, value, message }.
    function validate(key: string, value: var): var { throw new Error("Config.validate: not implemented"); }
    // The schema entry of a key, or null.
    function entry(key: string): var { throw new Error("Config.entry: not implemented"); }
    // Re-read settings.json (IPC `shell reloadConfig`, file changed outside the shell).
    function reload(): void { throw new Error("Config.reload: not implemented"); }

    function _loadSchema(): void { throw new Error("Config._loadSchema: not implemented"); }
    function _loadFile(text: string): void { throw new Error("Config._loadFile: not implemented"); }
    function _save(): void { throw new Error("Config._save: not implemented"); }
    function _backupV1(): void { throw new Error("Config._backupV1: not implemented"); }
}
