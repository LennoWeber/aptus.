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
    property int cellWidth
    property int ringSize
    property int dotSize
    property int activeSize

    signal workspaceClicked(int workspaceId)
}
