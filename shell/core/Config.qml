pragma Singleton
pragma ComponentBehavior: Bound
// Settings (07-architecture §8, 10-settings): defaults from shell/config/settings-schema.json,
// overrides from ~/.config/aptus/settings.json (only values that differ from the defaults).
import QtQuick
import Quickshell
import Quickshell.Io
import "js/config.js" as Lib

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
    // settings.json is a v1 file (no "v"): ignored, backed up to settings.json.v1 before the first write.
    property bool v1File: false
    // Keys set in this session that are not written yet (debounce): an outside change to the file
    // does not overwrite them (settings.md §9).
    property var pending: ({})

    signal settingChanged(string key)
    signal settingInvalid(string key, string message)

    // The effective value of a key (reads `revision`, so bindings follow every change).
    function get(key: string): var {
        root.revision;
        return root.values[key];
    }
    // Set and persist a value (debounced 300 ms, atomic). Returns "" or the validation message.
    function set(key: string, value: var): string {
        const e = entry(key);
        if (!e) return "unknown setting";
        const r = Lib.validate(schema, key, value, Paths.home, null);
        if (!r.ok) { settingInvalid(key, r.message); return r.message; }
        const next = Object.assign({}, values);
        next[key] = r.value;
        Lib.deriveAll(schema, next);
        const cross = Lib.crossCheck(schema, next);
        if (cross.length) { settingInvalid(key, cross[0].message); return cross[0].message; }
        _store(key, r.value, next);
        return "";
    }
    // Back to the default (removes the key from settings.json).
    function reset(key: string): void {
        const e = entry(key);
        if (!e || e.type === "derived") return;
        const next = Object.assign({}, values);
        next[key] = JSON.parse(JSON.stringify(e["default"]));
        Lib.deriveAll(schema, next);
        _store(key, next[key], next);
    }
    // Reset every key of a settings page (settings.md §4 "Reset page").
    function resetPage(page: string): void {
        for (const k in schema.keys) if (schema.keys[k].page === page) reset(k);
    }
    // Validate without storing: { ok, value, message }.
    function validate(key: string, value: var): var { return Lib.validate(schema, key, value, Paths.home, null); }
    // The schema entry of a key, or null.
    function entry(key: string): var { return schema.keys && schema.keys[key] ? schema.keys[key] : null; }
    // Re-read settings.json (IPC `shell reloadConfig`, file changed outside the shell).
    function reload(): void { settingsView.reload(); }

    function _loadSchema(): void {
        try {
            schema = JSON.parse(schemaView.text());
        } catch (e) {
            Log.error("config", "settings-schema.json: " + e);
            schema = { keys: {}, rules: [] };
        }
        defaults = Lib.defaults(schema);
        const v = Lib.defaults(schema);
        Lib.deriveAll(schema, v);
        values = v;
        revision++;
    }
    function _loadFile(text: string): void {
        const r = Lib.load(schema, text, Paths.home, null);
        fileError = r.ok ? "" : r.error;
        if (!r.ok) Log.warn("config", "settings.json: " + r.error + " (defaults in use)");
        v1File = r.v1;
        if (r.v1) { _v1Text = text; Log.info("config", "settings.json is a v1 file: ignored"); }
        // keys set in this session but not written yet survive an outside change (settings.md §9)
        for (const k in pending) {
            r.values[k] = pending[k];
            if (Lib.equal(pending[k], schema.keys[k]["default"])) delete r.overrides[k]; else r.overrides[k] = pending[k];
        }
        Lib.deriveAll(schema, r.values);
        for (const p of r.problems) { Log.warn("config", p.key + ": " + p.message); settingInvalid(p.key, p.message); }
        const old = values;
        overrides = r.overrides;
        unknown = r.unknown;
        values = r.values;
        revision++;
        const wasLoaded = loaded;
        loaded = true;
        if (wasLoaded) for (const k in r.values) if (!Lib.equal(old[k], r.values[k])) settingChanged(k);
        if (r.migrated) saveTimer.restart();
    }
    function _save(): void {
        if (v1File) _backupV1();
        Paths.ensureDir(Paths.config);
        settingsView.setText(Lib.serialise(overrides, unknown));
        pending = {};
    }
    function _backupV1(): void {
        backupView.setText(_v1Text);
        v1File = false;
        Log.info("config", "v1 settings backed up to settings.json.v1");
    }

    // The text of a v1 settings.json, kept for the backup before the first write.
    property string _v1Text: ""

    // Commit one change: `value` becomes the override of `key` (removed when it equals the
    // default, which is how reset() goes through here), `next` the complete validated value map
    // (derived keys included); marks the key pending, emits settingChanged per changed key, starts
    // the save debounce.
    function _store(key: string, value: var, next: var): void {
        const o = Object.assign({}, overrides);
        if (Lib.equal(value, schema.keys[key]["default"])) delete o[key]; else o[key] = value;
        const p = Object.assign({}, pending);
        p[key] = value;
        const old = values;
        overrides = o;
        pending = p;
        values = next;
        revision++;
        for (const k in next) if (!Lib.equal(old[k], next[k])) settingChanged(k);
        saveTimer.restart();
    }

    FileView {
        id: schemaView
        path: Paths.schemaFile
        blockLoading: true
        onLoaded: root._loadSchema()
        onLoadFailed: error => Log.error("config", "settings-schema.json: " + FileViewError.toString(error))
    }
    FileView {
        id: settingsView
        path: root.schema.keys ? Paths.settingsFile : ""
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._loadFile(text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) root.fileError = FileViewError.toString(error);
            root._loadFile("");
        }
    }
    FileView {
        id: backupView
        path: Paths.settingsFile + ".v1"
        atomicWrites: true
        printErrors: false
    }
    Timer {
        id: saveTimer
        interval: 300
        onTriggered: root._save()
    }
}
