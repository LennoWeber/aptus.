pragma Singleton
import QtQuick
// Test double of qs.core Paths: only what Config and the components read. @REPO@ is filled in by
// mkmock.py; the home does not exist, so settings.json is "not found" and Config uses defaults.
QtObject {
    readonly property string home: "/nonexistent-home"
    readonly property string config: home + "/.config/aptus"
    readonly property string fonts: "@REPO@/shell/assets/fonts"
    readonly property string schemaFile: "@REPO@/shell/config/settings-schema.json"
    readonly property string tokensFile: "@REPO@/theme/tokens.json"
    readonly property string settingsFile: config + "/settings.json"
    function url(path: string): string { return path === "" ? "" : "file://" + path; }
    function expand(path: string): string { return path; }
}
