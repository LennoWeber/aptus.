// Checkbox: Checkbox (03 §9): 18 × 18, radius 4, outline off, accent fill with a check glyph on.
import QtQuick
import qs.core

Item {
    id: root

    property bool checked: false
    property string accessibleName: ""
    property bool keyboardFocus: false
    signal toggled(bool checked)
}
