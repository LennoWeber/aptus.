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
    // TODO(phase 7, tablet mode): slides out when ShellState.barHidden; a swipe from the top edge brings it back (touch section).

    required property var modelData
    property var shellState  // ShellState
    property var appSettings // AppSettings
    property var batteryState // BatteryState
    property var audioState   // AudioState
    property var nightLightState  // NightLightState
    property var captureState  // CaptureState
    property var workspaces  // list of workspace objects from Compositor
    property var contextItems  // list of ContextItem
    property string windowTitle
    property bool slidOut  // hidden in tablet mode

    signal wordmarkClicked()
    signal controlCenterRequested()
    signal dropdownRequested(int dropdownId, var anchorItem, var targetScreen)

    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: Tokens.barHeight
    exclusiveZone: slidOut ? 0 : Tokens.barHeight
    color: Tokens.bg
    WlrLayershell.namespace: "aptus-bar"

    // Fullscreen windows and caffeine keep the screen awake (policy in Idle).
    IdleInhibitor {
        enabled: Idle.inhibit
        window: bar
    }

    function setSlidOut(on: bool): void {
        slidOut = on
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
        anchors { left: left.right; right: right.left; leftMargin: 16; rightMargin: 16; verticalCenter: parent.verticalCenter }
        items: bar.contextItems
        fallbackText: bar.windowTitle
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
                color: Tokens.ink
            }
        }
    }
}
