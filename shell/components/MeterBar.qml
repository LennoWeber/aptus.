import QtQuick
import qs.models
import qs.theme

// Thin value bar 0..1. Ink by default, colour only for warn and critical.
Item {
    id: bar

    property real value
    property int severity: Enums.Severity.Neutral  // Enums.Severity

    implicitWidth: 120
    implicitHeight: 6

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Tokens.surfaceAlt
        border.width: 1
        border.color: Tokens.line
    }
    Rectangle {
        height: parent.height
        width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, bar.value)))
        radius: height / 2
        color: bar.severity === Enums.Severity.Neutral ? Tokens.ink : Tokens.colorFor(bar.severity)
        Behavior on width { NumberAnimation { duration: Tokens.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
    }
}
