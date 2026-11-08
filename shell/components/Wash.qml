// Wash: The state layer (03 §2.3): ink.main over the ground at hover / current / pressed amounts.
import QtQuick
import qs.core

Rectangle {
    id: root

    property bool hovered: false
    property bool current: false
    property bool pressed: false
    // accentWash instead of the ink washes ("on" tiles).
    property bool on: false

    // The resolved washes are opaque (ink over ground); at rest the hover wash at alpha 0, so the
    // colour animation only fades in and never passes through black.
    readonly property color _target: pressed ? Tokens.washPressed
        : on ? (hovered ? ComponentShared.layer(Tokens.accentWash, Tokens.inkMain, "hover") : Tokens.accentWash)
        : current ? (hovered ? Tokens.washCurrentHover : Tokens.washCurrent)
        : hovered ? Tokens.washHover : Tokens.alpha(Tokens.washHover, 0)

    radius: Tokens.rowRadius
    color: _target

    Behavior on color {
        ColorAnimation {
            duration: root.pressed ? Motion.ms("press", false) : Motion.ms("hover", false)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.standard
        }
    }
}
