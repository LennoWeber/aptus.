.pragma library
// Levels and their glyphs (surfaces/bar.md §6, surfaces/notch.md §8): battery, volume, Wi-Fi,
// brightness, keyboard light; the step maths of the hardware keys; the OSD payloads.
//
// An OSD payload (SurfaceManager.post("osd", payload, 0, monitor, kind)):
//   { kind: "volume" | "mic" | "brightness" | "kbd" | "caps" | "layout",
//     glyph: string, ink: "main" | "crit" (the glyph's ink),
//     level: number | -1 (no level bar), max: number (100, or 150 with audio.allowBoost),
//     dots: -1 | the current state's dot, 0 = off (keyboard light), steps: count of dots,
//     value: string (the text after the level: "45", "Muted", "Caps Lock on"),
//     device: string ("" or the device name shown for 1 s instead of the value; the poster
//       sets it only on its first OSD after the device changed, and tracks that itself) }
//
// A status glyph: { glyph, ink: "main" | "sec" | "warn" | "crit" | "faint", overlay: "" | "bolt" }.

// Battery glyphs, empty → full (8 steps, bar.md §6), and the other status/OSD glyphs.
var BATTERY = ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar", "battery_4_bar",
               "battery_5_bar", "battery_6_bar", "battery_full"]
var WIFI = ["network_wifi_1_bar", "network_wifi_2_bar", "network_wifi_3_bar", "network_wifi"]
var VOLUME = ["volume_mute", "volume_down", "volume_up"]
var GLYPHS = { muted: "volume_off", mic: "mic", micOff: "mic_off", bright: "light_mode",
               brightLow: "brightness_low", kbd: "keyboard", caps: "keyboard_capslock",
               layout: "language", wifiOff: "wifi_off", lan: "lan", vpn: "vpn_key", bolt: "bolt",
               bluetooth: "bluetooth_connected", dnd: "do_not_disturb_on", camera: "videocam",
               screen: "screen_share" }

