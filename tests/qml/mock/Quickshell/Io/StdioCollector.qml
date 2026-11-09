import QtQuick
// Test double of Quickshell.Io StdioCollector: never receives anything.
QtObject {
    property string text: ""
    signal streamFinished()
}
