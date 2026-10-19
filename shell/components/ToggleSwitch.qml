import QtQuick
import qs.theme

// On/off switch.
Item {
    id: sw

    property bool checked
    property string label
    signal toggled(bool checked)

    implicitWidth: 240
    implicitHeight: 36

    Label {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        text: sw.label
    }

    // Thin track with a hairline; on = the "ok" colour. Flips within 140 ms.
    Rectangle {
        id: track
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 36
        height: 20
        radius: 10
        color: sw.checked ? Tokens.ok : Tokens.surfaceAlt
        border.width: 1
        border.color: sw.checked ? Tokens.ok : Tokens.line
        Behavior on color { ColorAnimation { duration: Tokens.durFast } }

        Rectangle {
            width: 14
            height: 14
            radius: 7
            anchors.verticalCenter: parent.verticalCenter
            x: sw.checked ? parent.width - width - 3 : 3
            color: sw.checked ? Tokens.surface : Tokens.inkSoft
            Behavior on x { NumberAnimation { duration: Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: sw.toggled(!sw.checked)
    }
}
