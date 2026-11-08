.pragma library
// Palette resolution (08-theming §3), identical to lib/aptus/theme/resolve.py.
.import "colour.js" as Colour

// The roles every resolution returns, in a fixed order (resolved.json key order).
var ROLES = ["ground", "raised", "raisedHot", "sunken", "line",
             "inkMain", "inkSec", "inkMeta", "inkFaint", "warn", "crit", "onAccent",
             "accent", "accentWash", "washHover", "washCurrent", "washCurrentHover", "washPressed",
             "selectionBg", "selectionFg", "borderActive", "borderInactive", "link",
             "scrim", "scrimAlpha", "shadow", "shadowAlpha", "frameLine", "frameLineAlpha"]

// Invariants: Tokens resolves `auto` to a mode before calling and Config has validated the enums,
// so anything else is a caller bug ("resolve invariant: …").
function invariant(cond, message) { if (!cond) throw new Error("resolve invariant: " + message) }
function checkInputs(tokens, inputs) {
    invariant(tokens && tokens.palettes && tokens.accents, "tokens without palettes or accents")
    invariant(inputs.mode === "dark" || inputs.mode === "light", "mode " + inputs.mode + " (auto is resolved by Tokens)")
    invariant(inputs.accent === "wallpaper" || inputs.accent in tokens.accents, "unknown accent " + inputs.accent)
    invariant(inputs.contrast === "normal" || inputs.contrast === "high", "contrast " + inputs.contrast)
}

// inputs: { mode: "dark"|"light", accent: name|"wallpaper", contrast: "normal"|"high",
//           glass: bool, wallpaperHue: deg|-1, wallpaperChroma: number|-1,
//           wallpaperLightness: 0..1|-1, currentAccent: name }
// → { mode, palette, accentName, highContrast, glass, groundAlpha, papirus, gnomeAccent,
//     roles: { <role>: "#rrggbb" | number }, ansi: [16 × "#rrggbb"], glyphGrad }
function resolve(tokens, inputs) {
    checkInputs(tokens, inputs);
    var mode = inputs.mode === "light" ? "light" : "dark"
    var paletteName = tokens.modes[mode]
    var p = tokens.palettes[paletteName]
    var accentName = accentFor(tokens, inputs.accent, inputs.wallpaperHue, inputs.wallpaperChroma,
                               inputs.currentAccent, paletteName)
    var accent = tokens.accents[accentName][paletteName]
    var high = inputs.contrast === "high"
    var inkSec = p.ink.sec, inkMeta = p.ink.meta
    if (high) {
        inkSec = Colour.toward(inkSec, p.ink.main, tokens.contrastHigh.toward)
        inkMeta = Colour.toward(inkMeta, p.ink.main, tokens.contrastHigh.toward)
    }
    var w = tokens.washes
    var roles = {
        ground: p.ground, raised: p.raised, raisedHot: p.raisedHot, sunken: p.sunken, line: p.line,
        inkMain: p.ink.main, inkSec: inkSec, inkMeta: inkMeta, inkFaint: p.ink.faint,
        warn: p.warn, crit: p.crit, onAccent: p.onAccent,
        accent: accent,
        accentWash: Colour.over(accent, p.ground, w.accentWash),
        washHover: Colour.over(p.ink.main, p.ground, w.hover),
        washCurrent: Colour.over(p.ink.main, p.ground, w.current),
        washCurrentHover: Colour.over(p.ink.main, p.ground, w.currentHover),
        washPressed: Colour.over(p.ink.main, p.ground, w.pressed),
        selectionBg: Colour.over(accent, p.ground, p.selectionAmount),
        selectionFg: p.ink.main,
        borderActive: accent, borderInactive: p.line, link: accent,
        scrim: p.scrim.color, scrimAlpha: p.scrim.alpha,
        shadow: p.shadow.color, shadowAlpha: p.shadow.alpha,
        frameLine: p.line, frameLineAlpha: tokens.frameLine.alpha
    }
    var ordered = {}
    for (var i = 0; i < ROLES.length; i++) ordered[ROLES[i]] = roles[ROLES[i]]
    return {
        mode: mode, palette: paletteName, accentName: accentName, highContrast: high,
        glass: !!inputs.glass,
        groundAlpha: groundAlpha(tokens, !!inputs.glass, mode, inputs.wallpaperLightness),
        papirus: tokens.accents[accentName].papirus, gnomeAccent: tokens.accents[accentName].gnome,
        roles: ordered, ansi: p.ansi.slice(), glyphGrad: p.glyphGrad
    }
}
// Step 2 of 08 §3: the accent name for `accent` (the six, or the nearest hue for "wallpaper";
// ties and low-chroma images keep currentAccent).
function accentFor(tokens, accent, wallpaperHue, wallpaperChroma, currentAccent, paletteName) {
    var current = tokens.accents[currentAccent] ? currentAccent : tokens.accentOrder[0]
    if (accent !== "wallpaper")
        return tokens.accents[accent] ? accent : current
    if (wallpaperHue === undefined || wallpaperHue < 0 || wallpaperChroma === undefined
            || wallpaperChroma < tokens.wallpaperAccent.minChroma)
        return current
    var pal = paletteName || "ember"
    var best = current, bestD = Colour.hueDistance(Colour.hue(tokens.accents[current][pal]), wallpaperHue)
    for (var i = 0; i < tokens.accentOrder.length; i++) {
        var name = tokens.accentOrder[i]
        var d = Colour.hueDistance(Colour.hue(tokens.accents[name][pal]), wallpaperHue)
        if (d < bestD - 1e-9) { best = name; bestD = d }
    }
    return best
}
// Step 5: ground alpha for glass (0.86, 0.92 when the wallpaper's lightness is in the wrong half).
function groundAlpha(tokens, glass, mode, wallpaperLightness) {
    if (!glass) return tokens.glass.solidAlpha
    var half = tokens.surfaces && tokens.surfaces.wallpaper ? tokens.surfaces.wallpaper.darkLightnessThreshold : 0.5
    var wrong = wallpaperLightness !== undefined && wallpaperLightness >= 0
              && (mode === "dark" ? wallpaperLightness > half : wallpaperLightness < half)
    return wrong ? tokens.glass.groundAlphaWrongHalf : tokens.glass.groundAlpha
}
