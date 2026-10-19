import QtQuick
import qs.theme

// Text button: quiet by default, filled (ink) when primary. Never coloured.
Item {
    id: btn

    property string text
    property bool primary
    property bool active: true
    signal clicked()

    implicitWidth: Math.max(72, label.implicitWidth + 28)
    implicitHeight: 40
    opacity: active ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: btn.primary ? Tokens.ink : Tokens.surfaceAlt
        border.width: btn.primary ? 0 : 1
        border.color: Tokens.line
        opacity: area.pressed ? 1 : area.containsMouse ? 0.85 : (btn.primary ? 1 : 0.6)
        Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
    }
    Label {
        id: label
        anchors.centerIn: parent
        text: btn.text
        color: btn.primary ? Tokens.bg : Tokens.ink
        font.weight: Font.Medium
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.active
        onClicked: btn.clicked()
    }
}
