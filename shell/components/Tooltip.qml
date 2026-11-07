// Tooltip: Tooltip (03 §9, M-32): raised, radius 8, body ink.main, 600 ms delay, 0 ms within 1 s of another.
import QtQuick
import qs.core

Item {
    id: root

    // TODO(phase): 600 ms delay, 0 ms within 1 s of another (shared timestamp), M-32 fade.

    property Item target: null
    property string text: ""
    property bool active: false
}
