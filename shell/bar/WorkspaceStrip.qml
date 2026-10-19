pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// Workspaces on the left of the bar.
Item {
    id: strip

    property var workspaces: []  // list of { id, name, active, urgent, occupied }
    property int style: 0        // 0 numbers, 1 dots
    signal workspaceClicked(int workspaceId)

    readonly property int cellWidth: 24
    readonly property int activeIndex: {
        const list = workspaces || []
        for (let i = 0; i < list.length; i++) if (list[i].active) return i
        return -1
    }

    implicitWidth: (workspaces ? workspaces.length : 0) * cellWidth
    implicitHeight: Tokens.barHeight

    Repeater {
        model: strip.workspaces
        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            x: index * strip.cellWidth
            width: strip.cellWidth
            height: strip.height

            // The state is carried by weight and a thin line, never by colour. Urgent is the one signal colour.
            readonly property color tone: modelData.urgent ? Tokens.warn : modelData.active ? Tokens.ink : modelData.occupied ? Tokens.inkSoft : Tokens.inkFaint

            Label {
                visible: strip.style === 0
                anchors.centerIn: parent
                text: cell.modelData.name
                role: Enums.TextRole.Bar
                color: cell.tone
                font.weight: cell.modelData.active ? Font.DemiBold : Font.Normal
                Behavior on color { ColorAnimation { duration: Tokens.durFast } }
            }

            Rectangle {
                visible: strip.style === 1
                anchors.centerIn: parent
                width: cell.modelData.active ? 7 : 5
                height: width
                radius: width / 2
                color: cell.tone
                Behavior on width { NumberAnimation { duration: Tokens.durFast } }
            }

            // Hit area: the full cell, 24 px wide and as high as the bar.
            MouseArea {
                anchors.fill: parent
                onClicked: strip.workspaceClicked(cell.modelData.id)
            }
        }
    }

    // One thin line that slides under the active number.
    Rectangle {
        visible: strip.style === 0 && strip.activeIndex >= 0
        y: strip.height - 6
        height: 2
        width: 10
        radius: 1
        color: Tokens.ink
        x: strip.activeIndex * strip.cellWidth + (strip.cellWidth - width) / 2
        Behavior on x { NumberAnimation { duration: Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
    }
}
