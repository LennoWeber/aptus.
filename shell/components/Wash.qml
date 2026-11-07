// Wash: The state layer (03 §2.3): ink.main over the ground at hover / current / pressed amounts.
import QtQuick
import qs.core

Rectangle {
    id: root

    // TODO(phase): rounded Rectangle in Tokens.washHover/washPressed/washCurrent by state, 120 ms colour Behavior.

    property bool hovered: false
    property bool current: false
    property bool pressed: false
    // accentWash instead of the ink washes ("on" tiles).
    property bool on: false

    // Private state.
    // The resolved washes are opaque (ink over ground); at rest the hover wash at alpha 0, so the
    // colour animation only fades in and never passes through black.
    readonly property color _target: "transparent"
}
