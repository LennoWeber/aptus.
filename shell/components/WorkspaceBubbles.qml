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
        // TODO(phase 7): sizeFor stays the diameter; with oval every dot is ovalHeight high.
        return entry.active ? activeSize : (entry.occupied || entry.urgent) ? dotSize : ringSize
    }

    // Width of the shape of one workspace entry: the oval width for the active one, else its diameter (style ovals).
    function widthFor(entry: var): int {
        throw new Error("not implemented")
    }

    // Colour of the bubble: urgent is the one signal colour, the rest is ink with weight.
    function toneFor(entry: var): color {
        if (!entry) throw new Error("invariant: WorkspaceBubbles.toneFor: no workspace entry")
        return entry.urgent ? Tokens.warn : ink
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
                // TODO(phase 7): width: bubbles.widthFor(cell.modelData); height: bubbles.oval ? ovalHeight : width; radius: height / 2; cellWidth must hold ovalWidth (28 for ovals).
                width: bubbles.sizeFor(cell.modelData)
                height: width
                radius: width / 2
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
