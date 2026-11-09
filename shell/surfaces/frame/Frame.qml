// The frame: the screen-edge band and every open drawer's bulge, painted as one shape (03 §6, 07 §4).
// Owner: S1.
import QtQuick
import qs.core
import qs.components
import QtQuick.Effects

Item {
    id: root

    property MonitorState monitor
    // The drawers' bulges (BulgeSpec), drawn as dents in the content area's outline.
    property list<BulgeSpec> bulges
    // 0 → 1 during the session intro (M-01): edges thicken, the bar slides down.
    property real introProgress: 1
    // A fullscreen window: frame and bar slide out (M-31) unless revealed by the hot edge.
    property bool hidden: false
    // The hot edge brought the bar back over the fullscreen window.
    property bool revealed: false
    // How far the frame is slid out (0 shown, 1 hidden), animated.
    property real hide: hidden && !revealed ? 1 : 0
    Behavior on hide {
        id: hideBehavior
        NumberAnimation {
            // M-31: out with `exit` 180, back with `enter` 240
            duration: Motion.catalogueMs("fullscreen", hideBehavior.targetValue > 0.5)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: hideBehavior.targetValue > 0.5 ? Motion.exit : Motion.enter
        }
    }

    // Current thicknesses: the intro grows them (M-01), fullscreen slides them out (M-31).
    readonly property real edgeNow: Tokens.frameEdge * introProgress * (1 - hide)
    readonly property real barNow: Tokens.barHeight * introProgress * (1 - hide)

    // The open bulges normalised once per change (bulge.js normalise), shared by the frame and
    // the shadow shapes.
    readonly property var shape: ({ full: null, bulges: [] })
    // The area the drawer shadow is blurred over: the shadow-casting bodies' bounding box plus
    // the blur radius (monitor-local), empty when nothing casts one.
    readonly property rect shadowBox: Qt.rect(0, 0, 0, 0)

    opacity: 1 - hide

    // The drawer shadow: the open bulge bodies in the shadow colour, blurred and offset (03 §6).
    // (A blurred copy instead of MultiEffect's shadow, which would also draw the bodies themselves
    // and show through glass.)
    Bulge {
        id: bodies
        visible: false
        frameWidth: root.width
        frameHeight: root.height
        edge: root.edgeNow
        barHeight: root.barNow
        innerRadius: Tokens.frameInnerRadius
        bulges: root.bulges
        bodiesOnly: true
        colour: Tokens.shadow
    }
    MultiEffect {
        source: bodies
        width: bodies.width
        height: bodies.height
        y: Tokens.shadowOffsetY
        visible: bodies._specs.length > 0
        blurEnabled: true
        blur: 1
        blurMax: Tokens.shadowBlur
        autoPaddingEnabled: true
    }
    Bulge {
        frameWidth: root.width
        frameHeight: root.height
        edge: root.edgeNow
        barHeight: root.barNow
        innerRadius: Tokens.frameInnerRadius
        bulges: root.bulges
        colour: Tokens.alpha(Tokens.ground, Tokens.groundAlpha)
        lineColour: Tokens.frameLine
        lineWidth: Tokens.frameLineWidth
    }
}
