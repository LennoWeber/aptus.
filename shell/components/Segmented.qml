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

    // Private state.
    readonly property int _index: 0
    readonly property real _inset: 0
    readonly property real _padH: 0
    // Natural width of every segment; extra width is shared evenly.
    readonly property real _natural: 0
    readonly property real _extra: 0
    readonly property Item _current: null

    // Private helpers.
    function _pick(i: int): void { throw new Error("Segmented._pick: not implemented"); }
}
