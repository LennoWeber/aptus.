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
//     device: string ("" or the device name shown for 1 s instead of the value on a device change) }
//
// A status glyph: { glyph, ink: "main" | "sec" | "warn" | "crit" | "faint", overlay: "" | "bolt" }.
