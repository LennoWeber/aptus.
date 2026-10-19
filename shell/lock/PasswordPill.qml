import QtQuick
import qs.theme
import qs.components

// Password field in the pill shape: dots instead of letters, a short shake on a wrong password.
Item {
    id: pill

    property string placeholder: "Password"
    property bool busy
    property bool error
    readonly property alias text: field.text
    property int length: field.text.length
    signal submitted()
    signal textEdited(string text)

    implicitWidth: 380
    implicitHeight: 52

    function focusInput(): void { field.forceActiveFocus() }
    function clear(): void { field.text = "" }
    function insert(text: string): void { field.insert(field.cursorPosition, text) }
    function backspace(): void { if (field.cursorPosition > 0) field.remove(field.cursorPosition - 1, field.cursorPosition) }
    function shake(): void { shakeAnimation.restart() }

    SequentialAnimation {
        id: shakeAnimation
        NumberAnimation { target: body; property: "x"; to: -10; duration: 40 }
        NumberAnimation { target: body; property: "x"; to: 10; duration: 70 }
        NumberAnimation { target: body; property: "x"; to: -6; duration: 60 }
        NumberAnimation { target: body; property: "x"; to: 0; duration: 50 }
    }

    Item {
        id: body
        width: parent.width
        height: parent.height
        opacity: pill.busy ? 0.6 : 1

        Surface {
            anchors.fill: parent
            cornerRadius: Tokens.radiusPill
            elevated: true
            border.color: pill.error ? Tokens.critical : Tokens.line
        }
        TextInput {
            id: field
            anchors { left: parent.left; leftMargin: 26; right: parent.right; rightMargin: 26; verticalCenter: parent.verticalCenter }
            font.family: Tokens.fontUi
            font.pixelSize: 19
            color: Tokens.ink
            clip: true
            focus: true
            echoMode: TextInput.Password
            passwordCharacter: "•"
            readOnly: pill.busy
            horizontalAlignment: TextInput.AlignHCenter
            onTextEdited: pill.textEdited(text)
            onAccepted: pill.submitted()

            Text {
                visible: field.text === "" && !field.preeditText
                anchors.centerIn: parent
                text: pill.placeholder
                font: field.font
                color: Tokens.inkFaint
            }
        }
    }
}
