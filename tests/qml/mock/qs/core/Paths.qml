pragma Singleton
import QtQuick
// Test double of qs.core Paths: only what components read. @REPO@ is filled in by mkmock.py.
QtObject {
    readonly property string fonts: "@REPO@/shell/assets/fonts"
    readonly property string home: "/nonexistent-home"
    function url(path: string): string { return path === "" ? "" : "file://" + path; }
}
