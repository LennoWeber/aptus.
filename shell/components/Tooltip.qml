// Tooltip: Tooltip (03 §9, M-32): raised, radius 8, body ink.main, 600 ms delay, 0 ms within 1 s of another.
import QtQuick
import qs.core

Item {
    id: root

    // TODO(phase): 600 ms delay, 0 ms within 1 s of another (shared timestamp), M-32 fade.

    property Item target: null
    property string text: ""
    property bool active: false

    // Private state.
    // Wanted now (the owner's hover state, a text, a visible target).
    readonly property bool _want: false
    property bool _shown: false
    // Placement in the content item, computed when it shows.
    property real _x: 0
    property real _y: 0
    readonly property real _rise: 0

    // Private helpers.
    function _show(): void { throw new Error("Tooltip._show: not implemented"); }
    function _hide(): void { throw new Error("Tooltip._hide: not implemented"); }
    // Centred below the target, above it when there is no room; inside the window.
    function _place(): void { throw new Error("Tooltip._place: not implemented"); }
}
