// A NumberAnimation on the standard curve (Motion.standard); the caller sets the duration.
import QtQuick
import qs.core

NumberAnimation {
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.standard
}
