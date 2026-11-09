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

    // Durations: ms(name, out) (04 §2.1; it honours reduced motion). The two ambient ones:
    // the wallpaper crossfade (M-28); the theme crossfade (M-30) is Tokens._themeMs.
    readonly property int ambientWallpaper: _m ? _m.durations.ambient.wallpaper : 600
    readonly property int reducedCrossfade: _m ? _m.reduced.crossfade : 120

    // Curves (04 §2.2) as QML easing.bezierCurve lists [x1, y1, x2, y2, 1, 1].
    readonly property var standard: curve("standard")
    readonly property var enter: curve("enter")
    readonly property var exit: curve("exit")
    readonly property var linear: curve("linear")

    // Springs (04 §2.3): name ("notch" | "snappy" | "gentle") → { spring, damping, mass, epsilon }
    // for a SpringAnimation.
    readonly property var springs: _m ? _m.springs : ({})

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
    // Before tokens.json has loaded, every lookup gives 0 (scaleFrom 1) without a warning; the
    // bindings that call them depend on _m and run again once it is there.
    function ms(name: string, out: bool): int {
        if (!_m) return 0;
        const d = _m.durations[name];
        if (!d) { Log.warn("motion", "unknown duration " + name); return 0; }
        if (reduced && name !== "press" && name !== "hover") return reducedCrossfade;
        return out ? d["out"] : d["in"];
    }
    // A catalogue duration in ms ("menu", "scrim.fade", "loadingDelay"). An entry with "in"/"out"
    // (a surface's own transition) gives "out" when `out` is set, else "in", and with reduced motion
    // the 120 ms crossfade, like ms(); single numbers (delays, holds, fades) come back as they are.
    function catalogueMs(path: string, out: bool): int {
        if (!_m) return 0;
        let v = _at(path);
        if (v !== null && typeof v === "object" && ("in" in v || "out" in v)) {
            if (reduced) return reducedCrossfade;
            v = out && v["out"] !== undefined ? v["out"] : v["in"];
        }
        if (typeof v !== "number") { Log.warn("motion", "unknown catalogue duration " + path); return 0; }
        return v;
    }
    // A number of the catalogue ("fullscreen.hotEdge", "capture.dimAmount"); 0 and a warning when
    // the path is unknown.
    function catalogueValue(path: string): real {
        if (!_m) return 0;
        const v = _at(path);
        if (typeof v !== "number") { Log.warn("motion", "unknown catalogue value " + path); return 0; }
        return v;
    }
    // A catalogue entry's entrance scale ("menu", "wallpaper": its scaleFrom); 1 with reduced
    // motion (nothing scales, 04 §7).
    function scaleFrom(name: string): real {
        return reduced || !_m ? 1 : catalogueValue(name + ".scaleFrom");
    }
    // The catalogue entry at a dotted path, undefined when missing.
    function _at(path: string): var {
        let v = catalogue;
        for (const k of path.split(".")) v = v !== undefined && v !== null ? v[k] : undefined;
        return v;
    }
    // bezierCurve list for a curve name ("standard" | "enter" | "exit" | "linear").
    function curve(name: string): var {
        const c = _m && _m.curves[name] ? _m.curves[name] : [0.2, 0, 0, 1];
        return [c[0], c[1], c[2], c[3], 1, 1];
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
