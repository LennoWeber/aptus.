// Ring: Progress ring (03 §9): 2 px line track, 2 px arc, round caps.
// The arc starts at the top and runs clockwise; progress changes are not animated here
// (M-22 drives it from the owner).
import QtQuick
import QtQuick.Shapes
import qs.core

Item {
    id: root

    // 0..1
    property real progress: 0
    property real thickness: Tokens.ring.width
    property color colour

    readonly property real _p: Math.max(0, Math.min(1, progress))
    readonly property real _r: (Math.min(width, height) - thickness) / 2

    implicitWidth: Tokens.s6
    implicitHeight: Tokens.s6
    Accessible.role: Accessible.ProgressBar

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Tokens.line
            strokeWidth: root.thickness
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root._r
                radiusY: root._r
                startAngle: 0
                sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: root.colour.valid ? root.colour : Tokens.accent
            // a negative width draws no stroke (no round-cap dot at 0)
            strokeWidth: root._p > 0 ? root.thickness : -1
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root._r
                radiusY: root._r
                startAngle: -90
                sweepAngle: 360 * root._p
            }
        }
    }
}
