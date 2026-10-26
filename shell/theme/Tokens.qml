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
    NumberAnimation { id: fadeAnim; target: root; property: "themeFade"; from: 0; to: 1; duration: root.colorModeMs; easing.type: Easing.InOutSine }
    // The colours follow while it moves; applyPalette does not write themeFade back.
    onThemeFadeChanged: if (toColors) applyPalette(blend, themeFade)
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
    property color accentInk: "#F4F3EF"        // text and icons on the accent
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
        buildThemeList()
        setTheme(themeId, false)
    }

    // Palette between day (0) and night (1) (night light) of the mix of fromColors and toColors at `fade` (0 .. 1, themeFade);
    // the night tint is applied on top, weaker the darker the mix is (darknessAt, nightTintInDark).
    function paletteAt(blend: real, fade: real): var {
        if (!(blend >= 0 && blend <= 1)) throw new Error("invariant: Tokens.paletteAt: blend outside 0..1")
        if (!(fade >= 0 && fade <= 1)) throw new Error("invariant: Tokens.paletteAt: fade outside 0..1")
        if (!palette || !toColors) throw new Error("invariant: Tokens.paletteAt: tokens not loaded")
        const base = mixColors(fromColors || toColors, toColors, fade)
        // The night tint is the step from the day to the night colour of each role; it is added to the mix, weaker the darker it is.
        const tint = blend * (1 - darknessAt(fade) * (1 - nightTintInDark))
        const clamp = v => Math.max(0, Math.min(1, v))
        const out = {}
        for (const key in base) {
            const c = base[key]
            if (typeof c !== "object") continue
            const day = palette.day[key] !== undefined ? Qt.color(palette.day[key]) : null
            const night = palette.night[key] !== undefined ? Qt.color(palette.night[key]) : null
            if (!day || !night) { out[key] = c; continue }
            out[key] = Qt.rgba(clamp(c.r + (night.r - day.r) * tint), clamp(c.g + (night.g - day.g) * tint), clamp(c.b + (night.b - day.b) * tint), 1)
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
        if (!(fade >= 0 && fade <= 1)) throw new Error("invariant: Tokens.applyPalette: fade outside 0..1")
        // NightLightState calls this when its blend changes (it moves over seconds, never a flash).
        const p = paletteAt(blend, fade)
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
        accent = p.accent
        accentInk = p.accentInk
        on = p.on
        // the night light has never tinted the bar, the washes or the glass; they follow the theme only
        applyDerived(paletteAt(0, fade), darknessAt(fade))
    }

    // The colours that follow the theme without the night tint: bar, barInk, barInkSoft, barInkFaint, selection, wash1 to
    // wash4 and glass, for the palette `p` (from paletteAt with blend 0) and `darkness` (0 .. 1).
    function applyDerived(p: var, darkness: real): void {
        if (!(darkness >= 0 && darkness <= 1)) throw new Error("invariant: Tokens.applyDerived: darkness outside 0..1")
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
        glass = glassFor(p.surface, darkness)
    }

    // The fill of the blurred surfaces (Control Center, launcher) for a surface colour: translucent, a little denser the
    // darker the theme is; `darkness` is 0 .. 1 (darknessAt). Returns "#AARRGGBB".
    function glassFor(base: color, darkness: real): color {
        if (!(darkness >= 0 && darkness <= 1)) throw new Error("invariant: Tokens.glassFor: darkness outside 0..1")
        return Qt.rgba(base.r, base.g, base.b, 0.72 + 0.08 * darkness)
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
    // "auto" is a setting value, not a theme. "wallpaper" is always listed; it has colours once customTheme is set.
    function themeIds(): var {
        const ids = ["light", "dark"]
        if (palette && palette.themes) for (const key in palette.themes) if (key !== "note") ids.push(key)
        ids.push("wallpaper")
        return ids
    }

    // The flat colour map ({ role: "#RRGGBB", base: "light" | "dark", name }) of a theme: light is palette.day, dark is
    // palette.dark (base dark), the colour themes are palette.themes, wallpaper is customTheme. null for an unknown id,
    // or for wallpaper while customTheme is null.
    function themeColors(id: string): var {
        if (typeof id !== "string" || id === "") throw new Error("invariant: Tokens.themeColors: id must be a non-empty string")
        if (!palette) return null
        const flat = (src, base, name) => {
            const out = { base: base, name: name, darkness: base === "dark" ? 1 : 0 }
            for (const key in src) if (String(src[key])[0] === "#") out[key] = src[key]
            return out
        }
        if (id === "light") return flat(palette.day, "light", "Light")
        if (id === "dark") return flat(palette.dark, "dark", "Dark")
        if (id === "wallpaper") return customTheme ? flat(customTheme, customTheme.base === "dark" ? "dark" : "light", "Wallpaper") : null
        const t = id !== "note" && palette.themes ? palette.themes[id] : undefined
        return t ? flat(t, t.base, t.name) : null
    }

    // Whether a theme is dark (its base), 0 or 1; unknown ids count as light.
    function isDarkTheme(id: string): bool {
        const c = themeColors(id)
        return c !== null && c.base === "dark"
    }

    // The darkness (0 light .. 1 dark) of the colours showing at `fade` between fromColors and toColors; the night tint is weaker the darker it is.
    function darknessAt(fade: real): real {
        if (!(fade >= 0 && fade <= 1)) throw new Error("invariant: Tokens.darknessAt: fade outside 0..1")
        const to = toColors ? toColors.darkness : 0
        const from = fromColors ? fromColors.darkness : to
        return from + (to - from) * fade
    }

    // Pure: mix two flat colour maps role by role. t in 0..1; roles missing in either map are taken from the other.
    function mixColors(a: var, b: var, t: real): var {
        if (!a || !b) throw new Error("invariant: Tokens.mixColors: both colour maps are needed")
        if (!(t >= 0 && t <= 1)) throw new Error("invariant: Tokens.mixColors: t outside 0..1")
        const out = {}
        const keys = Object.keys(a).concat(Object.keys(b).filter(k => !(k in a)))
        for (const key of keys) {
            const x = a[key] !== undefined ? a[key] : b[key]
            const y = b[key] !== undefined ? b[key] : a[key]
            if (typeof x === "number") out[key] = x + (y - x) * t
            else if (key === "base" || key === "name") out[key] = t < 0.5 ? x : y
            else out[key] = mix(Qt.color(x), Qt.color(y), t)
        }
        return out
    }

    // Show the theme `id`: `animate` fades from the colours showing now (also while a fade runs), otherwise it switches at once
    // (start-up). Does nothing for an unknown id.
    function setTheme(id: string, animate: bool): void {
        if (typeof id !== "string" || id === "") throw new Error("invariant: Tokens.setTheme: id must be a non-empty string")
        if (id === "auto") throw new Error("invariant: Tokens.setTheme: auto is a setting value, ColorModeState resolves it")
        const target = themeColors(id)
        if (!target || !palette) return
        // the colours showing now are where a fade starts, also when another fade is still running
        const now = toColors ? mixColors(fromColors || toColors, toColors, themeFade) : target
        fadeAnim.stop()
        themeId = id
        if (animate && toColors) {
            fromColors = now
            toColors = target
            themeFade = 0
            fadeAnim.start()
        } else {
            fromColors = target
            toColors = target
            themeFade = 1
        }
        applyPalette(blend, themeFade)
    }

    // The generated palette for the theme "wallpaper" (ThemeSource.palette), or null. When the wallpaper theme shows, it fades to the new colours.
    function setCustomTheme(colors: var): void {
        if (colors !== null && !(colors.base === "light" || colors.base === "dark")) throw new Error("invariant: Tokens.setCustomTheme: the palette needs a base, light or dark")
        if (colors !== null && ["bg", "surface", "surfaceAlt", "line", "ink", "inkSoft", "inkFaint", "ok", "warn", "critical", "accent", "accentInk", "on"].some(k => String(colors[k])[0] !== "#")) throw new Error("invariant: Tokens.setCustomTheme: the palette misses a colour")
        customTheme = colors
        buildThemeList()
    }

    // Fill themeList from the loaded tokens (and customTheme) so that the picker and the settings can draw samples.
    function buildThemeList(): void {
        themeList = themeIds().map(id => {
            const c = themeColors(id)
            // the wallpaper theme has no colours until the picture has been read: a calm grey sample
            return c ? { id: id, name: c.name, base: c.base, bg: c.bg, surface: c.surface, ink: c.ink, accent: c.accent }
                     : { id: id, name: "Wallpaper", base: "light", bg: "#D8DADD", surface: "#E8EAEC", ink: "#4A4F55", accent: "#8A9098", pending: true }
        })
    }

    // The Enums.WallpaperFit for a name of the setting wallpaper.fit (fill, fit, stretch, center, tile); Fill for anything else.
    function fitFromName(name: string): int {
        if (typeof name !== "string") throw new Error("invariant: Tokens.fitFromName: name must be a string")
        const fits = { fill: Enums.WallpaperFit.Fill, fit: Enums.WallpaperFit.Fit, stretch: Enums.WallpaperFit.Stretch, center: Enums.WallpaperFit.Center, tile: Enums.WallpaperFit.Tile }
        return fits[name] ?? Enums.WallpaperFit.Fill
    }

    // The Image.fillMode that shows a picture the way `fit` (Enums.WallpaperFit) says. Shared by the desktop and the login screen.
    function fillModeFor(fit: int): int {
        if (!(fit >= Enums.WallpaperFit.Fill && fit <= Enums.WallpaperFit.Tile)) throw new Error("invariant: Tokens.fillModeFor: unknown fit")
        switch (fit) {
        case Enums.WallpaperFit.Fit: return Image.PreserveAspectFit
        case Enums.WallpaperFit.Stretch: return Image.Stretch
        case Enums.WallpaperFit.Center: return Image.Pad
        case Enums.WallpaperFit.Tile: return Image.Tile
        default: return Image.PreserveAspectCrop
        }
    }
}
