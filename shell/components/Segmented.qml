// Segmented: Segmented control (03 §9): 28 high, sunken track, sliding raised indicator.
import QtQuick
import qs.core

Item {
    id: root

    // TODO(phase): options with the raised indicator sliding on the snappy spring; ←/→ when focused.

    // [{ value, label }]
    property var options: []
    property var value
    property bool keyboardFocus: false
    signal selected(var value)
}
