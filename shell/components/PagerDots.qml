// PagerDots: Pager dots (03 §9): 6 px dots, ink.faint, current ink.sec.
pragma ComponentBehavior: Bound
import QtQuick
import qs.core

Item {
    id: root

    property int count: 0
    property int current: 0
    signal picked(int index)

    readonly property real _pitch: Tokens.pagerDots.size + Tokens.pagerDots.gap

    implicitWidth: count > 0 ? count * Tokens.pagerDots.size + (count - 1) * Tokens.pagerDots.gap : 0
    implicitHeight: Tokens.pagerDots.size
    Accessible.role: Accessible.PageTabList

    Row {
        anchors.centerIn: parent
        spacing: Tokens.pagerDots.gap

        Repeater {
            model: root.count
            delegate: Rectangle {
                required property int index
                width: Tokens.pagerDots.size
                height: width
                radius: width / 2
                color: index === root.current ? Tokens.inkSec : Tokens.inkFaint

                Behavior on color {
                    ColorAnimation { duration: Motion.ms("small", false); easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.standard }
                }
            }
        }
    }
    // One hit area over the row, hitMin high; the dot under the pointer (by pitch) is picked.
    MouseArea {
        anchors.centerIn: parent
        width: parent.width + Tokens.pagerDots.gap
        height: Math.max(parent.height, Tokens.hitMin)
        onClicked: event => {
            const i = Math.floor(event.x / root._pitch);
            if (i >= 0 && i < root.count) root.picked(i);
        }
    }
}
