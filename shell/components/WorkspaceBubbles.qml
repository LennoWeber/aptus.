pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme

// A row of workspace bubbles: an empty workspace is a thin ring, an occupied one a filled dot, the active one a larger
// bubble with its number. Used by the bar and the island (setting bar.workspaceStyle = bubbles).
Item {
    id: bubbles

    property var workspaces: []     // list of { id, name, active, urgent, occupied }
    property color ink
    property color inkSoft
    property bool numbered          // the active bubble shows the number of its workspace (style bubbles); without: style dots
    property color inkOn            // colour of the number inside the active bubble (the opposite of ink)
    property int cellHeight         // height of one cell (the bar's height, 40 on the island for touch)
    property int cellWidth: 24
    property int ringSize: 8
    property int dotSize: 10
    property int activeSize: 16
    property bool oval                // the active workspace is a stretched oval instead of a larger bubble (style ovals)
    property int ovalWidth: 24        // width of the active oval
    property int ovalHeight: 10       // height of every oval-style dot

    signal workspaceClicked(int workspaceId)

    implicitWidth: (workspaces ? workspaces.length : 0) * cellWidth
    implicitHeight: cellHeight

    // The bubbles grow from ring to dot to active bubble, and the cell holds the largest.
    Component.onCompleted: if (ringSize > dotSize || dotSize > activeSize || activeSize > cellWidth) throw new Error("invariant: WorkspaceBubbles: sizes out of order")

    // The oval has to fit its cell.
    onOvalChanged: if (oval && ovalWidth > cellWidth) throw new Error("invariant: WorkspaceBubbles: the oval is wider than its cell")

    // Diameter of the bubble of one workspace entry (ring, dot or active).
    function sizeFor(entry: var): int {
        if (!entry) throw new Error("invariant: WorkspaceBubbles.sizeFor: no workspace entry")
        return entry.active ? activeSize : (entry.occupied || entry.urgent) ? dotSize : ringSize
    }

    // Width of the dot of one workspace entry: its diameter (style ovals: all dots are as round as they are high).
    function widthFor(entry: var): int {
        if (!entry) throw new Error("invariant: WorkspaceBubbles.widthFor: no workspace entry")
        if (!oval) return sizeFor(entry)
        return ovalHeight   // the dots are round; the active oval is the sliding shape above them
    }

    // Colour of the bubble: urgent is the one signal colour, the rest is ink with weight.
    function toneFor(entry: var): color {
        if (!entry) throw new Error("invariant: WorkspaceBubbles.toneFor: no workspace entry")
        return entry.urgent ? Tokens.warn : ink
    }

    // Style ovals: the active workspace is one oval that slides to the new cell. Its leading edge runs ahead of the
    // trailing one, so it stretches while it moves and settles into the new cell.
    readonly property int activeIndex: {
        const list = workspaces || []
        for (let i = 0; i < list.length; i++) if (list[i].active) return i
        return -1
    }
    readonly property real targetLeft: activeIndex * cellWidth + (cellWidth - ovalWidth) / 2
    readonly property real targetRight: targetLeft + ovalWidth
    property real leftEdge: targetLeft
    property real rightEdge: targetRight
    Behavior on leftEdge { NumberAnimation { duration: bubbles.targetLeft < bubbles.leftEdge ? 140 : 280; easing.type: Easing.OutCubic } }
    Behavior on rightEdge { NumberAnimation { duration: bubbles.targetRight > bubbles.rightEdge ? 140 : 280; easing.type: Easing.OutCubic } }

    Rectangle {
        visible: bubbles.oval && bubbles.activeIndex >= 0
        x: bubbles.leftEdge
        anchors.verticalCenter: parent.verticalCenter
        width: bubbles.rightEdge - bubbles.leftEdge
        height: bubbles.ovalHeight
        radius: height / 2
        color: bubbles.ink
        z: 1
    }

    Repeater {
        model: bubbles.workspaces
        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            readonly property bool filled: modelData.active || modelData.occupied || modelData.urgent
            readonly property color tone: bubbles.toneFor(modelData)
            x: index * bubbles.cellWidth
            width: bubbles.cellWidth
            height: bubbles.height

            // Size and weight carry the state; urgent is the one signal colour.
            Rectangle {
                anchors.centerIn: parent
                width: bubbles.widthFor(cell.modelData)
                height: bubbles.oval ? bubbles.ovalHeight : width
                radius: height / 2
                opacity: bubbles.oval && cell.modelData.active ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                color: cell.filled ? Qt.rgba(cell.tone.r, cell.tone.g, cell.tone.b, cell.modelData.active ? 1 : 0.55) : "transparent"
                border.width: cell.filled ? 0 : 1.5
                border.color: Qt.rgba(bubbles.ink.r, bubbles.ink.g, bubbles.ink.b, 0.5)
                Behavior on width { NumberAnimation { duration: Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
                Behavior on color { ColorAnimation { duration: Tokens.durFast } }
            }
            Text {
                visible: bubbles.numbered && cell.modelData.active
                anchors.centerIn: parent
                text: cell.modelData.name
                font.family: Tokens.fontUi
                font.pixelSize: cell.modelData.name.length > 1 ? 8 : 10
                font.weight: Font.DemiBold
                color: bubbles.inkOn
                renderType: Text.NativeRendering
            }
            MouseArea { anchors.fill: parent; onClicked: bubbles.workspaceClicked(cell.modelData.id) }
        }
    }
}
