import QtQuick
// Test double of Quickshell.Io Process: runs nothing (`running` stays as set, no output).
QtObject {
    property bool running: false
    property var command: []
    property var stdout: null
    property var stderr: null
    signal exited(int exitCode)
}
