// Scrim: The dim behind polkit and the session sheet (M-27). The host sizes it (full area).
import QtQuick
import qs.core

Rectangle {
    id: root

    property bool shown: false

    color: Tokens.scrim
    opacity: shown ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.reduced ? Motion.reducedCrossfade : Motion.catalogueMs("scrim.fade", false)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.shown ? Motion.enter : Motion.exit
        }
    }
}
