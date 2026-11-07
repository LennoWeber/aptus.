// Switch: Switch (03 §9): 36 × 20 track, 16 thumb.
import QtQuick
import qs.core

Item {
    id: root

    property bool checked: false
    property bool enabled: true
    property string accessibleName: ""
    property bool keyboardFocus: false
    signal toggled(bool checked)
}
