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
function batteryGlyph(percent, charging, warnAt, critAt) { throw new Error("not implemented") }
// The volume glyph by level (0..1.5) or muted.
function volumeGlyph(level, muted) { throw new Error("not implemented") }
// The network's status glyph: Wi-Fi strength (4 steps), lan, or wifi_off (faint) offline.
function networkGlyph(kind, online, strength) { throw new Error("not implemented") }
// The brightness glyph by level (0..1).
function brightnessGlyph(level) { throw new Error("not implemented") }
// One key step on a percent scale: the next multiple of `stepPercent` in `direction`, clamped.
function step(percent, direction, stepPercent, min, max) { throw new Error("not implemented") }
// OSD payloads (notch.md §8).
function volumeOsd(level, muted, boost, device) { throw new Error("not implemented") }
function micOsd(muted, device) { throw new Error("not implemented") }
function brightnessOsd(level) { throw new Error("not implemented") }
function kbdOsd(level, max) { throw new Error("not implemented") }
function capsOsd(on) { throw new Error("not implemented") }
function layoutOsd(name) { throw new Error("not implemented") }
