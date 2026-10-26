pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.components
import qs.services

// Style dashboard: time on the left, volume and brightness on the right, the switches as pills, the music and a foot row.
Item {
    id: dash

    required property var card

    implicitHeight: column.implicitHeight + 36

    Column {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
        spacing: 14

        Item {
            width: parent.width
            height: 84
            Column {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: 2
                Label { text: dash.card.timeText; color: dash.card.ink; tabularNumbers: true; font.pixelSize: 46; font.weight: Font.DemiBold }
                Label { text: dash.card.dateText; role: Enums.TextRole.Bar; color: dash.card.inkSoft }
            }
            Column {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 170
                spacing: 4
                IslandSlider {
                    width: parent.width
                    iconName: "volume"
                    ink: dash.card.ink; line: dash.card.line
                    value: dash.card.audioState ? (dash.card.audioState.muted ? 0 : dash.card.audioState.volume) : 0
                    onMoved: v => { const a = dash.card.audioState; if (a) { if (a.muted) a.setMuted(false); a.setVolume(v) } }
                    onIconClicked: if (dash.card.audioState) dash.card.audioState.toggleMute()
                }
                IslandSlider {
                    width: parent.width
                    iconName: "sun"
                    ink: dash.card.ink; line: dash.card.line
                    value: dash.card.displayState ? dash.card.displayState.brightness : 0
                    onMoved: v => { if (dash.card.displayState) dash.card.displayState.setBrightness(v) }
                }
            }
        }

        Flow {
            width: parent.width
            spacing: 6
            CardPill {
                kind: "wifi"; label: "Wi-Fi"
                checked: dash.card.networkState ? dash.card.networkState.wifiEnabled : false
                open: dash.card.expanded === "wifi"
                ink: dash.card.ink; fill: dash.card.fill; line: dash.card.line
                onClicked: dash.card.toggleSection("wifi")
            }
            CardPill {
                kind: "bluetooth"; label: "Bluetooth"
                checked: dash.card.bluetoothState ? dash.card.bluetoothState.powered : false
                open: dash.card.expanded === "bluetooth"
                ink: dash.card.ink; fill: dash.card.fill; line: dash.card.line
                onClicked: dash.card.toggleSection("bluetooth")
            }
            CardPill {
                kind: "focus"; label: "Focus"
                checked: dash.card.focusState ? dash.card.focusState.active : false
                ink: dash.card.ink; fill: dash.card.fill; line: dash.card.line
                onClicked: if (dash.card.focusState) dash.card.focusState.toggle()
            }
            CardPill {
                kind: "moon"; label: "Night"
                checked: dash.card.nightLightState ? dash.card.nightLightState.enabled : false
                ink: dash.card.ink; fill: dash.card.fill; line: dash.card.line
                onClicked: if (dash.card.nightLightState) dash.card.nightLightState.setEnabled(!dash.card.nightLightState.enabled)
            }
            CardPill {
                kind: "cup"; label: "Caffeine"
                checked: dash.card.caffeineState ? dash.card.caffeineState.active : false
                ink: dash.card.ink; fill: dash.card.fill; line: dash.card.line
                onClicked: if (dash.card.caffeineState) dash.card.caffeineState.toggle()
            }
        }

        IslandMedia {
            visible: dash.card.playerShown
            width: parent.width
            height: visible ? implicitHeight : 0
            mediaState: dash.card.mediaState
            ink: dash.card.ink; inkSoft: dash.card.inkSoft; line: dash.card.line
        }

        Item {
            width: parent.width
            height: 36
            WorkspaceBubbles {
                visible: dash.card.workspaceStyle !== "numbers"
                numbered: dash.card.workspaceStyle === "bubbles"
                oval: dash.card.workspaceStyle === "ovals"
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                workspaces: dash.card.workspaces
                ink: dash.card.ink; inkSoft: dash.card.inkSoft; inkOn: dash.card.inkOn
                cellHeight: 36; cellWidth: 28
                onWorkspaceClicked: id => Compositor.focusWorkspace(id)
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 12
                Label {
                    visible: dash.card.batteryState && dash.card.batteryState.present
                    anchors.verticalCenter: parent.verticalCenter
                    text: dash.card.batteryState ? Math.round(dash.card.batteryState.percent) + "%  " + dash.card.batteryState.statusText() : ""
                    role: Enums.TextRole.Bar
                    color: dash.card.inkSoft
                    tabularNumbers: true
                }
                IslandButton { anchors.verticalCenter: parent.verticalCenter; kind: "sliders"; color: dash.card.ink; onClicked: dash.card.controlCenterRequested() }
            }
        }
    }
}
