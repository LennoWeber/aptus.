// Segmented: Segmented control (03 §9): 28 high, sunken track, sliding raised indicator.
import QtQuick
import qs.core

Item {
    id: root

    // [{ value, label }]
    property var options: []
    property var value
    property bool enabled: true
    property bool keyboardFocus: false
    signal selected(var value)
}
