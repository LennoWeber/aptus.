.pragma library
// The bar's layout and status logic (surfaces/bar.md §2–§7) as pure functions.
//
// A status item (StatusCluster, right to left in bar.md §6 order):
//   { id: "battery" | "volume" | "bluetooth" | "network" | "dnd" | "mic" | "camera" | "screen",
//     glyph, ink: "main" | "sec" | "warn" | "crit" | "faint", overlay: "" | "bolt",
//     extra: "" | second glyph after the first ("vpn_key" while a VPN is up),
//     text: "" | the percentage after the battery glyph, tooltip: string,
//     section: the Deck section it opens ("power", "sound", "bluetooth", "network", "dnd",
//       "privacy"), quietKeeps: bool (stays in the quiet bar, M-31b) }
//
// The status input (what Bar/StatusCluster read from the services):
//   { battery: { present, percent, charging, timeToEmpty, timeToFull, profile },
//     volume: { level 0..1.5, muted, device }, bluetooth: { enabled, connected: [{ name, battery }] },
//     network: { kind, online, ssid, strength, vpn: "" | name },
//     dnd: { on, until: "" | "HH:mm", focus: bool }, privacy: { mic: [app], camera: [app],
//     screencast: bool }, settings: { batteryPercent: "auto"|"always"|"never",
//     bluetooth: "connected"|"always" } }
//
// A title throttle state (bar.md §4: more than 4 changes a second → at most every 250 ms):
//   { changes: [ms], shownAt: ms }
