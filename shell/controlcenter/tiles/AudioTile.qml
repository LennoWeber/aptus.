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

    // One program: name, level, mute on the right.
    component AppRow: Item {
        id: app
        required property var modelData
        width: parent ? parent.width : 0
        height: 58
        Label {
            anchors { left: parent.left; right: mute.left; rightMargin: 10; top: parent.top; topMargin: 4 }
            elide: Text.ElideRight
            text: app.modelData.name
            font.weight: Font.Medium
            color: app.modelData.muted ? Tokens.inkFaint : Tokens.ink
        }
        SliderControl {
            anchors { left: parent.left; right: mute.left; rightMargin: 10; bottom: parent.bottom; bottomMargin: 2 }
            value: app.modelData.volume
            opacity: app.modelData.muted ? 0.45 : 1
            onMoved: v => tile.audioState.setAppVolume(app.modelData.id, v)
        }
        Item {
            id: mute
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 40
            height: 40
            StatusGlyph {
                anchors.centerIn: parent
                width: 20
                height: 20
                kind: "volume"
                muted: app.modelData.muted
                level: app.modelData.volume
                color: app.modelData.muted ? Tokens.critical : Tokens.inkSoft
            }
            MouseArea {
                anchors.fill: parent
                onClicked: tile.audioState.setAppMuted(app.modelData.id, !app.modelData.muted)
            }
        }
    }

    // Expanded: output, input and the programs, three columns across the full width.
    Item {
        anchors.fill: parent
        visible: tile.expanded
        readonly property real colWidth: (width - 2 * 49) / 3

        DeviceColumn {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: parent.colWidth
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
            anchors { left: parent.left; leftMargin: parent.colWidth + 24; top: parent.top; bottom: parent.bottom }
            width: 1
            color: Tokens.line
        }

        DeviceColumn {
            anchors { left: divider.right; leftMargin: 24; top: parent.top; bottom: parent.bottom }
            width: parent.colWidth
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

        Rectangle {
            id: divider2
            anchors { left: parent.left; leftMargin: 2 * parent.colWidth + 73; top: parent.top; bottom: parent.bottom }
            width: 1
            color: Tokens.line
        }

        Item {
            anchors { left: divider2.right; leftMargin: 24; top: parent.top; bottom: parent.bottom; right: parent.right }

            Label {
                id: appsHead
                text: "Apps"
                role: Enums.TextRole.Bar
                color: Tokens.inkFaint
            }
            Flickable {
                anchors { top: appsHead.bottom; topMargin: 6; left: parent.left; right: parent.right; bottom: parent.bottom }
                contentHeight: appList.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: appList
                    width: parent.width
                    Repeater {
                        model: tile.audioState ? tile.audioState.apps : []
                        delegate: AppRow {}
                    }
                    Label {
                        visible: tile.audioState && tile.audioState.apps.length === 0
                        text: "Nothing is playing"
                        color: Tokens.inkFaint
                    }
                }
            }
        }
    }
}
