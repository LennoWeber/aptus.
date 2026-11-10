// The frame: the screen-edge band and every open drawer's bulge, painted as one shape (03 §6, 07 §4).
// Owner: S1.
import QtQuick
import qs.core
import qs.components
import QtQuick.Effects
import "../../core/js/bulge.js" as BJ

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

    // (Each Bulge normalises its own bulges, as the S1 hand-off found: the frame and the shadow
    // bodies take different sets, bodiesOnly drops those without a shadow, and with at most four
    // bulges a second normalise costs nothing measurable; one shared shape would need a Bulge.qml
    // change for no gain.)
    // The area the drawer shadow is blurred over: the shadow-casting bodies' bounding box plus
    // the blur radius (monitor-local, clamped to the monitor), empty when nothing casts one. The
    // blur's texture covers this box instead of the whole monitor (07 §12).
    readonly property rect shadowBox: {
        const n = BJ.normalise(bodies._specs, width, edgeNow);
        const list = (n.full ? [n.full] : []).concat(n.bulges);
        if (list.length === 0) return Qt.rect(0, 0, 0, 0);
        let x0 = width, x1 = 0, deepest = 0;
        for (const b of list) { x0 = Math.min(x0, b.x); x1 = Math.max(x1, b.x + b.width); }
        for (const b of n.bulges) deepest = Math.max(deepest, b.height);
        const pad = Tokens.shadowBlur;
        const bottom = barNow + (n.full ? n.full.height : 0) + deepest + pad;
        const x = Math.max(0, x0 - pad), y = Math.max(0, barNow - pad);
        return Qt.rect(x, y, Math.min(width, x1 + pad) - x, Math.min(height, bottom) - y);
    }

    // No whole-frame opacity (it would take the notch's bulge, and with it a critical toast or OSD
    // above a fullscreen window, out too): the frame fades with `hide` while the shadow-casting
    // bodies (the notch casts one while hidden, Notch.bulge) cross-fade in on their own (M-31).

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
    // The bodies' box only (shadowBox, padded for the blur), not the whole monitor.
    ShaderEffectSource {
        id: shadowSource
        visible: false
        sourceItem: bodies
        sourceRect: root.shadowBox
        width: root.shadowBox.width
        height: root.shadowBox.height
    }
    MultiEffect {
        source: shadowSource
        x: root.shadowBox.x
        y: root.shadowBox.y + Tokens.shadowOffsetY
        width: root.shadowBox.width
        height: root.shadowBox.height
        visible: root.shadowBox.width > 0
        blurEnabled: true
        blur: 1
        blurMax: Tokens.shadowBlur
    }
    Bulge {
        visible: root.hide > 0
        opacity: root.hide
        frameWidth: root.width
        frameHeight: root.height
        edge: root.edgeNow
        barHeight: root.barNow
        innerRadius: Tokens.frameInnerRadius
        bulges: root.bulges
        bodiesOnly: true
        colour: Tokens.alpha(Tokens.ground, Tokens.groundAlpha)
    }
    Bulge {
        visible: root.hide < 1
        opacity: 1 - root.hide
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
