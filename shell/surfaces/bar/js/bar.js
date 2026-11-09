.pragma library
.import "../../../core/js/format.js" as F
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
// The status input (what StatusCluster reads from the services, with the services' own names):
//   { battery: { hasBattery, percentage, charging, timeToEmpty, timeToFull, profile } (Power),
//     volume: { level 0..1.5, muted, device }, bluetooth: { enabled, connected: [{ name, battery }] },
//     network: { kind, online, ssid, strength, vpn: "" | name },
//     dnd: { on, until: "" | "HH:mm", focus: bool }, privacy: { mic: [app], camera: [app],
//     screencast: bool }, settings: { batteryPercent: "auto"|"always"|"never",
//     bluetooth: "connected"|"always" } }
//
// A title throttle state (bar.md §4: more than 4 changes a second → at most every 250 ms):
//   { changes: [ms], shownAt: ms }

// The order of the status items, right to left (bar.md §6).
var STATUS_ORDER = ["battery", "volume", "bluetooth", "network", "dnd", "mic", "camera", "screen"]
// The window state glyphs after the title (bar.md §4).
var WINDOW_GLYPHS = { floating: "picture_in_picture", pinned: "push_pin", fullscreen: "fullscreen" }

// The status items for an input (quiet: only those that keep, M-31b).
function statusItems(input, quiet, tokens) { throw new Error("not implemented") }
// "64 % · 3 h 10 min left · Balanced" (durations from core/js/format.js).
function batteryTooltip(battery) { throw new Error("not implemented") }
// The strip's icon collapse level for its widths with icons on every pill, with numbers on the
// inactive pills, and with numbers only, against the 40 % budget (bar.md §3).
function collapseLevel(widthFull, widthInactive, widthNone, maxWidth) { throw new Error("not implemented") }
// The throttle after a title change at `now`, and how long to wait before showing it (0 = now).
function noteTitleChange(throttle, now) { throw new Error("not implemented") }
function titleDelay(throttle, now, rate, minInterval) { throw new Error("not implemented") }
// The tray split: { shown: [item], overflow: [item] } (bar.tray.max, .hidden, .order by id).
function trayLayout(items, max, hidden, order) { throw new Error("not implemented") }
// The Deck args for a status item (deck.openPages: a page instead of the section).
function deckArgs(section, openPages) { throw new Error("not implemented") }
// "2 · zen, kitty" (number or name, then the apps).
function workspaceTooltip(record, appNames) { throw new Error("not implemented") }
// The state glyphs of a window record, in order.
function windowGlyphs(window) { throw new Error("not implemented") }
// The window menu rows (bar.md §4) for a window record; monitors: [name]; current monitor.
function windowMenu(window, monitors, monitor) { throw new Error("not implemented") }
// The pill menu rows (bar.md §3) for a workspace record; monitors: [name]; current monitor.
function pillMenu(record, monitors, monitor) { throw new Error("not implemented") }
// The monitor is narrower than surfaces.bar.narrowMonitorWidth.
function isNarrow(width, threshold) { throw new Error("not implemented") }
