// Field: Text field (03 §9): sunken, radius 12, 40 high (52 in Spotlight), 2 px accent caret.
pragma ComponentBehavior: Bound
import QtQuick
import qs.core

Item {
    id: root

    // The input's text (an alias: typing changes it without breaking an owner's `text: query` binding).
    property alias text: textInput.text
    property string placeholder: ""
    // Spotlight size (52 high, field type).
    property bool large: false
    property bool password: false
    property string glyph: ""
    readonly property Item input: textInput
    signal accepted()
    signal edited(string text)

    function forceFocus(): void { textInput.forceActiveFocus(); }
    function selectAll(): void { textInput.selectAll(); }
    // Empties the field (also Ctrl+Backspace, 05 §5) and reports it as an edit.
    function clear(): void {
        if (textInput.text === "") return;
        textInput.clear();
        root.edited("");
    }

    readonly property string _type: large ? "field" : "body"
    readonly property var _font: Tokens.font(_type)

    implicitHeight: large ? Tokens.field.heightSpotlight : Tokens.field.height
    implicitWidth: Tokens.s10 * 5
    Accessible.role: Accessible.EditableText
    Accessible.name: placeholder
    Accessible.passwordEdit: password

    Rectangle {
        anchors.fill: parent
        radius: Tokens.field.radius
        color: Tokens.sunken
    }
    Glyph {
        id: lead
        x: Tokens.s5
        anchors.verticalCenter: parent.verticalCenter
        visible: root.glyph !== ""
        name: root.glyph
        size: root.large ? Tokens.glyphHeader : Tokens.glyphRow
        colour: Tokens.inkMeta
    }
    TextInput {
        id: textInput
        anchors.left: lead.visible ? lead.right : parent.left
        anchors.leftMargin: lead.visible ? Tokens.gapRowIcon : Tokens.s5
        anchors.right: parent.right
        anchors.rightMargin: Tokens.s5
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: Tokens.inkMain
        selectionColor: Tokens.selectionBg
        selectedTextColor: Tokens.selectionFg
        selectByMouse: true
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        passwordMaskDelay: 0
        font.family: root._font.family
        font.pixelSize: root._font.pixelSize
        font.weight: root._font.weight
        font.letterSpacing: root._font.letterSpacing
        // a steady caret: nothing moves at rest (04 §1 rule 5), so no blinking
        cursorDelegate: Rectangle {
            width: Tokens.field.caret
            color: Tokens.accent
            visible: textInput.activeFocus && textInput.selectedText === ""
        }

        onAccepted: root.accepted()
        onTextEdited: root.edited(text)
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Backspace && (event.modifiers & Qt.ControlModifier)) {
                root.clear();
                event.accepted = true;
            }
        }
    }
    Label {
        anchors.fill: textInput
        visible: textInput.text === "" && textInput.preeditText === ""
        text: root.placeholder
        type: root._type
        ink: "faint"
    }
}
