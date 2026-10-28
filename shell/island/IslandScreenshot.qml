pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.services
import qs.components

// Screenshot view: region, screen, window, and screen recording (start and stop).
FocusScope {
    id: shot

    property var captureState  // CaptureState
    property int selectedIndex
    property var actions: defaultActions       // { id, label, glyph }
    property color ink
    property color inkSoft
    property color line
    property real outerRadius: 22       // corner radius of the island body: inner shapes take outerRadius minus their margin

    signal closeRequested()

    readonly property real cellMargin: 14     // distance of the tiles from the body's edge
    readonly property real cellSpacing: 10

    // Width of one tile when count tiles share a row of total px: margins left and right, spacing between.
    function cellWidth(total: real, count: int): real {
        if (!(count > 0)) throw new Error("invariant: IslandScreenshot.cellWidth: there must be at least one tile")
        return (total - 2 * cellMargin - (count - 1) * cellSpacing) / count
    }

    readonly property var defaultActions: [
        { id: "region", label: "Region", glyph: "region" },
        { id: "screen", label: "Screen", glyph: "screen" },
        { id: "window", label: "Window", glyph: "window" },
        { id: "record", label: "Record", glyph: "record" }
    ]

    // Take the screenshot or start / stop the recording; the island closes first so it is not in the picture.
    function run(actionId: string): void {
        closeRequested()
        if (!captureState) return
        if (actionId === "record") {
            if (captureState.recording) captureState.stopRecording()
            else captureState.startRecording("screen")
        } else captureState.screenshot(actionId)
    }

    function moveSelection(delta: int): void {
        selectedIndex = (selectedIndex + delta + actions.length) % actions.length
    }

    function activateSelected(): void {
        run(actions[selectedIndex].id)
    }

    function reset(): void {
        selectedIndex = 0
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left) { moveSelection(-1); event.accepted = true }
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) { moveSelection(1); event.accepted = true }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { activateSelected(); event.accepted = true }
        else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_4) { selectedIndex = event.key - Qt.Key_1; activateSelected(); event.accepted = true }
    }

    Row {
        x: shot.cellMargin
        y: shot.cellMargin
        spacing: shot.cellSpacing

        Repeater {
            model: shot.actions
            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool isSelected: shot.selectedIndex === index
                readonly property bool isRecording: modelData.id === "record" && shot.captureState && shot.captureState.recording
                width: shot.cellWidth(shot.width, shot.actions.length)
                height: shot.height - 2 * shot.cellMargin

                Rectangle {
                    anchors.fill: parent
                    radius: Math.max(4, shot.outerRadius - shot.cellMargin)
                    color: shot.ink
                    opacity: tap.pressed ? 0.16 : (tap.containsMouse || cell.isSelected) ? 0.09 : 0.04
                    Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Math.max(4, shot.outerRadius - shot.cellMargin)
                    color: "transparent"
                    border.width: cell.isSelected ? 1 : 0
                    border.color: shot.ink
                }

                // The shapes are drawn here, small and plain.
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(parent.height / 2 - 30)
                    width: 32
                    height: 28
                    Rectangle {
                        visible: cell.modelData.id === "region"
                        anchors.fill: parent
                        color: "transparent"
                        border.width: 1.5
                        border.color: shot.ink
                        radius: 3
                        opacity: 0.9
                        Rectangle { anchors.centerIn: parent; width: 10; height: 10; color: "transparent"; border.width: 1; border.color: shot.ink; radius: 1 }
                    }
                    Rectangle {
                        visible: cell.modelData.id === "screen"
                        anchors.fill: parent
                        color: "transparent"
                        border.width: 1.5
                        border.color: shot.ink
                        radius: 3
                    }
                    Rectangle {
                        visible: cell.modelData.id === "window"
                        x: 4; y: 2; width: 24; height: 22
                        color: "transparent"
                        border.width: 1.5
                        border.color: shot.ink
                        radius: 3
                        Rectangle { x: 0; y: 5; width: parent.width; height: 1.5; color: shot.ink }
                    }
                    Rectangle {
                        visible: cell.modelData.id === "record"
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        radius: cell.isRecording ? 3 : 9
                        color: Tokens.critical
                        Behavior on radius { NumberAnimation { duration: Tokens.durFast } }
                    }
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(parent.height / 2 + 8)
                    text: cell.isRecording ? "Stop" : cell.modelData.label
                    color: shot.ink
                    font.weight: Font.Medium
                }
                MouseArea {
                    id: tap
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { shot.selectedIndex = cell.index; shot.run(cell.modelData.id) }
                }
            }
        }
    }
}
