// Swatch: Swatch (03 §9): a 20 px colour dot, ringed when selected.
import QtQuick
import qs.core

Item {
    id: root

    property color colour
    property bool selected: false
    // Tooltip text (the accent's name).
    property string name: ""
    signal picked()
}
