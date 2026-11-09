// A ColorAnimation on the standard curve (Motion.standard); the caller sets the duration.
import QtQuick
import qs.core

ColorAnimation {
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.standard
}
