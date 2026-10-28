import QtQuick
import qs.models
import qs.theme

// Small pill for a step that costs something (forgetting a network or device): the first click arms it, the second one confirms.
Item {
    id: button

    property string label
    property string confirmLabel: "Really?"
    property bool armed
    property int severity: Enums.Severity.Critical  // the colour of the armed state

    signal confirmed()

    function disarm(): void {
        armed = false
    }

    implicitWidth: Math.max(72, Math.max(plain.implicitWidth, sure.implicitWidth) + 24)
    implicitHeight: 32

    // An armed button falls back by itself, so a stray click never leaves it loaded.
    Timer {
        interval: 3000
        running: button.armed
        onTriggered: button.disarm()
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: button.armed ? Tokens.colorFor(button.severity) : Tokens.surfaceAlt
        border.width: 1
        border.color: button.armed ? Tokens.colorFor(button.severity) : Tokens.line
        opacity: area.pressed ? 1 : area.containsMouse || button.armed ? 1 : 0.7
        Behavior on color { ColorAnimation { duration: Tokens.durFast } }
        Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
    }
    Label {
        id: plain
        anchors.centerIn: parent
        text: button.label
        opacity: button.armed ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
    }
    Label {
        id: sure
        anchors.centerIn: parent
        text: button.confirmLabel
        color: Tokens.bg
        font.weight: Font.DemiBold
        opacity: button.armed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (button.armed) {
                button.disarm()
                button.confirmed()
            } else {
                button.armed = true
            }
        }
    }
}
