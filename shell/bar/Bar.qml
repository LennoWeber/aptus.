import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.models
import qs.theme
import qs.services
import qs.components

// The compact top bar.
PanelWindow {
    id: bar

    required property var modelData
    property var shellState  // ShellState
    property var appSettings // AppSettings
    property var batteryState // BatteryState
    property var audioState   // AudioState
    property var nightLightState  // NightLightState
    property var captureState  // CaptureState
    property var networkState
    property var bluetoothState
    property var caffeineState
    property var focusState
    property var workspaces  // list of workspace objects from Compositor
    property var contextItems  // see ContextState
    property string windowTitle
    property bool slidOut  // hidden in tablet mode, a swipe from the top edge brings it back

    signal wordmarkClicked()
    signal controlCenterRequested()
    signal tileRequested(int tileId)
    signal dropdownRequested(int dropdownId, var anchorItem, var targetScreen)

    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: Tokens.barHeight
    exclusiveZone: slidOut ? 0 : Tokens.barHeight
    // TODO(phase 7, Bild-Theming): the bar fill is Tokens.bar (the Standard source keeps bg); the border stays Tokens.line.
    color: Tokens.bg
    // qmllint disable unqualified unresolved-type
    margins { top: -Tokens.barHeight * bar.slide }
    // qmllint enable unqualified unresolved-type
    property real slide: slidOut ? 1 : 0
    Behavior on slide { NumberAnimation { duration: Tokens.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
    WlrLayershell.namespace: "aptus-bar"

    // Fullscreen windows and caffeine keep the screen awake (policy in Idle).
    IdleInhibitor {
        enabled: Idle.inhibit
        window: bar
    }

    // Hairline at the bottom edge, no shadow.
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Tokens.line
    }

    Row {
        id: left
        anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
        spacing: 4

        BarItem {
            text: "shell."
            emphasis: true
            horizontalPadding: 8
            onClicked: bar.wordmarkClicked()
        }

        WorkspaceStrip {
            workspaces: bar.workspaces
            style: bar.appSettings && bar.appSettings.get("bar.workspaceStyle") === "dots" ? 1 : 0
            onWorkspaceClicked: id => Compositor.focusWorkspace(id)
        }
    }

    ContextZone {
        // Always exactly in the middle of the bar; it only gets narrower (never shifts) when the sides need room.
        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
        width: Math.max(0, bar.width - 2 * (Math.max(left.width, right.width) + 16))
        items: bar.contextItems
        fallbackText: bar.windowTitle
        onTileRequested: id => bar.tileRequested(id)
    }

    Row {
        id: right
        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
        spacing: 2

        // Red dot while a screen recording runs; a click stops it.
        BarItem {
            visible: bar.captureState ? bar.captureState.recording : false
            onClicked: bar.captureState.stopRecording()
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: Tokens.critical
                SequentialAnimation on opacity {
                    running: bar.captureState ? bar.captureState.recording : false
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.3; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.3; to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: bar.captureState ? Math.floor(bar.captureState.recordingSec / 60) + ":" + (bar.captureState.recordingSec % 60 < 10 ? "0" : "") + bar.captureState.recordingSec % 60 : ""
                role: Enums.TextRole.Bar
                tabularNumbers: true
                color: Tokens.critical
            }
        }

        StatusGroup {
            audioState: bar.audioState
            nightLightState: bar.nightLightState
            networkState: bar.networkState
            bluetoothState: bar.bluetoothState
            caffeineState: bar.caffeineState
            focusState: bar.focusState
            onItemClicked: (id, anchor) => bar.dropdownRequested(id, anchor, bar.modelData)
            batteryState: bar.batteryState
            showBatteryPercent: bar.appSettings ? bar.appSettings.get("bar.showBatteryPercent") !== false : true
        }

        Clock {
            id: clock
            onClicked: bar.dropdownRequested(Enums.DropdownId.Clock, clock, bar.modelData)
            format: bar.appSettings ? bar.appSettings.get("bar.clockFormat") : "24h"
            showSeconds: bar.appSettings ? bar.appSettings.get("bar.showSeconds") === true : false
            showDate: bar.appSettings ? bar.appSettings.get("bar.showDate") !== false : true
        }

        BarItem {
            onClicked: bar.controlCenterRequested()
            StatusGlyph {
                anchors.verticalCenter: parent.verticalCenter
                kind: "sliders"
                // TODO(phase 7, Bild-Theming): text and icons on the bar use Tokens.barInk; secondary text barInkSoft, inactive icons barInkFaint.
                color: Tokens.ink
            }
        }
    }
}
