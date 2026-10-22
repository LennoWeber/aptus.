import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.models
import qs.theme
import qs.services

// The notch on one screen: a layer window of fixed size at the top centre. Only the notch inside it takes input;
// the rest of the window lets clicks through.
PanelWindow {
    id: win

    required property var modelData
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
    property var workspaces
    property string windowTitle
    property bool slidOut

    // Settings, as read from appSettings.
    property string look: "light"       // light | ink
    property bool hoverOpen
    property bool reserveSpace: true
    property bool mediaWings: true
    property string clockFormat: "24h"
    property bool showSeconds

    // Which stage this screen's notch is in (the state holds the stage for the focused screen only).
    readonly property bool isOpen: false
    readonly property bool hasAlert: false
    property real slide: 0              // 0 shown .. 1 slid out
    property real hoverProgress: 0      // dwell for hover-open, 0..1

    signal dropdownRequested(int dropdownId, var anchorItem, var targetScreen)
    signal tileRequested(int tileId)
    signal controlCenterRequested()
    signal launcherRequested()
}
