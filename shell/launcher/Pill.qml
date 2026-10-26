import QtQuick
import qs.theme
import qs.services
import qs.components

// The rounded search bar with the mode symbol at the front.
Item {
    id: pill

    property int mode  // Enums.LauncherMode
    property string query
    property string placeholder
    property bool switching
    property real mergeProgress: 1  // 0..1, runs while the mode changes
    property int previousMode
    readonly property alias input: field
    signal queryEdited(string text)
    signal accepted()
    signal navigationKey(var event)

    implicitHeight: 52

    function focusInput(): void {
        field.forceActiveFocus()
    }

    function clear(): void {
        field.text = ""
    }

    // Fully rounded, hairline only, never transparent.
    Surface {
        anchors.fill: parent
        cornerRadius: Tokens.radiusPill
        elevated: true
    }

    // The old symbol slides out and fades, the new one slides in. Typing never waits for this.
    Item {
        id: symbolSlot
        x: 20
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18

        ModeGlyph {
            anchors.centerIn: parent
            mode: pill.previousMode
            color: Tokens.inkSoft
            opacity: pill.switching ? 1 - pill.mergeProgress : 0
            anchors.horizontalCenterOffset: -8 * pill.mergeProgress
        }
        ModeGlyph {
            anchors.centerIn: parent
            mode: pill.mode
            color: Tokens.ink
            opacity: pill.switching ? pill.mergeProgress : 1
            anchors.horizontalCenterOffset: pill.switching ? 8 * (1 - pill.mergeProgress) : 0
        }
    }

    TextInput {
        id: field
        anchors { left: symbolSlot.right; leftMargin: 14; right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
        font.family: Tokens.fontUi
        font.pixelSize: 17
        color: Tokens.ink
        selectionColor: Tokens.surfaceAlt
        selectedTextColor: Tokens.ink
        clip: true
        focus: true
        text: pill.query
        onTextEdited: pill.queryEdited(text)
        onAccepted: pill.accepted()
        onActiveFocusChanged: Osk.track(field, activeFocus)
        Keys.onPressed: event => pill.navigationKey(event)

        Text {
            visible: field.text === "" && !field.preeditText
            anchors.verticalCenter: parent.verticalCenter
            text: pill.placeholder
            font: field.font
            color: Tokens.inkFaint
        }
    }
}
