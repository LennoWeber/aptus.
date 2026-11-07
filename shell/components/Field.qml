// Field: Text field (03 §9): sunken, radius 12, 40 high (52 in Spotlight), 2 px accent caret.
import QtQuick
import qs.core

Item {
    id: root
    // TODO(phase): the caret does not blink (04 §1 rule 5); Ctrl+Backspace clears (05 §5) and emits edited("").

    // TODO(phase): TextInput in a sunken rounded rect, accent caret, placeholder in ink.faint, password mode.

    // The input's text (an alias: typing changes it without breaking an owner's `text: query` binding).
    property alias text: textInput.text
    property string placeholder: ""
    // Spotlight size (52 high, field type).
    property bool large: false
    property bool password: false
    property string glyph: ""
    readonly property Item input: null
    signal accepted()
    signal edited(string text)

    function forceFocus(): void { throw new Error("Field.forceFocus: not implemented"); }
    function selectAll(): void { throw new Error("Field.selectAll: not implemented"); }
    function clear(): void { throw new Error("Field.clear: not implemented"); }

    // Private state.
    readonly property string _type: ""
    readonly property var _font: ({})

    TextInput {
        id: textInput
    }
}
