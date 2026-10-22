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

    // colour theming (settings appearance.themeSource, appearance.style, bar.tone); the defaults reproduce the standard palette
    property int themeSource: Enums.ThemeSource.Standard
    property int themeStyle: Enums.ThemeStyle.Watercolor
    property int barTone: Enums.BarTone.OffWhite
    property var styles                       // raw themeStyles of tokens.json
    property var extraction                   // raw themeExtraction of tokens.json
    property color bar: "#F4F3EF"             // top bar fill
    property color barInk: "#1C2127"          // text and icons on the bar
    property color wash1: "#ECEAE4"           // tile tints, taken from the four source colours
    property color wash2: "#ECEAE4"
    property color wash3: "#ECEAE4"
    property color wash4: "#ECEAE4"
    property color selection: "#ECEAE4"       // selected row
    property color glass: "#B8FBFAF7"         // fill of the blurred surfaces (Control Center, launcher)
    property string grain: "none"             // "none" | "paper" | "weave", only on large surfaces

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
        // TODO(phase 7, Bild-Theming): then call refreshTheme(); also read themeStyles and themeExtraction from the file. The palette stays the Standard source.
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
        // TODO(phase 7, Bild-Theming): with a themeSource other than Standard the style owns bg, surface, line and the ink colours; do not overwrite them here.
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

    // The colour theme from the source selected by themeSource: the neutral palette, the fallback colours of the style, or
    // the colours of the wallpaper. Called when a setting or the wallpaper colours change.
    function refreshTheme(): void {
        throw new Error("not implemented")
    }

    // Pure: the shell colours for a style from the source colours (entries as in WallpaperColors.entries, at least four).
    // Returns { paper, surface, line, ink, inkSoft, inkFaint, selection, bar, barInk, glass, grain, wash: [4], signal: { ok, warn, critical } }
    // with every colour as "#RRGGBB" (glass as "#AARRGGBB"), computed from themeStyles in tokens.json.
    function styleColors(style: int, entries: var, tone: int): var {
        throw new Error("not implemented")
    }

    // Write the result of styleColors into the colour properties.
    function applyStyle(colors: var): void {
        throw new Error("not implemented")
    }

    // Move a colour toward the warm night tint by `blend` (0 day .. 1 night), so the night light also works on style colours.
    function nightShift(c: color, blend: real): color {
        throw new Error("not implemented")
    }

    // Colour maths for styleColors.
    function hexToHsl(hex: string): var {        // { h: 0..360, s: 0..100, l: 0..100 }
        throw new Error("not implemented")
    }

    function hslToHex(h: real, s: real, l: real): string {
        throw new Error("not implemented")
    }

    // Hue h moved toward `target` by the fraction `amount`, along the shorter way round the colour wheel.
    function shiftHue(h: real, target: real, amount: real): real {
        throw new Error("not implemented")
    }
}
