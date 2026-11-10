.pragma library
// Levels and their glyphs (surfaces/bar.md §6, surfaces/notch.md §8): battery, volume, Wi-Fi,
// brightness, keyboard light; the step maths of the hardware keys; the OSD payloads.
//
// An OSD payload (SurfaceManager.post("osd", payload, 0, monitor, kind)):
//   { kind: "volume" | "mic" | "brightness" | "kbd" | "caps" | "layout",
//     glyph: string, ink: "main" | "crit" (the glyph's ink),
//     level: number | -1 (no level bar), max: number (100, or 150 with audio.allowBoost),
//     dots: -1 | count of filled dots (keyboard light), steps: count of dots,
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
    throw new Error("not implemented")
}
// The volume glyph by level (0..1.5) or muted.
function volumeGlyph(level, muted) { throw new Error("not implemented") }
// The network's status glyph: Wi-Fi strength (4 steps), lan, or wifi_off (faint) offline.
function networkGlyph(kind, online, strength) { throw new Error("not implemented") }
// The brightness glyph by level (0..1).
function brightnessGlyph(level) { throw new Error("not implemented") }
// One key step on a percent scale: the next multiple of `stepPercent` in `direction`, clamped.
function step(percent, direction, stepPercent, min, max) {
    invariant(direction === 1 || direction === -1, "step direction " + direction)
    invariant(stepPercent > 0 && min < max, "step " + stepPercent + " in " + min + ".." + max)
    throw new Error("not implemented")
}
// OSD payloads (notch.md §8).
function volumeOsd(level, muted, boost, device) {
    invariant(isFinite(level), "volume level " + level)
    // TODO(phase): checkOsd(result), as for every OSD payload below.
    throw new Error("not implemented")
}
function micOsd(muted, device) { throw new Error("not implemented") }
function brightnessOsd(level) {
    invariant(isFinite(level), "brightness level " + level)
    throw new Error("not implemented")
}
function kbdOsd(level, max) {
    invariant(max >= 1 && level >= 0 && level <= max, "keyboard light " + level + "/" + max)
    throw new Error("not implemented")
}
function capsOsd(on) { throw new Error("not implemented") }
function layoutOsd(name) { throw new Error("not implemented") }
// The OSD kinds the Deck has a slider for (volume, mic, brightness): while the Deck is open on
// the monitor its slider moves instead and no OSD is posted (notch.md §8). One place for the rule;
// Audio._osd and Brightness._osd ask it.
function deckReplaces(kind) {
    invariant(OSD_KINDS.indexOf(kind) >= 0, "unknown OSD kind " + kind)
    throw new Error("not implemented")
}

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
