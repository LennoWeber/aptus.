import QtQuick
import qs.theme
import qs.services
import qs.components

// A one-line text field in the settings look. Reports the focus to the on-screen keyboard.
Item {
    id: box

    property alias text: input.text
    property string placeholder
    signal edited(string text)
    signal accepted()

    implicitWidth: 200
    implicitHeight: 34

    Surface { anchors.fill: parent; cornerRadius: 8 }
    TextInput {
        id: input
        anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        font.family: Tokens.fontUi
        font.pixelSize: 14
        color: Tokens.ink
        clip: true
        selectByMouse: true
        onTextEdited: box.edited(text)
        onAccepted: box.accepted()
        onActiveFocusChanged: Osk.track(input, activeFocus)
        Text {
            visible: input.text === "" && !input.preeditText
            anchors.verticalCenter: parent.verticalCenter
            text: box.placeholder
            font: input.font
            color: Tokens.inkFaint
        }
    }
}
