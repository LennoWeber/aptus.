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
    // below: the bar's height, or the island's reserve. Set from shell.qml; barHeight stays the bar's own size.
    property int topInset: barHeight

    // raw data of theme/tokens.json and the current day/night blend (0 day .. 1 night)
    property var palette             // { day: {...}, night: {...} }
    property real blend: 0
    // The theme: `themeId` names it (light, dark, ocean, forest, dusk, sand, sky, wallpaper). The colours are the mix of
    // `fromColors` and `toColors` (flat { role: "#RRGGBB" } maps of one palette, see palette.themes in tokens.json) at
    // `themeFade` (0 = from .. 1 = to); a change of theme starts a new fade from the colours showing at that moment.
    // The night light tints on top of the mix.
    property string themeId: "light"
    property real themeFade: 1
    property var fromColors: null
    property var toColors: null
    // The generated theme "wallpaper" (ThemeSource.palette), null until the picture has been read.
    property var customTheme: null
    // Entries { id, name, base, bg, surface, ink, accent } of every theme that can be chosen, in the order of the picker.
    property var themeList: []
    // false while the start-up state is set, so the shell does not fade from light to dark when it starts
    property bool colorModeFade: true
    Behavior on darkAmount {
        enabled: root.colorModeFade
        NumberAnimation { duration: root.colorModeMs; easing.type: Easing.InOutSine }
    }
    // The colours follow while it moves; applyPalette does not write darkAmount back.
    onDarkAmountChanged: if (palette) applyPalette(blend, darkAmount)
    readonly property int colorModeMs: 300
    // How much of the night tint stays in dark mode (1 = as strong as in light mode).
    readonly property real nightTintInDark: 0.35

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
    property color accent: "#1C2127"          // sliders, meters, the active workspace; in light and dark the same as ink
    property color onAccent: "#F4F3EF"        // text and icons on the accent
    property color on: "#1F6B4F"              // the on state of a switch; in light and dark the "ok" colour

    // bar and derived colours; the defaults reproduce the standard palette
    property color bar: "#F4F3EF"             // top bar fill
    property color barInk: "#1C2127"          // text and icons on the bar
    property color wash1: "#ECEAE4"           // tile tints, taken from the four source colours
    property color wash2: "#ECEAE4"
    property color wash3: "#ECEAE4"
    property color wash4: "#ECEAE4"
    property color barInkSoft: "#5A616B"      // secondary text on the bar: a mix of barInk and bar (barInkSoftMix)
    property color barInkFaint: "#8D939B"     // inactive icons on the bar (barInkFaintMix)
    property color selection: "#ECEAE4"       // selected row
    property color glass: "#B8FBFAF7"         // fill of the blurred surfaces (Control Center, launcher)

    // shape
    readonly property int radiusWindow: 10
    readonly property int radiusDropdown: 10
    readonly property int radiusTile: 18
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
    readonly property int staggerMs: 40         // delay between tiles when the control center opens
    readonly property real tileLift: 3          // px a tile rises on hover

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
        // TODO(phase 7, Bild-Theming): read themeStyles and themeExtraction from the file; the shell root then calls refreshTheme(entries). The palette stays the Standard source.
        applyPalette(blend, darkAmount)
    }

    // Palette between day (0) and night (1) (night light) of the mix of fromColors and toColors at `fade` (0 .. 1, themeFade);
    // the night tint is applied on top, weaker the darker the mix is (darknessAt, nightTintInDark).
    function paletteAt(blend: real, fade: real): var {
        if (!(blend >= 0 && blend <= 1)) throw new Error("invariant: Tokens.paletteAt: blend outside 0..1")
        if (!(dark >= 0 && dark <= 1)) throw new Error("invariant: Tokens.paletteAt: dark outside 0..1")
        if (!palette) throw new Error("invariant: Tokens.paletteAt: tokens not loaded")
        const out = {}
        // The night tint is the step from the day to the night colour; it is added to the mix of light and dark,
        // weaker the darker it is.
        const tint = blend * (1 - dark * (1 - nightTintInDark))
        const clamp = v => Math.max(0, Math.min(1, v))
        for (const key in palette.day) {
            if (String(palette.day[key])[0] !== "#") continue
            const day = Qt.color(palette.day[key])
            const night = Qt.color(palette.night[key])
            const base = mix(day, Qt.color(palette.dark?.[key] ?? palette.day[key]), dark)
            out[key] = Qt.rgba(clamp(base.r + (night.r - day.r) * tint), clamp(base.g + (night.g - day.g) * tint), clamp(base.b + (night.b - day.b) * tint), 1)
        }
        return out
    }

    function mix(a: color, b: color, t: real): color {
        if (!(t >= 0 && t <= 1)) throw new Error("invariant: Tokens.mix: t outside 0..1")
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
    }

    // Update the colour properties.
    function applyPalette(blend: real, fade: real): void {
        if (!(blend >= 0 && blend <= 1)) throw new Error("invariant: Tokens.applyPalette: blend outside 0..1")
        if (!(dark >= 0 && dark <= 1)) throw new Error("invariant: Tokens.applyPalette: dark outside 0..1")
        // NightLightState calls this when its blend changes (it moves over seconds, never a flash).
        // TODO(phase 7, Bild-Theming): with a themeSource other than Standard the style owns bg, surface, line and the ink colours; do not overwrite them here while dark is 0.
        const p = paletteAt(blend, dark)
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
        // the night light has never tinted the bar, the washes or the glass; they follow the light or dark palette only
        applyDerived(paletteAt(0, dark), dark)
    }

    // The colours that follow the theme without the night tint: bar, barInk, barInkSoft, barInkFaint, selection, wash1 to
    // wash4 and glass, for the palette `p` (from paletteAt with blend 0) and `darkness` (0 .. 1).
    function applyDerived(p: var, darkness: real): void {
        if (!(dark >= 0 && dark <= 1)) throw new Error("invariant: Tokens.applyDerived: dark outside 0..1")
        if (!p || p.bg === undefined) throw new Error("invariant: Tokens.applyDerived: palette incomplete")
        bar = p.bg
        barInk = p.ink
        barInkSoft = p.inkSoft
        barInkFaint = p.inkFaint
        selection = p.surfaceAlt
        wash1 = p.surfaceAlt
        wash2 = p.surfaceAlt
        wash3 = p.surfaceAlt
        wash4 = p.surfaceAlt
        glass = glassFor(p.surface, dark)
    }

    // The fill of the blurred surfaces (Control Center, launcher) for a surface colour: translucent, a little denser the
    // darker the theme is; `darkness` is 0 .. 1 (darknessAt). Returns "#AARRGGBB".
    function glassFor(base: color, darkness: real): color {
        if (!(dark >= 0 && dark <= 1)) throw new Error("invariant: Tokens.glassFor: dark outside 0..1")
        return Qt.rgba(base.r, base.g, base.b, 0.72 + 0.08 * dark)
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

    // The ids of the themes that can be chosen, in the order of the picker: light, dark, ocean, forest, dusk, sand, sky, wallpaper.
    // "auto" is a setting value, not a theme. "wallpaper" is listed only when customTheme is set.
    function themeIds(): var {
        throw new Error("not implemented")
    }

    // The flat colour map ({ role: "#RRGGBB", base: "light" | "dark", name }) of a theme: light is palette.day, dark is
    // palette.dark (base dark), the colour themes are palette.themes, wallpaper is customTheme. null for an unknown id,
    // or for wallpaper while customTheme is null.
    function themeColors(id: string): var {
        throw new Error("not implemented")
    }

    // Whether a theme is dark (its base), 0 or 1; unknown ids count as light.
    function isDarkTheme(id: string): bool {
        throw new Error("not implemented")
    }

    // The darkness (0 light .. 1 dark) of the colours showing at `fade` between fromColors and toColors; the night tint is weaker the darker it is.
    function darknessAt(fade: real): real {
        throw new Error("not implemented")
    }

    // Pure: mix two flat colour maps role by role. t in 0..1; roles missing in either map are taken from the other.
    function mixColors(a: var, b: var, t: real): var {
        throw new Error("not implemented")
    }

    // Show the theme `id`: `animate` fades from the colours showing now (also while a fade runs), otherwise it switches at once
    // (start-up). Does nothing for an unknown id.
    function setTheme(id: string, animate: bool): void {
        throw new Error("not implemented")
    }

    // The generated palette for the theme "wallpaper" (ThemeSource.palette), or null. When the wallpaper theme shows, it fades to the new colours.
    function setCustomTheme(colors: var): void {
        throw new Error("not implemented")
    }

    // Fill themeList from the loaded tokens (and customTheme) so that the picker and the settings can draw samples.
    function buildThemeList(): void {
        throw new Error("not implemented")
    }

    // The Enums.WallpaperFit for a name of the setting wallpaper.fit (fill, fit, stretch, center, tile); Fill for anything else.
    function fitFromName(name: string): int {
        throw new Error("not implemented")
    }

    // The Image.fillMode that shows a picture the way `fit` (Enums.WallpaperFit) says. Shared by the desktop and the login screen.
    function fillModeFor(fit: int): int {
        throw new Error("not implemented")
    }
}
