pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.models

// Design values. The source is theme/tokens.json; the colours below start as the day palette so that nothing is ever
// unset, and load() replaces them with the file's values. NightLightState drives `blend` (day 0 .. night 1).
Singleton {
    id: root
    // bar
    readonly property int barHeight: 28
    // Height of the strip at the top edge that windows must not cover and that dropdowns, panels and popups start
    // below: the bar's height, or the notch's reserve. Set from shell.qml; barHeight stays the bar's own size.
    property int topInset: barHeight

    // raw data of theme/tokens.json and the current day/night blend (0 day .. 1 night)
    property var palette             // { day: {...}, night: {...} }
    property real blend: 0

    // colors (semantic)
    property color bg: "#F4F3EF"
    property color surface: "#FBFAF7"
    property color surfaceAlt: "#ECEAE4"
    property color line: "#D9D6CE"
    property color ink: "#1C2127"
    property color inkSoft: "#5A616B"
    property color inkFaint: "#8D939B"
    property color ok: "#1F6B4F"
    property color warn: "#B7791F"
    property color critical: "#B3382C"

    // shape
    readonly property int radiusWindow: 10
    readonly property int radiusDropdown: 10
    readonly property int radiusTile: 16
    readonly property int radiusPill: 999

    // spacing
    readonly property int spaceXs: 4
    readonly property int spaceSm: 8
    readonly property int spaceMd: 12
    readonly property int spaceLg: 20
    readonly property int spaceXl: 32

    // motion
    readonly property int durFast: 140
    readonly property int durSlow: 260
    readonly property int feedbackBudgetMs: 50

    // typography
    property string fontUi: "Inter"          // load() picks "Inter Variable" or "Inter", whichever is installed
    property string fontMono: "JetBrains Mono"
    readonly property int sizeBar: 12
    readonly property int sizeBody: 13
    readonly property int sizeTitle: 18
    readonly property int sizeDisplay: 32

    // blur overlay
    readonly property real overlayDim: 0.18
    readonly property int blurRadius: 18

    readonly property string rootDir: Quickshell.env("APTUS_ROOT") || Quickshell.shellPath("..")

    FileView {
        id: tokensFile
        path: root.rootDir + "/theme/tokens.json"
        blockLoading: true
    }

    Component.onCompleted: load()

    // Read theme/tokens.json.
    function load(): void {
        try {
            const data = JSON.parse(tokensFile.text())
            palette = data.palette
            const families = Qt.fontFamilies()
            fontUi = ["Inter Variable", "Inter"].find(f => families.indexOf(f) >= 0) || data.font.ui
            fontMono = ["JetBrains Mono", "Iosevka Nerd Font Mono", "monospace"].find(f => families.indexOf(f) >= 0) || data.font.mono
        } catch (e) {
            // The built-in day colours stay in place; the bar still renders.
            console.error("aptus: cannot read tokens.json (" + e + "), using built-in day colours")
            return
        }
        applyPalette(blend)
    }

    // Palette between day (0) and night (1).
    function paletteAt(blend: real): var {
        if (!(blend >= 0 && blend <= 1)) throw new Error("invariant: Tokens.paletteAt: blend outside 0..1")
        if (!palette) throw new Error("invariant: Tokens.paletteAt: tokens not loaded")
        const out = {}
        for (const key in palette.day) {
            if (String(palette.day[key])[0] === "#") out[key] = mix(palette.day[key], palette.night[key], blend)
        }
        return out
    }

    function mix(a: color, b: color, t: real): color {
        if (!(t >= 0 && t <= 1)) throw new Error("invariant: Tokens.mix: t outside 0..1")
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
    }

    // Update the colour properties.
    function applyPalette(blend: real): void {
        if (!(blend >= 0 && blend <= 1)) throw new Error("invariant: Tokens.applyPalette: blend outside 0..1")
        // TODO(phase 7, night light): NightLightState calls this when its blend changes; move smoothly over minutes, never a flash.
        const p = paletteAt(blend)
        root.blend = blend
        bg = p.bg
        surface = p.surface
        surfaceAlt = p.surfaceAlt
        line = p.line
        ink = p.ink
        inkSoft = p.inkSoft
        inkFaint = p.inkFaint
        ok = p.ok
        warn = p.warn
        critical = p.critical
    }

    // Colour for a severity: neutral ink, or ok, warn, critical.
    function colorFor(severity: int): color {
        if (severity < Enums.Severity.Neutral || severity > Enums.Severity.Critical) throw new Error("invariant: Tokens.colorFor: unknown severity")
        switch (severity) {
        case Enums.Severity.Ok: return ok
        case Enums.Severity.Warn: return warn
        case Enums.Severity.Critical: return critical
        default: return ink
        }
    }
}
