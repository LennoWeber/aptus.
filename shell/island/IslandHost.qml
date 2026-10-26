import QtQuick
import Quickshell
import qs.models
import qs.services

// The island of every screen. shell.qml loads this file through a Loader (not by type name), so that a fault in the
// island cannot stop the rest of the shell; the Loader hands the properties below over when it loads it.
Scope {
    id: host

    property var shellState         // ShellState
    property var appSettings        // AppSettings
    property var islandState        // IslandState
    property var lockState          // LockState
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
    property var displayState
    property var weatherState
    property var workspaces         // from Compositor.workspaceList
    property string windowTitle     // from Compositor.activeTitle
    property bool slidOut           // tablet mode: the island leaves like the bar does

    signal dropdownRequested(int dropdownId, var anchorItem, var targetScreen, real offsetX)
    signal tileRequested(int tileId)
    signal controlCenterRequested()
    signal launcherRequested()

    // Bookkeeping to tell what is new.
    property int lastPopupId: -1
    property string lastTrackKey: ""
    property bool batteryAnnounced

    // Push an alert for the notification at the top of Notifications.popupItems when it is a new one.
    function announceNotification(): void {
        throw new Error("not implemented")
    }

    // The launcher or the control center takes the stage (ShellState): tell IslandState where to morph to.
    function followShellState(): void {
        throw new Error("not implemented")
    }
}
