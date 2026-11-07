.pragma library
// Colour maths for the palette resolution (08-theming §3): sRGB ↔ OKLab/OKLCH, mixing in OKLab,
// rounding to 8-bit sRGB. Must give byte-identical results to lib/aptus/theme/resolve.py.

function notImplemented(name) { throw new Error("colour." + name + ": not implemented") }

// Private helpers.
// Round half away from zero and clamp to 0..255.
function round8(x) { notImplemented("round8") }

// "#rrggbb" → [r, g, b] in 0..255.
function hexToRgb(hex) { notImplemented("hexToRgb") }
// [r, g, b] in 0..255 (floats allowed) → "#rrggbb", rounded half away from zero and clamped.
function rgbToHex(rgb) { notImplemented("rgbToHex") }
// One channel 0..1, sRGB transfer function and its inverse.
function srgbToLinear(c) { notImplemented("srgbToLinear") }
function linearToSrgb(c) { notImplemented("linearToSrgb") }
// "#rrggbb" → [L, a, b] (OKLab) and back.
function hexToOklab(hex) { notImplemented("hexToOklab") }
function oklabToHex(lab) { notImplemented("oklabToHex") }
// OKLab → [L, C, h] with h in degrees 0..360.
function oklabToOklch(lab) { notImplemented("oklabToOklch") }
// fg laid over bg at `amount` (0..1), mixed in OKLab: the washes, accentWash, selection.
function over(fg, bg, amount) { notImplemented("over") }
// `from` moved `t` of the way toward `to` in OKLab (contrast high: inks toward ink.main).
function toward(from, to, t) { notImplemented("toward") }
// Smallest circular distance between two hues in degrees (0..180).
function hueDistance(a, b) { notImplemented("hueDistance") }
// The OKLCH hue of a hex colour.
function hue(hex) { notImplemented("hue") }
// OKLab interpolation between two "#rrggbb" colours, t in 0..1 (Tokens' theme crossfade).
function mix(a, b, t) { notImplemented("mix") }
