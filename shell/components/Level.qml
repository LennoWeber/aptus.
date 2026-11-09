// Level: The OSD level bar (03 §9): 6 px, radius 3, accent fill, snappy spring; the part over 1 in warn.
import QtQuick
import qs.core

Item {
    id: root

    // 0..max
    property real value: 0
    property real max: 1

    // The fill width follows `value` on the snappy spring (M-07), in pixels (spring epsilon).
    property real _fill: max > 0 ? width * Math.max(0, Math.min(value, max)) / max : 0
    readonly property real _one: max > 0 ? width * Math.min(1, 1 / max) : 0

    implicitHeight: Tokens.level.height
    implicitWidth: Tokens.s10 * 4
    Accessible.role: Accessible.ProgressBar

    Behavior on _fill {
        enabled: !Motion.reduced
        SnappySpring {}
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.level.radius
        color: Tokens.line
    }
    Rectangle {
        width: root._fill
        height: parent.height
        radius: Tokens.level.radius
        color: Tokens.accent
        visible: width > 0
    }
    // Over 1 (volume boost): the same rounded fill in warn, clipped to the part beyond 1.
    Item {
        x: root._one
        width: Math.max(0, root._fill - root._one)
        height: parent.height
        clip: true
        visible: width > 0

        Rectangle {
            x: -parent.x
            width: root._fill
            height: parent.height
            radius: Tokens.level.radius
            color: Tokens.warn
        }
    }
}
