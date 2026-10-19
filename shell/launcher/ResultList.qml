pragma ComponentBehavior: Bound
import QtQuick
import qs.theme
import qs.components

// Result list below the pill.
Item {
    id: list

    property var results  // list of SearchResult
    property int selectedIndex
    property int mode  // Enums.LauncherMode
    readonly property int rowHeight: 44
    readonly property int count: results ? results.length : 0
    signal resultActivated(int index)
    signal selectionRequested(int index)

    implicitHeight: count > 0 ? count * rowHeight + 12 : 0
    height: implicitHeight
    visible: count > 0 || height > 0
    clip: true

    Behavior on height { NumberAnimation { duration: Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }

    function moveSelection(delta: int): void {
        if (count === 0) return
        selectionRequested(((selectedIndex + delta) % count + count) % count)
    }

    Surface {
        anchors.fill: parent
        cornerRadius: 18
        elevated: true

        // The selection glides between rows, it never jumps.
        Rectangle {
            x: 6
            width: parent.width - 12
            height: list.rowHeight
            radius: 12
            color: Tokens.surfaceAlt
            y: 6 + list.selectedIndex * list.rowHeight
            visible: list.count > 0
            Behavior on y { NumberAnimation { duration: Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
        }

        Repeater {
            model: list.results
            delegate: ResultRow {
                required property var modelData
                required property int index
                y: 6 + index * list.rowHeight
                width: list.width
                height: list.rowHeight
                result: modelData
                selected: index === list.selectedIndex
                onClicked: {
                    list.selectionRequested(index)
                    list.resultActivated(index)
                }
            }
        }
    }
}