// The battery's status glyph (bar.md §6: warn ≤ 15 %, crit ≤ 7 %, bolt while charging).
function batteryGlyph(percent, charging, warnAt, critAt) {
    invariant(critAt > 0 && critAt < warnAt && warnAt <= 100, "battery thresholds " + critAt + "/" + warnAt)
    var p = Math.max(0, Math.min(100, Number(percent) || 0))
    var i = p >= 97 ? BATTERY.length - 1 : Math.min(BATTERY.length - 2, Math.floor(p / (100 / (BATTERY.length - 1))))
    var ink = charging ? "main" : p <= critAt ? "crit" : p <= warnAt ? "warn" : "main"
    return { glyph: BATTERY[i], ink: ink, overlay: charging ? GLYPHS.bolt : "" }
}
// The volume glyph by level (0..1.5) or muted.
function volumeGlyph(level, muted) {
    if (muted) return { glyph: GLYPHS.muted, ink: "crit", overlay: "" }
    var l = Number(level) || 0
    return { glyph: l <= 0 ? VOLUME[0] : l < 0.5 ? VOLUME[1] : VOLUME[2], ink: "main", overlay: "" }
}
// The network's status glyph: Wi-Fi strength (4 steps), lan, or wifi_off (faint) offline.
function networkGlyph(kind, online, strength) {
    if (!online || kind === "none") return { glyph: GLYPHS.wifiOff, ink: "faint", overlay: "" }
    if (kind === "ethernet") return { glyph: GLYPHS.lan, ink: "main", overlay: "" }
    var s = Math.max(0, Math.min(100, Number(strength) || 0))
    return { glyph: WIFI[Math.min(WIFI.length - 1, Math.floor(s / 25))], ink: "main", overlay: "" }
}
// The brightness glyph by level (0..1).
function brightnessGlyph(level) {
    return { glyph: (Number(level) || 0) < 0.3 ? GLYPHS.brightLow : GLYPHS.bright, ink: "main", overlay: "" }
}
// One key step on a percent scale: the next multiple of `stepPercent` in `direction`, clamped.
function step(percent, direction, stepPercent, min, max) {
    invariant(direction === 1 || direction === -1, "step direction " + direction)
    invariant(stepPercent > 0 && min < max, "step " + stepPercent + " in " + min + ".." + max)
    var p = Math.round(Number(percent) * 1000) / 1000
    var s = Math.max(1, stepPercent)
    var next = direction > 0 ? (Math.floor(p / s + 1e-6) + 1) * s : (Math.ceil(p / s - 1e-6) - 1) * s
    return Math.max(min, Math.min(max, next))
}
// OSD payloads (notch.md §8). A level is the hardware's: clamped into 0..max (NaN is 0), never
// refused (another app can set the sink above the maximum).
// max: osd.volumeMax, or osd.volumeBoostMax with audio.allowBoost.
function volumeOsd(level, muted, max, device) {
    invariant(max >= 1, "volume maximum " + max)
    var g = volumeGlyph(level, muted)
    var v = _clamp(Math.round((Number(level) || 0) * 100), 0, max)
    var p = { kind: "volume", glyph: g.glyph, ink: g.ink, level: muted ? 0 : v, max: max,
              dots: -1, steps: 0, value: muted ? "Muted" : String(v), device: device || "" }
    checkOsd(p)
    return p
}
function micOsd(muted, device) {
    return { kind: "mic", glyph: muted ? GLYPHS.micOff : GLYPHS.mic, ink: muted ? "crit" : "main", level: -1,
             max: 0, dots: -1, steps: 0, value: muted ? "Muted" : "On", device: device || "" }
}
function brightnessOsd(level) {
    var v = _clamp(Math.round((Number(level) || 0) * 100), 0, 100)
    var p = { kind: "brightness", glyph: brightnessGlyph(level).glyph, ink: "main", level: v, max: 100,
              dots: -1, steps: 0, value: String(v), device: "" }
    checkOsd(p)
    return p
}
function kbdOsd(level, max) {
    invariant(max >= 1, "keyboard light maximum " + max)
    var p = { kind: "kbd", glyph: GLYPHS.kbd, ink: "main", level: -1, max: 0,
              dots: _clamp(Math.round(Number(level) || 0), 0, max), steps: max + 1, value: "", device: "" }
    checkOsd(p)
    return p
}
function capsOsd(on) {
    return { kind: "caps", glyph: GLYPHS.caps, ink: "main", level: -1, max: 0, dots: -1, steps: 0,
             value: on ? "Caps Lock on" : "Caps Lock off", device: "" }
}
function layoutOsd(name) {
    return { kind: "layout", glyph: GLYPHS.layout, ink: "main", level: -1, max: 0, dots: -1, steps: 0,
             value: String(name || ""), device: "" }
}
// The OSD kinds the Deck has a slider for (volume, mic, brightness): while the Deck is open on
// the monitor its slider moves instead and no OSD is posted (notch.md §8). One place for the rule;
// Audio._osd and Brightness._osd ask it.
function deckReplaces(kind) {
    invariant(OSD_KINDS.indexOf(kind) >= 0, "unknown OSD kind " + kind)
    return kind === "volume" || kind === "mic" || kind === "brightness"
}

// A number into lo..hi.
function _clamp(x, lo, hi) { return Math.max(lo, Math.min(hi, x)) }

// Invariants (phase 6): they throw "levels invariant: …" (thresholds, steps and OSD kinds come
// from tokens and the services, not from the hardware: a level is clamped, never refused).
var OSD_KINDS = ["volume", "mic", "brightness", "kbd", "caps", "layout"]
function invariant(cond, message) { if (!cond) throw new Error("levels invariant: " + message) }
// An OSD payload: a known kind and glyph, a level within its maximum or none, dots within steps.
function checkOsd(p) {
    invariant(p && OSD_KINDS.indexOf(p.kind) >= 0 && typeof p.glyph === "string" && p.glyph !== "", "broken OSD payload")
    invariant(p.level === -1 || (p.level >= 0 && p.level <= p.max), p.kind + " level " + p.level + "/" + p.max)
    invariant(p.dots === -1 || (p.dots >= 0 && p.dots < p.steps), p.kind + " dots " + p.dots + "/" + p.steps)
}
