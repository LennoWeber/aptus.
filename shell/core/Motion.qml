pragma Singleton
// Durations, curves, springs and choreography of 04-motion, from theme/tokens.json "motion".
// With reduced motion (motion.reduce, §7), geometry durations become 0 and content crossfades
// use `reducedCrossfade`.
import QtQuick
import Quickshell

Singleton {
    id: root

    // motion.reduce resolved ("auto" reads org.gnome.desktop.interface enable-animations).
    readonly property bool reduced: false

    // Durations in ms (04 §2.1): <token>In / <token>Out.
    readonly property int pressIn: 60
    readonly property int pressOut: 60
    readonly property int hoverIn: 120
    readonly property int hoverOut: 120
    readonly property int fadeIn: 160
    readonly property int fadeOut: 110
    readonly property int smallIn: 200
    readonly property int smallOut: 140
    readonly property int surfaceIn: 280
    readonly property int surfaceOut: 200
    readonly property int pageIn: 300
    readonly property int pageOut: 220
    readonly property int morphIn: 380
    readonly property int morphOut: 300
    readonly property int introIn: 420
    // `ambient` (04 §2.1): the theme crossfade (M-30) and the wallpaper crossfade (M-28).
    readonly property int ambientTheme: 400
    readonly property int ambientWallpaper: 600
    readonly property int reducedCrossfade: 120

    // Curves (04 §2.2) as QML easing.bezierCurve lists [x1, y1, x2, y2, 1, 1].
    readonly property var standard: []
    readonly property var enter: []
    readonly property var exit: []
    readonly property var linear: []

    // Springs (04 §2.3): SpringAnimation parameters.
    readonly property real notchSpring: 4.0
    readonly property real notchDamping: 0.30
    readonly property real notchMass: 1.0
    readonly property real notchEpsilon: 0.25
    readonly property real snappySpring: 5.0
    readonly property real snappyDamping: 0.40
    readonly property real snappyMass: 1.0
    readonly property real snappyEpsilon: 0.25
    readonly property real gentleSpring: 3.0
    readonly property real gentleDamping: 0.45
    readonly property real gentleMass: 1.0
    readonly property real gentleEpsilon: 0.25

    // Choreography (04 §3).
    readonly property int contentDelay: 60
    readonly property int contentRise: 8
    readonly property int exitContentFade: 100
    readonly property int exitGeometryDelay: 40
    readonly property int staggerStep: 18
    readonly property int staggerCount: 6
    readonly property int staggerTotalMax: 110
    readonly property int digitRoll: 6
    readonly property real iconSwapScale: 0.8
    readonly property int ambientThemeMidpoint: 200

    // Per-animation numbers of the M-xx catalogue (tokens.json motion.catalogue).
    readonly property var catalogue: ({})

    // A duration in ms, honouring reduced motion (moves become the 120 ms crossfade, 04 §5).
    // name: a key of the durations table ("drawer", "notch", …); out: the exit duration.
    function ms(name: string, out: bool): int { throw new Error("Motion.ms: not implemented"); }
    // bezierCurve list for a curve name ("standard" | "enter" | "exit" | "linear").
    function curve(name: string): var { throw new Error("Motion.curve: not implemented"); }
    // { spring, damping, mass, epsilon } for a SpringAnimation ("notch" | "snappy" | "gentle").
    function spring(name: string): var { throw new Error("Motion.spring: not implemented"); }
}
