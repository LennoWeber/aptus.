// Field: Text field (03 §9): sunken, radius 12, 40 high (52 in Spotlight), 2 px accent caret.
import QtQuick
import qs.core

Item {
    id: root

    property string text: ""
    property string placeholder: ""
    // Spotlight size (52 high, field type).
    property bool large: false
    property bool password: false
    property string glyph: ""
    readonly property Item input: null
    signal accepted()
    signal edited(string text)
}
