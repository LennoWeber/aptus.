pragma Singleton
pragma ComponentBehavior: Bound
// Durations, curves, springs and choreography of 04-motion, from theme/tokens.json "motion".
// With reduced motion (motion.reduce, §7), geometry durations become 0 and content crossfades
// use `reducedCrossfade`.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // motion.reduce resolved ("auto" reads org.gnome.desktop.interface enable-animations).
    readonly property bool reduced: { const r = Config.loaded ? Config.get("motion.reduce") : "auto"; return r === "on" || (r === "auto" && _systemReduced); }

    // Durations in ms (04 §2.1): <token>In / <token>Out.
    readonly property int pressIn: _m ? _m.durations.press["in"] : 60
    readonly property int pressOut: _m ? _m.durations.press["out"] : 60
    readonly property int hoverIn: _m ? _m.durations.hover["in"] : 120
    readonly property int hoverOut: _m ? _m.durations.hover["out"] : 120
    readonly property int fadeIn: _m ? _m.durations.fade["in"] : 160
    readonly property int fadeOut: _m ? _m.durations.fade["out"] : 110
    readonly property int smallIn: _m ? _m.durations.small["in"] : 200
    readonly property int smallOut: _m ? _m.durations.small["out"] : 140
    readonly property int surfaceIn: _m ? _m.durations.surface["in"] : 280
    readonly property int surfaceOut: _m ? _m.durations.surface["out"] : 200
    readonly property int pageIn: _m ? _m.durations.page["in"] : 300
    readonly property int pageOut: _m ? _m.durations.page["out"] : 220
    readonly property int morphIn: _m ? _m.durations.morph["in"] : 380
    readonly property int morphOut: _m ? _m.durations.morph["out"] : 300
    readonly property int introIn: _m ? _m.durations.intro["in"] : 420
    // `ambient` (04 §2.1): the theme crossfade (M-30) and the wallpaper crossfade (M-28).
    readonly property int ambientTheme: _m ? _m.durations.ambient.theme : 400
    readonly property int ambientWallpaper: _m ? _m.durations.ambient.wallpaper : 600
    readonly property int reducedCrossfade: _m ? _m.reduced.crossfade : 120

    // Curves (04 §2.2) as QML easing.bezierCurve lists [x1, y1, x2, y2, 1, 1].
    readonly property var standard: curve("standard")
    readonly property var enter: curve("enter")
    readonly property var exit: curve("exit")
    readonly property var linear: curve("linear")

    // Springs (04 §2.3): SpringAnimation parameters.
    readonly property real notchSpring: _m ? _m.springs.notch.spring : 4.0
    readonly property real notchDamping: _m ? _m.springs.notch.damping : 0.30
    readonly property real notchMass: _m ? _m.springs.notch.mass : 1.0
    readonly property real notchEpsilon: _m ? _m.springs.notch.epsilon : 0.25
    readonly property real snappySpring: _m ? _m.springs.snappy.spring : 5.0
    readonly property real snappyDamping: _m ? _m.springs.snappy.damping : 0.40
    readonly property real snappyMass: _m ? _m.springs.snappy.mass : 1.0
    readonly property real snappyEpsilon: _m ? _m.springs.snappy.epsilon : 0.25
    readonly property real gentleSpring: _m ? _m.springs.gentle.spring : 3.0
    readonly property real gentleDamping: _m ? _m.springs.gentle.damping : 0.45
    readonly property real gentleMass: _m ? _m.springs.gentle.mass : 1.0
    readonly property real gentleEpsilon: _m ? _m.springs.gentle.epsilon : 0.25

    // Choreography (04 §3).
    readonly property int contentDelay: _m ? _m.choreography.contentDelay : 60
    readonly property int contentRise: _m ? _m.choreography.contentRise : 8
    readonly property int exitContentFade: _m ? _m.choreography.exitContentFade : 100
    readonly property int exitGeometryDelay: _m ? _m.choreography.exitGeometryDelay : 40
    readonly property int staggerStep: _m ? _m.choreography.staggerStep : 18
    readonly property int staggerCount: _m ? _m.choreography.staggerCount : 6
    readonly property int staggerTotalMax: _m ? _m.choreography.staggerTotalMax : 110
    readonly property int digitRoll: _m ? _m.choreography.digitRoll : 6
    readonly property real iconSwapScale: _m ? _m.choreography.iconSwapScale : 0.8
    readonly property int ambientThemeMidpoint: _m ? _m.choreography.themeMidpoint : 200

    // Per-animation numbers of the M-xx catalogue (tokens.json motion.catalogue).
    readonly property var catalogue: _m ? _m.catalogue : ({})

    // A duration in ms, honouring reduced motion (moves become the 120 ms crossfade, 04 §5).
    // name: a key of the durations table ("drawer", "notch", …); out: the exit duration.
    function ms(name: string, out: bool): int {
        const d = _m ? _m.durations[name] : null;
        if (!d) { Log.warn("motion", "unknown duration " + name); return 0; }
        if (reduced && name !== "press" && name !== "hover") return reducedCrossfade;
        return out ? d["out"] : d["in"];
    }
    // A catalogue duration in ms ("menu", "scrim.fade", "loadingDelay"). An entry with "in"/"out"
    // (a surface's own transition) gives "out" when `out` is set, else "in", and with reduced motion
    // the 120 ms crossfade, like ms(); single numbers (delays, holds, fades) come back as they are.
    function catalogueMs(path: string, out: bool): int {
        let v = catalogue;
        for (const k of path.split(".")) v = v !== undefined && v !== null ? v[k] : undefined;
        if (v !== null && typeof v === "object" && ("in" in v || "out" in v)) {
            if (reduced) return reducedCrossfade;
            v = out && v["out"] !== undefined ? v["out"] : v["in"];
        }
        if (typeof v !== "number") { Log.warn("motion", "unknown catalogue duration " + path); return 0; }
        return v;
    }
    // bezierCurve list for a curve name ("standard" | "enter" | "exit" | "linear").
    function curve(name: string): var {
        const c = _m && _m.curves[name] ? _m.curves[name] : [0.2, 0, 0, 1];
        return [c[0], c[1], c[2], c[3], 1, 1];
    }
    // { spring, damping, mass, epsilon } for a SpringAnimation ("notch" | "snappy" | "gentle").
    function spring(name: string): var {
        const p = _m && _m.springs[name] ? _m.springs[name] : { spring: 4, damping: 0.3, mass: 1, epsilon: 0.25 };
        return { spring: p.spring, damping: p.damping, mass: p.mass, epsilon: p.epsilon };
    }

    // Tokens.raw.motion (the catalogue and named durations of 04).
    readonly property var _m: Tokens.raw.motion || null
    // org.gnome.desktop.interface enable-animations is false (read once).
    property bool _systemReduced: false

    Process {
        running: true
        command: ["gsettings", "get", "org.gnome.desktop.interface", "enable-animations"]
        stdout: StdioCollector { onStreamFinished: root._systemReduced = this.text.trim() === "false" }
    }
}
