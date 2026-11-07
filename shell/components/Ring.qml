// Ring: Progress ring (03 §9): 2 px line track, 2 px arc, round caps.
import QtQuick
import QtQuick.Shapes
import qs.core

Item {
    id: root

    // TODO(phase): the thickness default comes from Tokens.ring.width, not a literal.
    // TODO(phase): a progress ring (Shape arc) for timers and focus.

    // 0..1
    property real progress: 0
    property real thickness: 2
    property color colour

    // Private state.
    readonly property real _p: 0
    readonly property real _r: 0
}
