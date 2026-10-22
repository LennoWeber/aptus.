import QtQuick
import Quickshell
import qs.models

// The notch of every screen. shell.qml loads this file through a Loader (not by type name), so that a fault in the
// notch cannot stop the rest of the shell; the Loader hands the properties below over when it loads it.
Scope {
    id: host

    property var shellState         // ShellState
    property var appSettings        // AppSettings
    property var notchState         // NotchState
    property var audioState
    property var networkState
    property var bluetoothState
    property var batteryState
    property var nightLightState
    property var caffeineState
    property var focusState
    property var mediaState
    property var timerState
    property var captureState
    property var workspaces         // from Compositor.workspaceList
    property string windowTitle     // from Compositor.activeTitle
    property bool slidOut           // tablet mode: the notch leaves like the bar does

    signal dropdownRequested(int dropdownId, var anchorItem, var targetScreen)
    signal tileRequested(int tileId)
    signal controlCenterRequested()
    signal launcherRequested()
}
