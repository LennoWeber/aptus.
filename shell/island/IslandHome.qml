pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.models
import qs.theme
import qs.components
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
    property string workspaceStyle  // bar.workspaceStyle: numbers, dots or bubbles
    property color inkOn            // for the number inside the active bubble
    property string clockFormat
    property color ink
    property color inkSoft
    property color line

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

            Item {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                width: wordmark.implicitWidth + 20
                height: 36
                Label {
                    id: wordmark
                    anchors.centerIn: parent
                    text: "shell."
                    color: home.ink
                    font.weight: Font.DemiBold
                }
                MouseArea { anchors.fill: parent; onClicked: home.launcherRequested() }
            }
            Column {
                anchors.centerIn: parent
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: home.english.toString(sys.date, home.clockFormat === "12h" ? "h:mm AP" : "HH:mm")
                    role: Enums.TextRole.Title
                    color: home.ink
                    tabularNumbers: true
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: home.english.toString(sys.date, "dddd d MMMM")
                    role: Enums.TextRole.Bar
                    color: home.inkSoft
                }
            }
            IslandButton {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                kind: "sliders"
                color: home.ink
                onClicked: home.controlCenterRequested()
            }
        }

        Rectangle { visible: home.mediaState && home.mediaState.available; width: parent.width; height: 1; color: home.line }

        IslandMedia {
            visible: home.mediaState && home.mediaState.available
            width: parent.width
            height: visible ? implicitHeight : 0
            mediaState: home.mediaState
            ink: home.ink
            inkSoft: home.inkSoft
            line: home.line
        }

        Rectangle { width: parent.width; height: 1; color: home.line }

        Item {
            width: parent.width
            height: 40

            // TODO(phase 7, Island-Blasen): Bubbles instead of the numbers when bar.workspaceStyle is "bubbles" (40 px cells for touch).
            // Workspaces: the state is carried by weight, never by colour; urgent is the one signal colour.
            Row {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                Repeater {
                    model: home.workspaces
                    delegate: Item {
                        id: cell
                        required property var modelData
                        width: 28
                        height: 36
                        Label {
                            anchors.centerIn: parent
                            text: cell.modelData.name
                            role: Enums.TextRole.Bar
                            color: cell.modelData.urgent ? Tokens.warn : home.ink
                            opacity: cell.modelData.active ? 1 : cell.modelData.occupied ? 0.7 : 0.4
                            font.weight: cell.modelData.active ? Font.DemiBold : Font.Normal
                        }
                        Rectangle {
                            visible: cell.modelData.active
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 4 }
                            width: 12
                            height: 2
                            radius: 1
                            color: home.ink
                        }
                        MouseArea { anchors.fill: parent; onClicked: Compositor.focusWorkspace(cell.modelData.id) }
                    }
                }
            }

            // Status icons; a tap opens the dropdown of that item.
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 2

                Item {
                    visible: home.caffeineState ? home.caffeineState.active : false
                    width: 32; height: 36
                    StatusGlyph { anchors.centerIn: parent; kind: "cup"; color: Tokens.ok }
                }
                Item {
                    visible: home.focusState ? home.focusState.active : false
                    width: 32; height: 36
                    StatusGlyph { anchors.centerIn: parent; kind: "focus"; color: Tokens.ok }
                }
                Item {
                    id: btItem
                    visible: home.bluetoothState ? home.bluetoothState.powered : false
                    width: 32; height: 36
                    StatusGlyph { anchors.centerIn: parent; kind: "bluetooth"; color: home.ink }
                    MouseArea { anchors.fill: parent; onClicked: home.dropdownRequested(Enums.DropdownId.Bluetooth, btItem) }
                }
                Item {
                    id: netItem
                    width: 32; height: 36
                    StatusGlyph { anchors.centerIn: parent; kind: "wifi"; color: home.ink; opacity: home.networkState && home.networkState.connected ? 1 : 0.4 }
                    MouseArea { anchors.fill: parent; onClicked: home.dropdownRequested(Enums.DropdownId.Network, netItem) }
                }
                Item {
                    id: audioItem
                    width: 32; height: 36
                    StatusGlyph { anchors.centerIn: parent; kind: "volume"; color: home.ink; opacity: home.audioState && home.audioState.muted ? 0.4 : 1 }
                    MouseArea { anchors.fill: parent; onClicked: home.dropdownRequested(Enums.DropdownId.Audio, audioItem) }
                }
                Item {
                    id: moonItem
                    visible: home.nightLightState ? home.nightLightState.enabled : false
                    width: 32; height: 36
                    StatusGlyph { anchors.centerIn: parent; kind: "moon"; color: home.ink }
                    MouseArea { anchors.fill: parent; onClicked: home.dropdownRequested(Enums.DropdownId.NightLight, moonItem) }
                }
                Item {
                    id: batItem
                    visible: home.batteryState ? home.batteryState.present : false
                    width: batLabel.implicitWidth + 16; height: 36
                    Label {
                        id: batLabel
                        anchors.centerIn: parent
                        text: home.batteryState ? Math.round(home.batteryState.percent) + "%" : ""
                        role: Enums.TextRole.Bar
                        color: home.batteryState && home.batteryState.severity !== Enums.Severity.Neutral ? Tokens.colorFor(home.batteryState.severity) : home.ink
                        tabularNumbers: true
                    }
                    MouseArea { anchors.fill: parent; onClicked: home.dropdownRequested(Enums.DropdownId.Battery, batItem) }
                }
            }
        }
    }
}
