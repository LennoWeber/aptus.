import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the CaptureTile. Compact: state; expanded: screenshots and recordings.
Item {
    id: tile

    property bool expanded
    property var captureState

    readonly property bool recording: captureState ? captureState.recording : false

    function clock(seconds: int): string {
        const m = Math.floor(seconds / 60)
        const s = seconds % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    Item {
        anchors.fill: parent
        visible: !tile.expanded

        StatusGlyph {
            kind: "capture"
            width: 24
            height: 24
            color: tile.recording ? Tokens.critical : Tokens.inkSoft
        }
        Label {
            anchors { left: parent.left; bottom: parent.bottom }
            text: tile.recording ? "Stop " + tile.clock(tile.captureState.recordingSec) : "Ready"
            font.weight: tile.recording ? Font.DemiBold : Font.Normal
            color: tile.recording ? Tokens.critical : Tokens.inkSoft
        }
    }

    Item {
        anchors.fill: parent
        visible: tile.expanded

        Column {
            width: Math.min(parent.width, 520)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Label { text: "Screenshot"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
            Row {
                spacing: 8
                ActionButton { text: "Whole screen"; onClicked: tile.captureState.screenshot("screen") }
                ActionButton { text: "Region"; onClicked: tile.captureState.screenshot("region") }
                ActionButton { text: "Active window"; onClicked: tile.captureState.screenshot("window") }
            }
            Label {
                width: parent.width
                wrapMode: Text.Wrap
                text: "Saved to " + (tile.captureState ? tile.captureState.saveDirectory : "") + " and copied to the clipboard."
                color: Tokens.inkSoft
            }
            Row {
                spacing: 8
                ActionButton { text: "Open folder"; onClicked: tile.captureState.openFolder() }
                ActionButton { text: "Open last"; active: tile.captureState && tile.captureState.lastCapturePath !== ""; onClicked: tile.captureState.openLast() }
            }
            Label {
                visible: tile.captureState && tile.captureState.lastCapturePath !== ""
                width: parent.width
                elide: Text.ElideMiddle
                text: tile.captureState ? "Last: " + tile.captureState.lastCapturePath : ""
                role: Enums.TextRole.Bar
                color: Tokens.inkFaint
            }
            Label {
                visible: tile.captureState && tile.captureState.lastError !== ""
                width: parent.width
                wrapMode: Text.Wrap
                text: tile.captureState ? "Last attempt failed: " + tile.captureState.lastError : ""
                color: Tokens.warn
            }

            Item { width: 1; height: 12 }
            Label { text: "Screen recording"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
            Row {
                visible: !tile.recording
                spacing: 8
                ActionButton { text: "Record screen"; onClicked: tile.captureState.startRecording("screen") }
                ActionButton { text: "Record region"; onClicked: tile.captureState.startRecording("region") }
            }
            ToggleSwitch {
                visible: !tile.recording
                width: parent.width
                label: "Record audio"
                checked: tile.captureState ? tile.captureState.recordAudio : false
                onToggled: on => tile.captureState.recordAudio = on
            }
            Row {
                visible: tile.recording
                spacing: 12
                ActionButton { text: "Stop recording"; primary: true; onClicked: tile.captureState.stopRecording() }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tile.clock(tile.captureState ? tile.captureState.recordingSec : 0)
                    role: Enums.TextRole.Title
                    tabularNumbers: true
                    color: Tokens.critical
                }
            }

            Label {
                visible: tile.captureState && tile.captureState.missingTools !== ""
                width: parent.width
                wrapMode: Text.Wrap
                color: Tokens.warn
                text: tile.captureState ? "Missing tools: " + tile.captureState.missingTools + ". Install them with your package manager (dnf install grim slurp wl-clipboard wf-recorder)." : ""
            }
        }
    }
}
