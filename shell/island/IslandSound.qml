pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// The Sound section of the quick settings card: the output devices, a tap makes one the output.
FocusScope {
    id: sound

    property var audioState
    property bool shown                 // true while the section is open
    property int maxRows: 5
    property color ink
    property color inkSoft
    property color line
    property color fill

    readonly property var rows: audioState ? audioState.outputs.slice(0, maxRows) : []

    implicitHeight: column.implicitHeight
    Keys.onEscapePressed: closeRequested()

    signal closeRequested()

    // A tap on a device: it becomes the output.
    function setOutput(outputId: string): void {
        if (!outputId) throw new Error("invariant: IslandSound.setOutput: empty output id")
        if (!audioState) throw new Error("invariant: IslandSound.setOutput: no audio state")
        audioState.setOutput(outputId)
    }

    Column {
        id: column
        width: parent.width

        Label {
            visible: sound.rows.length === 0
            height: visible ? 30 : 0
            verticalAlignment: Text.AlignVCenter
            text: "No output devices"
            role: Enums.TextRole.Bar
            color: sound.inkSoft
        }
        Repeater {
            model: sound.rows
            delegate: Item {
                id: entry
                required property var modelData
                width: column.width
                height: 34
                Rectangle {
                    visible: entry.modelData.active
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: 6; height: 6; radius: 3
                    color: Tokens.ok
                }
                Label {
                    anchors { left: parent.left; leftMargin: 14; right: parent.right; verticalCenter: parent.verticalCenter }
                    text: entry.modelData.name
                    role: Enums.TextRole.Bar
                    elide: Text.ElideRight
                    color: sound.ink
                    font.weight: entry.modelData.active ? Font.DemiBold : Font.Normal
                }
                MouseArea { anchors.fill: parent; onClicked: sound.setOutput(entry.modelData.id) }
            }
        }
    }
}
