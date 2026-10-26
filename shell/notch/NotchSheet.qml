import QtQuick
import qs.models
import qs.theme
import qs.components
import qs.bar
import qs.services

// What the notch shows when it is open: header, music, workspaces and status icons.
Item {
    id: sheet

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
    property string clockFormat: "24h"

    signal closeRequested()
    signal dropdownRequested(int dropdownId, var anchorItem)
    signal launcherRequested()
    signal controlCenterRequested()

    implicitHeight: column.implicitHeight + 20

    SystemClock { id: sys; precision: SystemClock.Minutes }
    readonly property var english: Qt.locale("en_GB")

    Column {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; topMargin: 8 }
        spacing: 6

        // Header: wordmark, time and date, control center.
        Item {
            width: parent.width
            height: 40

            BarItem {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                height: 36
                text: "shell."
                emphasis: true
                horizontalPadding: 10
                onClicked: sheet.launcherRequested()
            }
            Column {
                anchors.centerIn: parent
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: sheet.english.toString(sys.date, sheet.clockFormat === "12h" ? "h:mm AP" : "HH:mm")
                    role: Enums.TextRole.Title
                    tabularNumbers: true
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: sheet.english.toString(sys.date, "dddd d MMMM")
                    role: Enums.TextRole.Bar
                    color: Tokens.inkSoft
                }
            }
            NotchButton {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                kind: "sliders"
                onClicked: sheet.controlCenterRequested()
            }
        }

        Rectangle { visible: sheet.mediaState && sheet.mediaState.available; width: parent.width; height: 1; color: Tokens.line }

        NotchMedia {
            visible: sheet.mediaState && sheet.mediaState.available
            width: parent.width
            height: visible ? implicitHeight : 0
            mediaState: sheet.mediaState
        }

        Rectangle { width: parent.width; height: 1; color: Tokens.line }

        Item {
            width: parent.width
            height: 40

            WorkspaceStrip {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                height: 36
                workspaces: sheet.workspaces
                style: sheet.appSettings && sheet.appSettings.get("bar.workspaceStyle") === "dots" ? 1 : 0
                onWorkspaceClicked: id => Compositor.focusWorkspace(id)
            }

            StatusGroup {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                audioState: sheet.audioState
                nightLightState: sheet.nightLightState
                networkState: sheet.networkState
                bluetoothState: sheet.bluetoothState
                caffeineState: sheet.caffeineState
                focusState: sheet.focusState
                batteryState: sheet.batteryState
                showBatteryPercent: sheet.appSettings ? sheet.appSettings.get("bar.showBatteryPercent") !== false : true
                onItemClicked: (id, anchor) => sheet.dropdownRequested(id, anchor)
            }
        }
    }
}
