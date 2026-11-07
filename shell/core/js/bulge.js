.pragma library
// The frame path (03-visual-language §6.2): the content area's outline with a dent for every
// open bulge, so the frame band and all drawers are one filled shape (even-odd fill: outer
// rectangle + inner outline). Coordinates are monitor-local logical pixels.
//
// A bulge: { dock: "top"|"topLeft"|"topRight"|"topFull", x, width, height, cove, radius }.

// Smallest bulge that is still drawn (a collapsing drawer below this is left out).
var MIN_SIZE = 0.5

function notImplemented(name) { throw new Error("bulge." + name + ": not implemented") }

// Sort by x, drop invisible ones, clamp into the content area, merge overlaps.
function normalise(bulges, width, edge) { notImplemented("normalise") }
// SVG path data of the frame band with the bulges: outer rectangle, then the inner outline.
// w × h: the monitor; edge: side/bottom thickness; top: the bar height; r: inner corner radius.
function framePath(w, h, edge, top, r, bulges) { notImplemented("framePath") }
// SVG path data of the bulge bodies alone (shadow source).
function bodiesPath(w, edge, top, bulges) { notImplemented("bodiesPath") }
