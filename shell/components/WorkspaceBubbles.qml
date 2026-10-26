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
    property int cellHeight         // height of one cell (the bar's height, 40 on the island for touch)
    property int cellWidth: 24
    property int ringSize: 8
    property int dotSize: 10
    property int activeSize: 16

    signal workspaceClicked(int workspaceId)

    // Diameter of the bubble of one workspace entry (ring, dot or active).
    function sizeFor(entry: var): int {
        throw new Error("not implemented")
    }

    // Colour of the bubble: urgent is the one signal colour, the rest is ink with weight.
    function toneFor(entry: var): color {
        throw new Error("not implemented")
    }
}
