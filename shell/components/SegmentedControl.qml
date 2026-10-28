pragma ComponentBehavior: Bound
import QtQuick
import qs.theme

// A row of mutually exclusive choices in one pill (scale, refresh rate).
Item {
    id: control

    property var options: []   // list of { label, value }
    property var current       // the value of the chosen option
    signal picked(var value)

    readonly property int chosen: options.findIndex(o => o.value === current)
    readonly property real cell: options.length > 0 ? (width - 6) / options.length : 0

    implicitWidth: 240
    implicitHeight: 40

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Tokens.surfaceAlt
        border.width: 1
        border.color: Tokens.line
    }
    // The chosen cell slides to its place within 140 ms.
    Rectangle {
        visible: control.chosen >= 0
        y: 3
        x: 3 + Math.max(0, control.chosen) * control.cell
        width: control.cell
        height: parent.height - 6
        radius: 9
        color: Tokens.ink
        Behavior on x { NumberAnimation { duration: Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
    }
    Repeater {
        model: control.options
        delegate: Item {
            id: cellItem
            required property var modelData
            required property int index
            x: 3 + index * control.cell
            width: control.cell
            height: control.height
            Label {
                anchors.centerIn: parent
                text: cellItem.modelData.label
                font.weight: Font.Medium
                color: control.chosen === cellItem.index ? Tokens.bg : Tokens.ink
                Behavior on color { ColorAnimation { duration: Tokens.durFast } }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: control.picked(cellItem.modelData.value)
            }
        }
    }
}
