import QtQuick
import qs.theme
import qs.components

Item {
    id: slider

    property real value
    property color ink
    property color line
    property string iconName
    signal moved(real value)
    signal iconClicked()

    implicitWidth: 200
    implicitHeight: 36

    StatusGlyph {
        id: glyph
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        kind: slider.iconName
        color: slider.ink
        MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: slider.iconClicked() }
    }

    Item {
        id: area
        anchors { left: glyph.right; leftMargin: 12; right: parent.right; verticalCenter: parent.verticalCenter }
        height: parent.height

        Rectangle {
            id: track
            width: parent.width
            height: 4
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            color: slider.line
            Rectangle {
                width: Math.max(0, Math.min(1, slider.value)) * parent.width
                height: parent.height
                radius: 2
                color: slider.ink
            }
        }
        Rectangle {
            width: 14
            height: 14
            radius: 7
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(1, slider.value)) * (track.width - width)
            color: slider.ink
            scale: drag.pressed ? 1.15 : 1
            Behavior on scale { NumberAnimation { duration: Tokens.durFast } }
        }
        MouseArea {
            id: drag
            anchors.fill: parent
            function apply(x: real): void { slider.moved(Math.max(0, Math.min(1, x / width))) }
            onPressed: mouse => apply(mouse.x)
            onPositionChanged: mouse => { if (pressed) apply(mouse.x) }
        }
    }
}
