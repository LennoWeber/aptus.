pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components
import qs.services

// Style bento: tiles with one job each. The time is the one tile filled with ink, the rest sit quietly on the card.
Item {
    id: bento

    required property var card

    readonly property real gap: 8
    readonly property var timeParts: card.timeText.split(":")

    implicitHeight: column.implicitHeight + 28

    // A quiet tile.
    component Tile: Rectangle {
        radius: 18
        color: bento.card.tileColor
    }

    // A switch tile: glyph above, label and state below; on = filled with ink.
    component SwitchTile: Rectangle {
        id: st
        property string kind
        property string label
        property string sub
        property bool checked
        property bool open
        property bool compact        // glyph and text side by side, for a low tile
        signal clicked()
        radius: 18
        color: checked ? bento.card.ink : bento.card.tileColor
        border.width: open ? 2 : 0
        border.color: bento.card.ink
        Behavior on color { ColorAnimation { duration: Tokens.durFast } }
        StatusGlyph { anchors { left: parent.left; top: st.compact ? undefined : parent.top; verticalCenter: st.compact ? parent.verticalCenter : undefined; margins: 12 } kind: st.kind; color: st.checked ? bento.card.fill : bento.card.ink }
        Column {
            anchors { left: parent.left; right: parent.right; bottom: st.compact ? undefined : parent.bottom; verticalCenter: st.compact ? parent.verticalCenter : undefined; margins: 12; leftMargin: st.compact ? 38 : 12 }
            Label { width: parent.width; text: st.label; role: Enums.TextRole.Bar; font.weight: Font.DemiBold; elide: Text.ElideRight; color: st.checked ? bento.card.fill : bento.card.ink }
            Label { width: parent.width; text: st.sub; role: Enums.TextRole.Bar; font.pixelSize: 10; elide: Text.ElideRight; color: st.checked ? bento.card.fill : bento.card.inkSoft; opacity: 0.85 }
        }
        MouseArea { anchors.fill: parent; onClicked: st.clicked() }
    }

    Column {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: bento.gap

        // Time and music, battery and volume.
        Row {
            width: parent.width
            height: 150
            spacing: bento.gap

            Rectangle {
                id: clockTile
                width: 168
                height: parent.height
                radius: 18
                color: bento.card.ink
                Label { anchors { left: parent.left; top: parent.top; margins: 14 } text: bento.card.english.toString(new Date(), "dddd"); role: Enums.TextRole.Bar; font.pixelSize: 11; color: bento.card.fill; opacity: 0.6 }
                Column {
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter; verticalCenterOffset: -4 }
                    spacing: -6
                    Label { text: bento.timeParts[0]; tabularNumbers: true; font.pixelSize: 46; font.weight: Font.Bold; color: bento.card.fill }
                    Label { text: bento.timeParts.length > 1 ? bento.timeParts[1] : ""; tabularNumbers: true; font.pixelSize: 46; font.weight: Font.Bold; color: bento.card.fill }
                }
                WorkspaceBubbles {
                    anchors { left: parent.left; leftMargin: 8; bottom: parent.bottom; bottomMargin: 4 }
                    width: parent.width - 16
                    clip: true
                    numbered: false
                    oval: true
                    workspaces: bento.card.workspaces
                    ink: bento.card.fill; inkSoft: bento.card.fill; inkOn: bento.card.ink
                    cellHeight: 28; cellWidth: 22; ovalWidth: 20
                    onWorkspaceClicked: id => Compositor.focusWorkspace(id)
                }
            }

            Column {
                width: parent.width - clockTile.width - bento.gap
                spacing: bento.gap

                Tile {
                    width: parent.width
                    height: 70
                    Rectangle {
                        id: cover
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        width: 50; height: 50; radius: 12
                        color: bento.card.line
                        clip: true
                        Image { anchors.fill: parent; source: bento.card.mediaState ? bento.card.mediaState.artUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                    }
                    Column {
                        anchors { left: cover.right; leftMargin: 10; right: playBtn.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
                        Label { width: parent.width; text: bento.card.playerShown ? bento.card.mediaState.title : "Nothing playing"; elide: Text.ElideRight; font.weight: Font.DemiBold; color: bento.card.ink }
                        Label { width: parent.width; text: bento.card.playerShown ? bento.card.mediaState.artist : ""; role: Enums.TextRole.Bar; elide: Text.ElideRight; color: bento.card.inkSoft }
                    }
                    IslandButton {
                        id: playBtn
                        visible: bento.card.playerShown
                        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                        kind: bento.card.playerShown && bento.card.mediaState.playing ? "pause" : "play"
                        color: bento.card.ink
                        onClicked: bento.card.mediaState.playPause()
                    }
                }

                Row {
                    width: parent.width
                    height: 72
                    spacing: bento.gap
                    Tile {
                        width: 84
                        height: parent.height
                        visible: bento.card.batteryState && bento.card.batteryState.present
                        Canvas {
                            id: ring
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 10 }
                            width: 44; height: 44
                            readonly property real level: bento.card.batteryState ? bento.card.batteryState.percent / 100 : 0
                            onLevelChanged: requestPaint()
                            property color ringInk: bento.card.ink
                            onRingInkChanged: requestPaint()
                            onPaint: {
                                const c = getContext("2d")
                                c.reset()
                                c.lineWidth = 5
                                c.lineCap = "round"
                                c.strokeStyle = Qt.rgba(ringInk.r, ringInk.g, ringInk.b, 0.15)
                                c.beginPath(); c.arc(22, 22, 18, 0, Math.PI * 2); c.stroke()
                                c.strokeStyle = ringInk
                                c.beginPath(); c.arc(22, 22, 18, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0.02, level)); c.stroke()
                            }
                        }
                        Label { anchors { left: ring.right; leftMargin: 6; verticalCenter: parent.verticalCenter } text: bento.card.batteryState ? Math.round(bento.card.batteryState.percent) + "" : ""; font.weight: Font.DemiBold; tabularNumbers: true; color: bento.card.ink }
                    }
                    Tile {
                        width: parent.width - (bento.card.batteryState && bento.card.batteryState.present ? 84 + bento.gap : 0)
                        height: parent.height
                        Label { anchors { left: parent.left; top: parent.top; margins: 12 } text: "Volume"; role: Enums.TextRole.Bar; font.pixelSize: 11; color: bento.card.inkSoft }
                        IslandSlider {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 }
                            iconName: "volume"
                            ink: bento.card.ink; line: bento.card.line
                            value: bento.card.audioState ? (bento.card.audioState.muted ? 0 : bento.card.audioState.volume) : 0
                            onMoved: v => { const a = bento.card.audioState; if (a) { if (a.muted) a.setMuted(false); a.setVolume(v) } }
                            onIconClicked: if (bento.card.audioState) bento.card.audioState.toggleMute()
                        }
                    }
                }
            }
        }

        // The switches.
        Row {
            width: parent.width
            height: 76
            spacing: bento.gap
            readonly property real cellW: (width - 3 * bento.gap) / 4
            SwitchTile {
                width: parent.cellW; height: parent.height
                kind: "wifi"; label: "Wi-Fi"
                sub: bento.card.networkState && bento.card.networkState.wifiEnabled ? (bento.card.networkState.ssid || "Not connected") : "Off"
                checked: bento.card.networkState ? bento.card.networkState.wifiEnabled : false
                open: bento.card.expanded === "wifi"
                onClicked: bento.card.toggleSection("wifi")
            }
            SwitchTile {
                width: parent.cellW; height: parent.height
                kind: "bluetooth"; label: "Bluetooth"
                sub: bento.card.bluetoothState && bento.card.bluetoothState.powered ? (bento.card.bluetoothState.connectedCount > 0 ? bento.card.bluetoothState.connectedCount + " connected" : "On") : "Off"
                checked: bento.card.bluetoothState ? bento.card.bluetoothState.powered : false
                open: bento.card.expanded === "bluetooth"
                onClicked: bento.card.toggleSection("bluetooth")
            }
            SwitchTile {
                width: parent.cellW; height: parent.height
                kind: "moon"; label: "Night"
                sub: bento.card.nightLightState && bento.card.nightLightState.enabled ? "On" : "Off"
                checked: bento.card.nightLightState ? bento.card.nightLightState.enabled : false
                onClicked: if (bento.card.nightLightState) bento.card.nightLightState.setEnabled(!bento.card.nightLightState.enabled)
            }
            SwitchTile {
                width: parent.cellW; height: parent.height
                kind: "focus"; label: "Focus"
                sub: bento.card.focusState && bento.card.focusState.active ? "On" : "Off"
                checked: bento.card.focusState ? bento.card.focusState.active : false
                onClicked: if (bento.card.focusState) bento.card.focusState.toggle()
            }
        }

        // Brightness and caffeine.
        Row {
            width: parent.width
            height: 56
            spacing: bento.gap
            Tile {
                width: parent.width - 150 - bento.gap
                height: parent.height
                IslandSlider {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 14 }
                    iconName: "sun"
                    ink: bento.card.ink; line: bento.card.line
                    value: bento.card.displayState ? bento.card.displayState.brightness : 0
                    onMoved: v => { if (bento.card.displayState) bento.card.displayState.setBrightness(v) }
                }
            }
            SwitchTile {
                width: 150; height: parent.height
                kind: "cup"; label: "Caffeine"; compact: true
                sub: bento.card.caffeineState && bento.card.caffeineState.active ? "On" : "Off"
                checked: bento.card.caffeineState ? bento.card.caffeineState.active : false
                onClicked: if (bento.card.caffeineState) bento.card.caffeineState.toggle()
            }
        }
    }
}
