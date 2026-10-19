import QtQuick
import qs.theme
import qs.components

// Search field of the settings app: always at the top, results filter live.
Item {
    id: field

    property string query
    signal edited(string text)

    implicitHeight: 40

    function focusInput(): void {
        input.forceActiveFocus()
    }

    Surface {
        anchors.fill: parent
        cornerRadius: Tokens.radiusPill
    }
    TextInput {
        id: input
        anchors { left: parent.left; leftMargin: 18; right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
        font.family: Tokens.fontUi
        font.pixelSize: 15
        color: Tokens.ink
        selectionColor: Tokens.surfaceAlt
        selectedTextColor: Tokens.ink
        clip: true
        text: field.query
        onTextEdited: field.edited(text)

        Text {
            visible: input.text === "" && !input.preeditText
            anchors.verticalCenter: parent.verticalCenter
            text: "Search settings"
            font: input.font
            color: Tokens.inkFaint
        }
    }
}
