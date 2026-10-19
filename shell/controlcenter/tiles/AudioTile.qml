pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the AudioTile.
Item {
    id: tile

    property bool expanded
    property var audioState

    // One side of the detail view: a device kind with level, mute and device list.
    component DeviceColumn: Item {
        id: col
        property string title
        property string glyph
        property real volume
        property bool muted
        property string deviceName
        property var devices
        property string muteLabel
        signal volumeMoved(real value)
        signal muteToggled(bool on)
        signal deviceChosen(string deviceId)

        Column {
            id: head
            width: parent.width
            spacing: 4

            Label {
                text: col.title
                role: Enums.TextRole.Bar
                color: Tokens.inkFaint
            }
            Label {
                width: parent.width
                elide: Text.ElideRight
                text: col.deviceName
                font.weight: Font.Medium
            }
            Item { width: 1; height: 8 }
            Row {
                spacing: 12
                StatusGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    kind: col.glyph
                    muted: col.muted
                    level: col.volume
                    color: col.muted ? Tokens.critical : Tokens.ink
                }
                Label {
                    text: Math.round(col.volume * 100) + "%"
                    role: Enums.TextRole.Display
                    tabularNumbers: true
                    color: col.muted ? Tokens.inkFaint : Tokens.ink
                }
            }
            SliderControl {
                width: parent.width
                value: col.volume
                opacity: col.muted ? 0.45 : 1
                onMoved: v => col.volumeMoved(v)
            }
            ToggleSwitch {
                width: parent.width
                label: col.muteLabel
                checked: col.muted
                onToggled: on => col.muteToggled(on)
            }
            Item { width: 1; height: 10 }
            Label {
                text: "Devices"
                role: Enums.TextRole.Bar
                color: Tokens.inkFaint
            }
        }

        // The device list takes the rest of the height.
        Flickable {
            anchors { top: head.bottom; topMargin: 2; left: parent.left; right: parent.right; bottom: parent.bottom }
            contentHeight: devs.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: devs
                width: parent.width
                Repeater {
                    model: col.devices
                    delegate: ListRow {
                        required property var modelData
                        width: devs.width
                        title: modelData.name
                        selected: modelData.active
                        onClicked: col.deviceChosen(modelData.id)
                    }
                }
            }
        }
    }

    // Compact: percentage and speaker on one row, slider below. Muted is shown by the dimmed number and the crossed speaker.
    Item {
        anchors.fill: parent
        visible: !tile.expanded

        Label {
            y: -4
            text: tile.audioState ? Math.round(tile.audioState.volume * 100) + "%" : ""
            role: Enums.TextRole.Display
            tabularNumbers: true
            color: tile.audioState && tile.audioState.muted ? Tokens.inkFaint : Tokens.ink
        }
        StatusGlyph {
            anchors { right: parent.right; top: parent.top; topMargin: 2 }
            kind: "volume"
            level: tile.audioState ? tile.audioState.volume : 0
            muted: tile.audioState ? tile.audioState.muted : false
            color: tile.audioState && tile.audioState.muted ? Tokens.critical : Tokens.ink
        }
        SliderControl {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: -4 }
            value: tile.audioState ? tile.audioState.volume : 0
            opacity: tile.audioState && tile.audioState.muted ? 0.45 : 1
            onMoved: v => tile.audioState.setVolume(v)
        }
    }

    // Expanded: output on the left, input on the right, the full width in use.
    Item {
        anchors.fill: parent
        visible: tile.expanded

        DeviceColumn {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: divider.left; rightMargin: 24 }
            title: "Output"
            glyph: "volume"
            volume: tile.audioState ? tile.audioState.volume : 0
            muted: tile.audioState ? tile.audioState.muted : false
            deviceName: tile.audioState ? tile.audioState.outputName : ""
            devices: tile.audioState ? tile.audioState.outputs : []
            muteLabel: "Mute"
            onVolumeMoved: v => tile.audioState.setVolume(v)
            onMuteToggled: on => tile.audioState.setMuted(on)
            onDeviceChosen: deviceId => tile.audioState.setOutput(deviceId)
        }

        Rectangle {
            id: divider
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; bottom: parent.bottom }
            width: 1
            color: Tokens.line
        }

        DeviceColumn {
            anchors { left: divider.right; leftMargin: 24; top: parent.top; bottom: parent.bottom; right: parent.right }
            title: "Input"
            glyph: "mic"
            volume: tile.audioState ? tile.audioState.inputVolume : 0
            muted: tile.audioState ? tile.audioState.inputMuted : false
            deviceName: tile.audioState ? tile.audioState.inputName : ""
            devices: tile.audioState ? tile.audioState.inputs : []
            muteLabel: "Mute microphone"
            onVolumeMoved: v => tile.audioState.setInputVolume(v)
            onMuteToggled: on => tile.audioState.toggleInputMute()
            onDeviceChosen: deviceId => tile.audioState.setInput(deviceId)
        }
    }
}
