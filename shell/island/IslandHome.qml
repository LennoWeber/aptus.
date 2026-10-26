import QtQuick
import qs.models
import qs.theme
import qs.components
import qs.bar
import qs.services

// The opened island, Home: header with time and date, music, workspaces and status icons.
Item {
    id: home

    property var appSettings
    property var audioState
    property var networkState
    property var bluetoothState
    property var batteryState
    property var nightLightState
    property var caffeineState
    property var focusState
    property var mediaState
    property var workspaces
    property string clockFormat
    property color ink
    property color inkSoft
    property color line

    signal closeRequested()
    signal dropdownRequested(int dropdownId, var anchorItem)
    signal launcherRequested()
    signal controlCenterRequested()
}
