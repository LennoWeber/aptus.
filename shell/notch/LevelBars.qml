pragma ComponentBehavior: Bound
import QtQuick

// Four small level bars that move while something plays and stand still when it pauses.
Row {
    id: bars

    property bool running
    property color color: "black"

    spacing: 2

    Repeater {
        model: [0.55, 1.0, 0.7, 0.9]
        delegate: Item {
            id: cell
            required property real modelData
            required property int index
            property real lv: 0.3
            width: 2
            height: 12

            Rectangle {
                anchors.bottom: parent.bottom
                width: 2
                height: 3 + 9 * cell.lv
                radius: 1
                color: bars.color
            }

            SequentialAnimation on lv {
                running: bars.running
                loops: Animation.Infinite
                NumberAnimation { to: cell.modelData; duration: 340 + cell.index * 90; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.15; duration: 340 + cell.index * 70; easing.type: Easing.InOutSine }
            }
        }
    }
}
