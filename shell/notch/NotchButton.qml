import QtQuick
import qs.theme
import qs.components

// A round icon button of the notch sheet (touch size 36).
Item {
    id: button

    property string kind: "play"
    property color color: Tokens.ink
    property int size: 36
    signal clicked()

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.centerIn: parent
        width: button.size * (0.88 + 0.12 * opacity / 0.14)
        height: width
        radius: width / 2
        color: Tokens.ink
        opacity: mouse.pressed ? 0.14 : mouse.containsMouse ? 0.09 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
    }

    StatusGlyph {
        anchors.centerIn: parent
        kind: button.kind
        color: button.color
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: button.clicked()
    }
}
