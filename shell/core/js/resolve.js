.pragma library
// Palette resolution (08-theming §3), identical to lib/aptus/theme/resolve.py.
.import "colour.js" as Colour

// The roles every resolution returns, in a fixed order (resolved.json key order).
var ROLES = ["ground", "raised", "raisedHot", "sunken", "line",
             "inkMain", "inkSec", "inkMeta", "inkFaint", "warn", "crit", "onAccent",
             "accent", "accentWash", "washHover", "washCurrent", "washCurrentHover", "washPressed",
             "selectionBg", "selectionFg", "borderActive", "borderInactive", "link",
             "scrim", "scrimAlpha", "shadow", "shadowAlpha", "frameLine", "frameLineAlpha"]

function notImplemented(name) { throw new Error("resolve." + name + ": not implemented") }

// inputs: { mode: "dark"|"light", accent: name|"wallpaper", contrast: "normal"|"high",
//           glass: bool, wallpaperHue: deg|-1, wallpaperChroma: number|-1,
//           wallpaperLightness: 0..1|-1, currentAccent: name }
// → { mode, palette, accentName, highContrast, glass, groundAlpha, papirus, gnomeAccent,
//     roles: { <role>: "#rrggbb" | number }, ansi: [16 × "#rrggbb"], glyphGrad }
function resolve(tokens, inputs) { notImplemented("resolve") }
// Step 2 of 08 §3: the accent name for `accent` (the six, or the nearest hue for "wallpaper";
// ties and low-chroma images keep currentAccent).
function accentFor(tokens, accent, wallpaperHue, wallpaperChroma, currentAccent, paletteName) { notImplemented("accentFor") }
// Step 5: ground alpha for glass (0.86, 0.92 when the wallpaper's lightness is in the wrong half).
function groundAlpha(tokens, glass, mode, wallpaperLightness) { notImplemented("groundAlpha") }
