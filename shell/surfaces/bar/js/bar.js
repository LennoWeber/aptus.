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
function statusItems(input, quiet, tokens) {
    checkBarTokens(tokens)
    invariant(["auto", "always", "never"].indexOf(input.settings.batteryPercent) >= 0, "bar.battery.percent " + input.settings.batteryPercent)
    invariant(["connected", "always"].indexOf(input.settings.bluetooth) >= 0, "bar.bluetooth " + input.settings.bluetooth)
    throw new Error("not implemented")
}
// "64 % · 3 h 10 min left · Balanced" (durations from core/js/format.js).
function batteryTooltip(battery) { throw new Error("not implemented") }
// The strip's icon collapse level for its widths with icons on every pill, with numbers on the
// inactive pills, and with numbers only, against the 40 % budget (bar.md §3).
function collapseLevel(widthFull, widthInactive, widthNone, maxWidth) {
    invariant(widthFull >= 0 && widthInactive >= 0 && widthNone >= 0 && maxWidth >= 0, "strip widths")
    throw new Error("not implemented")
}
// The throttle after a title change at `now`, and how long to wait before showing it (0 = now).
function noteTitleChange(throttle, now) {
    invariant(throttle && Array.isArray(throttle.changes), "broken title throttle")
    throw new Error("not implemented")
}
function titleDelay(throttle, now, rate, minInterval) {
    invariant(throttle && Array.isArray(throttle.changes), "broken title throttle")
    invariant(rate >= 1 && minInterval >= 0, "title throttle " + rate + "/" + minInterval)
    throw new Error("not implemented")
}
// The tray split: { shown: [item], overflow: [item] } (bar.tray.max, .hidden, .order by id).
function trayLayout(items, max, hidden, order) {
    invariant(max >= 0 && Math.floor(max) === max, "bar.tray.max " + max)
    invariant(Array.isArray(hidden) && Array.isArray(order), "tray settings are not lists")
    throw new Error("not implemented")
}
// The Deck args for a status item (deck.openPages: a page instead of the section).
function deckArgs(section, openPages) {
    invariant(typeof section === "string" && section !== "", "no Deck section")
    throw new Error("not implemented")
}
// "2 · zen, kitty" (number or name, then the apps).
function workspaceTooltip(record, appNames) { throw new Error("not implemented") }
// The state glyphs of a window record, in order.
function windowGlyphs(window) { throw new Error("not implemented") }
// The window menu rows (bar.md §4) for a window record; monitors: [name]; current monitor.
function windowMenu(window, monitors, monitor) {
    invariant(window && Array.isArray(monitors), "window menu without a window")
    // TODO(phase): checkMenu(result).
    throw new Error("not implemented")
}
// The pill menu rows (bar.md §3) for a workspace record; monitors: [name]; current monitor.
function pillMenu(record, monitors, monitor) {
    // (a named workspace has a negative id too: `special` alone tells a special one)
    invariant(record && !record.special && Array.isArray(monitors), "pill menu of a special or no workspace")
    // TODO(phase): checkMenu(result).
    throw new Error("not implemented")
}
// The title's width (bar.md §2, §9): what is left between the zones, at most titleMaxWidth (240
// on a narrow monitor), 0 (hidden) below titleMinWidth. tokens: Tokens.surfaces.bar.
function titleWidth(available, narrow, tokens) {
    checkBarTokens(tokens)
    throw new Error("not implemented")
}

// Invariants (phase 6): they throw "bar invariant: …".
function invariant(cond, message) { if (!cond) throw new Error("bar invariant: " + message) }
// The bar tokens the logic reads: battery thresholds in order, title widths in order.
function checkBarTokens(t) {
    invariant(t && t.batteryCritPercent > 0 && t.batteryCritPercent < t.batteryWarnPercent
              && t.batteryWarnPercent <= t.batteryShowPercentBelow, "battery thresholds")
    invariant(t.titleMinWidth > 0 && t.titleMinWidth <= t.narrowTitleMaxWidth && t.narrowTitleMaxWidth <= t.titleMaxWidth,
              "title widths")
}
// Menu rows (core Menu): an id each (separators aside), each id once, a submenu with rows.
function checkMenu(rows) {
    var ids = []
    for (var i = 0; i < rows.length; i++) {
        var r = rows[i]
        if (r.separator) continue
        invariant(typeof r.id === "string" && r.id !== "" && typeof r.label === "string" && r.label !== "", "menu row without id or label")
        invariant(ids.indexOf(r.id) < 0, "menu id " + r.id + " twice")
        ids.push(r.id)
        if (r.submenu) checkMenu(r.submenu)
    }
}
