.pragma library
// The frame path (03-visual-language §6.2): the content area's outline with a dent for every
// open bulge, so the frame band and all drawers are one filled shape (even-odd fill: outer
// rectangle + inner outline). Coordinates are monitor-local logical pixels.
//
// A bulge: { dock: "top"|"topLeft"|"topRight"|"topFull", x, width, height, cove, radius }.

// Smallest bulge that is still drawn (a collapsing drawer below this is left out).
var MIN_SIZE = 0.5

// A number for SVG path data (2 decimals).
function num(n) { return (Math.round(n * 100) / 100).toString() }

// Sort by x, drop invisible ones, clamp into the content area, merge overlaps.
function normalise(bulges, width, edge) {
    var left = edge, right = width - edge
    var full = null, list = []
    for (var i = 0; i < (bulges ? bulges.length : 0); i++) {
        var b = bulges[i]
        if (!b || b.shown === false || !(b.height >= MIN_SIZE)) continue
        var dock = b.dock || "top"
        if (dock === "topFull") {
            if (!full || b.height > full.height) full = { dock: "topFull", x: left, width: right - left, height: b.height, cove: 0, radius: 0 }
            continue
        }
        if (!(b.width >= MIN_SIZE)) continue
        var x = dock === "topLeft" ? left : (dock === "topRight" ? right - b.width : b.x)
        var w = b.width
        x = Math.max(left, Math.min(x, right - w))
        w = Math.min(w, right - x)
        var cove = Math.max(0, Math.min(b.cove || 0, b.height))
        var radius = Math.max(0, Math.min(b.radius || 0, b.height / 2, w / 2))
        list.push({ dock: dock, x: x, width: w, height: b.height, cove: cove, radius: radius })
    }
    list.sort(function (a, c) { return a.x - c.x })
    var merged = []
    for (var j = 0; j < list.length; j++) {
        var cur = list[j], prev = merged.length ? merged[merged.length - 1] : null
        if (prev && cur.x - cur.cove <= prev.x + prev.width + prev.cove) {
            var r = Math.max(prev.x + prev.width, cur.x + cur.width)
            prev.x = Math.min(prev.x, cur.x)
            prev.width = r - prev.x
            prev.height = Math.max(prev.height, cur.height)
            prev.cove = Math.max(prev.cove, cur.cove)
            prev.radius = Math.max(prev.radius, cur.radius)
            prev.dock = prev.dock === "topLeft" || cur.dock === "topLeft" ? (prev.dock === "topRight" || cur.dock === "topRight" ? "topFull" : "topLeft")
                      : (prev.dock === "topRight" || cur.dock === "topRight" ? "topRight" : "top")
        } else {
            merged.push(cur)
        }
    }
    return { full: full, bulges: merged }
}
// SVG path data of the frame band with the bulges: outer rectangle, then the inner outline.
// w × h: the monitor; edge: side/bottom thickness; top: the bar height; r: inner corner radius.
function framePath(w, h, edge, top, r, bulges) {
    var n = normalise(bulges, w, edge)
    var t = top + (n.full ? n.full.height : 0)
    var L = edge, R = w - edge, B = h - edge
    r = Math.max(0, Math.min(r, (R - L) / 2, (B - t) / 2))
    var p = []
    // outer rectangle, 2 px outside the monitor so a stroke of this path never shows on screen
    p.push("M -2 -2 L " + num(w + 2) + " -2 L " + num(w + 2) + " " + num(h + 2) + " L -2 " + num(h + 2) + " Z")

    var bs = n.bulges
    var first = bs.length && bs[0].dock === "topLeft" ? bs[0] : null
    var last = bs.length && bs[bs.length - 1].dock === "topRight" ? bs[bs.length - 1] : null

    // start on the left edge
    if (first) {
        var fy = t + first.height
        p.push("M " + num(L) + " " + num(fy + first.cove))
        p.push("A " + num(first.cove) + " " + num(first.cove) + " 0 0 1 " + num(L + first.cove) + " " + num(fy))
        p.push("L " + num(first.x + first.width - first.radius) + " " + num(fy))
        p.push("A " + num(first.radius) + " " + num(first.radius) + " 0 0 0 " + num(first.x + first.width) + " " + num(fy - first.radius))
        p.push("L " + num(first.x + first.width) + " " + num(t + first.cove))
        p.push("A " + num(first.cove) + " " + num(first.cove) + " 0 0 1 " + num(first.x + first.width + first.cove) + " " + num(t))
    } else {
        p.push("M " + num(L) + " " + num(t + r))
        p.push("A " + num(r) + " " + num(r) + " 0 0 1 " + num(L + r) + " " + num(t))
    }
    for (var i = 0; i < bs.length; i++) {
        var b = bs[i]
        if (b === first || b === last) continue
        var by = t + b.height
        p.push("L " + num(b.x - b.cove) + " " + num(t))
        p.push("A " + num(b.cove) + " " + num(b.cove) + " 0 0 1 " + num(b.x) + " " + num(t + b.cove))
        p.push("L " + num(b.x) + " " + num(by - b.radius))
        p.push("A " + num(b.radius) + " " + num(b.radius) + " 0 0 0 " + num(b.x + b.radius) + " " + num(by))
        p.push("L " + num(b.x + b.width - b.radius) + " " + num(by))
        p.push("A " + num(b.radius) + " " + num(b.radius) + " 0 0 0 " + num(b.x + b.width) + " " + num(by - b.radius))
        p.push("L " + num(b.x + b.width) + " " + num(t + b.cove))
        p.push("A " + num(b.cove) + " " + num(b.cove) + " 0 0 1 " + num(b.x + b.width + b.cove) + " " + num(t))
    }
    if (last) {
        var ly = t + last.height
        p.push("L " + num(last.x - last.cove) + " " + num(t))
        p.push("A " + num(last.cove) + " " + num(last.cove) + " 0 0 1 " + num(last.x) + " " + num(t + last.cove))
        p.push("L " + num(last.x) + " " + num(ly - last.radius))
        p.push("A " + num(last.radius) + " " + num(last.radius) + " 0 0 0 " + num(last.x + last.radius) + " " + num(ly))
        p.push("L " + num(R - last.cove) + " " + num(ly))
        p.push("A " + num(last.cove) + " " + num(last.cove) + " 0 0 1 " + num(R) + " " + num(ly + last.cove))
    } else {
        p.push("L " + num(R - r) + " " + num(t))
        p.push("A " + num(r) + " " + num(r) + " 0 0 1 " + num(R) + " " + num(t + r))
    }
    p.push("L " + num(R) + " " + num(B - r))
    p.push("A " + num(r) + " " + num(r) + " 0 0 1 " + num(R - r) + " " + num(B))
    p.push("L " + num(L + r) + " " + num(B))
    p.push("A " + num(r) + " " + num(r) + " 0 0 1 " + num(L) + " " + num(B - r))
    p.push("Z")
    return p.join(" ")
}
// SVG path data of the bulge bodies alone (shadow source).
function bodiesPath(w, edge, top, bulges) {
    var n = normalise(bulges, w, edge)
    var p = []
    var t = top
    if (n.full)
        p.push("M " + num(edge) + " " + num(t) + " L " + num(w - edge) + " " + num(t) + " L " + num(w - edge) + " " + num(t + n.full.height)
               + " L " + num(edge) + " " + num(t + n.full.height) + " Z")
    t += n.full ? n.full.height : 0
    for (var i = 0; i < n.bulges.length; i++) {
        var b = n.bulges[i], by = t + b.height
        p.push("M " + num(b.x) + " " + num(t) + " L " + num(b.x + b.width) + " " + num(t)
               + " L " + num(b.x + b.width) + " " + num(by - b.radius)
               + " A " + num(b.radius) + " " + num(b.radius) + " 0 0 1 " + num(b.x + b.width - b.radius) + " " + num(by)
               + " L " + num(b.x + b.radius) + " " + num(by)
               + " A " + num(b.radius) + " " + num(b.radius) + " 0 0 1 " + num(b.x) + " " + num(by - b.radius) + " Z")
    }
    return p.join(" ")
}
