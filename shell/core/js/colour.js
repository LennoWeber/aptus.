.pragma library
// Colour maths for the palette resolution (08-theming §3): sRGB ↔ OKLab/OKLCH, mixing in OKLab,
// rounding to 8-bit sRGB. Must give byte-identical results to lib/aptus/theme/resolve.py.

// Private helpers.
// Round half away from zero and clamp to 0..255.
function round8(x) {
    // half away from zero (x is never negative after the clamp), clamped to 0..255
    var v = Math.floor(x + 0.5)
    return v < 0 ? 0 : (v > 255 ? 255 : v)
}

// "#rrggbb" → [r, g, b] in 0..255.
function hexToRgb(hex) {
    var h = String(hex).replace("#", "")
    if (h.length !== 6 || /[^0-9a-fA-F]/.test(h))
        throw new Error("colour.hexToRgb: not a #rrggbb colour: " + hex)
    return [parseInt(h.substr(0, 2), 16), parseInt(h.substr(2, 2), 16), parseInt(h.substr(4, 2), 16)]
}
// [r, g, b] in 0..255 (floats allowed) → "#rrggbb", rounded half away from zero and clamped.
function rgbToHex(rgb) {
    var out = "#"
    for (var i = 0; i < 3; i++) {
        var v = round8(rgb[i])
        out += (v < 16 ? "0" : "") + v.toString(16)
    }
    return out
}
// One channel 0..1, sRGB transfer function and its inverse.
function srgbToLinear(c) {
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
}
function linearToSrgb(c) {
    return c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055
}
// "#rrggbb" → [L, a, b] (OKLab) and back.
function hexToOklab(hex) {
    var rgb = hexToRgb(hex)
    var r = srgbToLinear(rgb[0] / 255), g = srgbToLinear(rgb[1] / 255), b = srgbToLinear(rgb[2] / 255)
    var l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    var m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    var s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    return [0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s]
}
function oklabToHex(lab) {
    var l = lab[0] + 0.3963377774 * lab[1] + 0.2158037573 * lab[2]
    var m = lab[0] - 0.1055613458 * lab[1] - 0.0638541728 * lab[2]
    var s = lab[0] - 0.0894841775 * lab[1] - 1.2914855480 * lab[2]
    l = l * l * l; m = m * m * m; s = s * s * s
    var r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    var g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    var b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    function ch(c) { return 255 * linearToSrgb(Math.min(1, Math.max(0, c))) }
    return rgbToHex([ch(r), ch(g), ch(b)])
}
// OKLab → [L, C, h] with h in degrees 0..360.
function oklabToOklch(lab) {
    var c = Math.sqrt(lab[1] * lab[1] + lab[2] * lab[2])
    var h = Math.atan2(lab[2], lab[1]) * 180 / Math.PI
    if (h < 0) h += 360
    return [lab[0], c, h]
}
// fg laid over bg at `amount` (0..1), mixed in OKLab: the washes, accentWash, selection.
function over(fg, bg, amount) { return mix(bg, fg, amount) }
// `from` moved `t` of the way toward `to` in OKLab (contrast high: inks toward ink.main).
function toward(from, to, t) { return mix(from, to, t) }
// Smallest circular distance between two hues in degrees (0..180).
function hueDistance(a, b) {
    var d = Math.abs(a - b) % 360
    return d > 180 ? 360 - d : d
}
// The OKLCH hue of a hex colour.
function hue(hex) { return oklabToOklch(hexToOklab(hex))[2] }
// OKLab interpolation between two "#rrggbb" colours, t in 0..1 (over and toward build on it).
function mix(a, b, t) {
    var A = hexToOklab(a), B = hexToOklab(b)
    return oklabToHex([A[0] + (B[0] - A[0]) * t, A[1] + (B[1] - A[1]) * t, A[2] + (B[2] - A[2]) * t])
}
