import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.models
import qs.theme

// The island on one screen: a layer window of fixed size at the top centre (so the compositor never animates a
// resize). Only the island inside it takes input; the rest of the window lets clicks through.
PanelWindow {
    id: win

    required property var modelData
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
    property var workspaces
    property string windowTitle
    property bool slidOut

    // Settings, as read from appSettings.
    property bool hoverOpen
    property bool reserveSpace
    property bool mediaWings
    property string clockFormat

    // This screen's stage and view: Open and Hover only on the screen that was opened; an alert shows on every screen.
    property int stage
    property int view
    property bool isOpen
    property bool isHover
    property bool isAlert

    // Morph: how far the island has grown toward the launcher or control center (0 = itself, 1 = fully there).
    property real morphProgress
    property real slide

    // Size of the body for the current stage and view.
    property real restWidth
    property real targetWidth
    property real targetHeight

    // Hover bookkeeping.
    property bool openedByHover

    signal dropdownRequested(int dropdownId, var anchorItem, var targetScreen, real offsetX)
    signal tileRequested(int tileId)
    signal controlCenterRequested()
    signal launcherRequested()
}
