pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components
import qs.services

// Style paper: a large time, the workspaces as ovals, a row of round keys, two sliders and the music.
Item {
    id: paper

    required property var card

    implicitHeight: column.implicitHeight + 40

    Column {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
        spacing: 16

        Item {
            width: parent.width
            height: 56
            Label { anchors { left: parent.left; verticalCenter: parent.verticalCenter } text: paper.card.timeText; tabularNumbers: true; font.pixelSize: 54; font.weight: Font.Bold; color: paper.card.ink }
            Column {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                Label { anchors.right: parent.right; text: paper.card.english.toString(new Date(), "dddd"); role: Enums.TextRole.Bar; color: paper.card.ink; font.weight: Font.Medium }
                Label { anchors.right: parent.right; text: paper.card.english.toString(new Date(), "d MMMM"); role: Enums.TextRole.Bar; color: paper.card.inkSoft }
            }
        }

        Item {
            width: parent.width
            height: 28
            WorkspaceBubbles {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                numbered: false
                oval: true
                ovalWidth: 34; ovalHeight: 10
                workspaces: paper.card.workspaces
                ink: paper.card.ink; inkSoft: paper.card.inkSoft; inkOn: paper.card.inkOn
                cellHeight: 28; cellWidth: 40
                onWorkspaceClicked: id => Compositor.focusWorkspace(id)
            }
            Label {
                visible: paper.card.batteryState && paper.card.batteryState.present
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: paper.card.batteryState ? Math.round(paper.card.batteryState.percent) + "%" : ""
                role: Enums.TextRole.Bar
                color: paper.card.batteryState && paper.card.batteryState.severity !== Enums.Severity.Neutral ? Tokens.colorFor(paper.card.batteryState.severity) : paper.card.inkSoft
                tabularNumbers: true
            }
        }

        Row {
            width: parent.width
            spacing: (width - 5 * 44) / 4
            CardPill {
                round: true; kind: "wifi"
                checked: paper.card.networkState ? paper.card.networkState.wifiEnabled : false
                open: paper.card.expanded === "wifi"
                ink: paper.card.ink; fill: paper.card.fill; line: paper.card.line
                onClicked: paper.card.toggleSection("wifi")
            }
            CardPill {
                round: true; kind: "bluetooth"
                checked: paper.card.bluetoothState ? paper.card.bluetoothState.powered : false
                open: paper.card.expanded === "bluetooth"
                ink: paper.card.ink; fill: paper.card.fill; line: paper.card.line
                onClicked: paper.card.toggleSection("bluetooth")
            }
            CardPill {
                round: true; kind: "moon"
                checked: paper.card.nightLightState ? paper.card.nightLightState.enabled : false
                ink: paper.card.ink; fill: paper.card.fill; line: paper.card.line
                onClicked: if (paper.card.nightLightState) paper.card.nightLightState.setEnabled(!paper.card.nightLightState.enabled)
            }
            CardPill {
                round: true; kind: "focus"
                checked: paper.card.focusState ? paper.card.focusState.active : false
                ink: paper.card.ink; fill: paper.card.fill; line: paper.card.line
                onClicked: if (paper.card.focusState) paper.card.focusState.toggle()
            }
            CardPill {
                round: true; kind: "cup"
                checked: paper.card.caffeineState ? paper.card.caffeineState.active : false
                ink: paper.card.ink; fill: paper.card.fill; line: paper.card.line
                onClicked: if (paper.card.caffeineState) paper.card.caffeineState.toggle()
            }
        }

        Column {
            width: parent.width
            IslandSlider {
                width: parent.width
                iconName: "volume"
                ink: paper.card.ink; line: paper.card.line
                value: paper.card.audioState ? (paper.card.audioState.muted ? 0 : paper.card.audioState.volume) : 0
                onMoved: v => { const a = paper.card.audioState; if (a) { if (a.muted) a.setMuted(false); a.setVolume(v) } }
                onIconClicked: if (paper.card.audioState) paper.card.audioState.toggleMute()
            }
            IslandSlider {
                width: parent.width
                iconName: "sun"
                ink: paper.card.ink; line: paper.card.line
                value: paper.card.displayState ? paper.card.displayState.brightness : 0
                onMoved: v => { if (paper.card.displayState) paper.card.displayState.setBrightness(v) }
            }
        }

        IslandMedia {
            visible: paper.card.playerShown
            width: parent.width
            height: visible ? implicitHeight : 0
            mediaState: paper.card.mediaState
            ink: paper.card.ink; inkSoft: paper.card.inkSoft; line: paper.card.line
        }
    }
}
