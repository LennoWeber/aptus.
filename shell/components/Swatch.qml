// Swatch: Swatch (03 §9): a 20 px colour dot, ringed when selected.
import QtQuick
import qs.core

Item {
    id: root

    // TODO(phase): round Rectangle, ring when selected, Tooltip with name.

    property color colour
    property bool selected: false
    // Tooltip text (the accent's name).
    property string name: ""
    signal picked()

    // Private state.
    readonly property real _out: 0
}
