pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the audio dropdown.
Item {
    id: dd

    property var audioState
    signal moreRequested(int tileId)  // opens the control center on a tile

    implicitWidth: 300
    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: 2

        Label {
            text: "Output"
            role: Enums.TextRole.Bar
            color: Tokens.inkFaint
        }

        Row {
            width: parent.width
            spacing: 8
            StatusGlyph {
                anchors.verticalCenter: parent.verticalCenter
                kind: "volume"
                level: dd.audioState ? dd.audioState.volume : 0
                muted: dd.audioState ? dd.audioState.muted : false
                color: Tokens.ink
            }
            SliderControl {
                width: parent.width - 16 - 8 - 44 - 8
                value: dd.audioState ? dd.audioState.volume : 0
                onMoved: v => dd.audioState.setVolume(v)
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                horizontalAlignment: Text.AlignRight
                text: dd.audioState ? Math.round(dd.audioState.volume * 100) + "%" : ""
                color: Tokens.inkSoft
            }
        }

        ToggleSwitch {
            width: parent.width
            label: "Mute"
            checked: dd.audioState ? dd.audioState.muted : false
            onToggled: on => dd.audioState.setMuted(on)
        }

        Repeater {
            model: dd.audioState ? dd.audioState.outputs : []
            delegate: ListRow {
                required property var modelData
                width: column.width
                title: modelData.name
                selected: modelData.active
                onClicked: dd.audioState.setOutput(modelData.id)
            }
        }

        Item { width: 1; height: 10 }

        Label {
            text: "Input"
            role: Enums.TextRole.Bar
            color: Tokens.inkFaint
        }

        Row {
            width: parent.width
            spacing: 8
            StatusGlyph {
                anchors.verticalCenter: parent.verticalCenter
                kind: "mic"
                color: dd.audioState && dd.audioState.inputMuted ? Tokens.inkFaint : Tokens.ink
            }
            SliderControl {
                width: parent.width - 16 - 8 - 44 - 8
                value: dd.audioState ? dd.audioState.inputVolume : 0
                onMoved: v => dd.audioState.setInputVolume(v)
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                horizontalAlignment: Text.AlignRight
                text: dd.audioState ? Math.round(dd.audioState.inputVolume * 100) + "%" : ""
                color: Tokens.inkSoft
            }
        }

        ToggleSwitch {
            width: parent.width
            label: "Mute microphone"
            checked: dd.audioState ? dd.audioState.inputMuted : false
            onToggled: dd.audioState.toggleInputMute()
        }

        Repeater {
            model: dd.audioState ? dd.audioState.inputs : []
            delegate: ListRow {
                required property var modelData
                width: column.width
                title: modelData.name
                selected: modelData.active
                onClicked: dd.audioState.setInput(modelData.id)
            }
        }

        Item { width: 1; height: 6 }
        ActionButton {
            text: "More"
            onClicked: dd.moreRequested(Enums.TileId.Audio)
        }
    }
}
