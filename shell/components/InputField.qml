import QtQuick
import qs.theme
import qs.services

// A one-line text field in a soft pill.
Surface {
    id: field

    property alias text: input.text
    property string placeholder
    property bool secret
    signal accepted()

    cornerRadius: 10
    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
        verticalAlignment: TextInput.AlignVCenter
        echoMode: field.secret ? TextInput.Password : TextInput.Normal
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.sizeBody
        color: Tokens.ink
        clip: true
        onAccepted: field.accepted()
        onActiveFocusChanged: Osk.track(input, activeFocus)
        Text {
            visible: input.text === ""
            anchors.verticalCenter: parent.verticalCenter
            text: field.placeholder
            font: input.font
            color: Tokens.inkFaint
        }
    }
}
