.pragma library
.import "../../../core/js/format.js" as F
.import "../../../services/js/levels.js" as Lv
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
    var T = tokens
    var out = []
    var b = input.battery, s = input.settings || {}
    if (b && b.hasBattery) {
        var p = Math.round(b.percentage)
        var g = Lv.batteryGlyph(p, b.charging, T.batteryWarnPercent, T.batteryCritPercent)
        var showText = s.batteryPercent === "always" || (s.batteryPercent !== "never" && (p <= T.batteryShowPercentBelow || b.charging))
        out.push(item("battery", g.glyph, g.ink, g.overlay, "", showText ? p + " %" : "", batteryTooltip(b), "power",
                      p <= T.batteryShowPercentBelow && !b.charging))
    }
    var v = input.volume
    if (v) {
        var vl = Math.round(v.level * 100)
        var vg = Lv.volumeGlyph(v.level, v.muted)
        out.push(item("volume", vg.glyph, vg.ink, "", "", "", (v.muted ? "Muted" : "Volume " + vl + " %") + (v.device ? " · " + v.device : ""), "sound", false))
    }
    var bt = input.bluetooth
    if (bt && bt.available !== false && ((bt.enabled && bt.connected.length > 0) || s.bluetooth === "always")) {
        var names = bt.connected.map(function (d) { return d.name + (d.battery >= 0 ? " · " + Math.round(d.battery) + " %" : "") })
        out.push(item("bluetooth", bt.enabled ? (bt.connected.length > 0 ? "bluetooth_connected" : "bluetooth") : "bluetooth_disabled",
                      bt.enabled ? "main" : "faint", "", "", "", names.length > 0 ? names.join(", ") : (bt.enabled ? "Bluetooth on" : "Bluetooth off"),
                      "bluetooth", false))
    }
    var n = input.network
    if (n) {
        var ng = Lv.networkGlyph(n.kind, n.online, n.strength)
        var parts = []
        if (!n.online || n.kind === "none") parts.push("Offline")
        else if (n.kind === "ethernet") parts.push("Wired")
        else { parts.push(n.ssid || "Wi-Fi"); parts.push(Math.round(n.strength) + " %") }
        if (n.vpn) parts.push("VPN " + n.vpn)
        out.push(item("network", ng.glyph, ng.ink, "", n.vpn ? "vpn_key" : "", "", parts.join(" · "), "network", false))
    }
    var d = input.dnd
    if (d && d.on && !d.focus)
        out.push(item("dnd", "do_not_disturb_on", "main", "", "", "", "Do not disturb" + (d.until ? " until " + d.until : ""), "dnd", false))
    var pr = input.privacy
    if (pr) {
        if (pr.mic.length > 0) out.push(item("mic", "mic", "warn", "", "", "", "Microphone: " + pr.mic.join(", "), "privacy", true))
        if (pr.camera.length > 0) out.push(item("camera", "videocam", "warn", "", "", "", "Camera: " + pr.camera.join(", "), "privacy", true))
        if (pr.screencast) out.push(item("screen", "screen_share", "warn", "", "", "", "Sharing the screen", "privacy", true))
    }
    return quiet ? out.filter(function (i) { return i.quietKeeps }) : out
}
// "64 % · 3 h 10 min left · Balanced" (durations from core/js/format.js).
function batteryTooltip(battery) {
    var parts = [Math.round(battery.percentage) + " %"]
    if (battery.charging && battery.timeToFull > 0) parts.push(F.duration(battery.timeToFull) + " until full")
    else if (!battery.charging && battery.timeToEmpty > 0) parts.push(F.duration(battery.timeToEmpty) + " left")
    else if (battery.charging) parts.push("Charging")
    if (PROFILE_LABELS[battery.profile]) parts.push(PROFILE_LABELS[battery.profile])
    return parts.join(" · ")
}
// The strip's icon collapse level for its widths with icons on every pill, with numbers on the
// inactive pills, and with numbers only, against the 40 % budget (bar.md §3).
function collapseLevel(widthFull, widthInactive, widthNone, maxWidth) {
    invariant(widthFull >= 0 && widthInactive >= 0 && widthNone >= 0 && maxWidth >= 0, "strip widths")
    if (widthFull <= maxWidth) return 0
    if (widthInactive <= maxWidth) return 1
    return 2
}
// The throttle after a title change at `now`, and how long to wait before showing it (0 = now).
function noteTitleChange(throttle, now) {
    invariant(throttle && Array.isArray(throttle.changes), "broken title throttle")
    var changes = throttle.changes.filter(function (t) { return now - t < 1000 })
    changes.push(now)
    return { changes: changes, shownAt: throttle.shownAt }
}
function titleDelay(throttle, now, rate, minInterval) {
    invariant(throttle && Array.isArray(throttle.changes), "broken title throttle")
    invariant(rate >= 1 && minInterval >= 0, "title throttle " + rate + "/" + minInterval)
    var recent = throttle.changes.filter(function (t) { return now - t < 1000 }).length
    if (recent <= rate) return 0
    return Math.max(0, throttle.shownAt + minInterval - now)
}
// The tray split: { shown: [item], overflow: [item] } (bar.tray.max, .hidden, .order by id).
function trayLayout(items, max, hidden, order) {
    invariant(max >= 0 && Math.floor(max) === max, "bar.tray.max " + max)
    invariant(Array.isArray(hidden) && Array.isArray(order), "tray settings are not lists")
    var visible = items.filter(function (i) { return (hidden || []).indexOf(i.id) < 0 })
    var o = order || []
    var ranked = visible.map(function (i, k) { var at = o.indexOf(i.id); return { i: i, r: at >= 0 ? at : o.length + k } })
    ranked.sort(function (a, b) { return a.r - b.r })
    var sorted = ranked.map(function (x) { return x.i })
    if (sorted.length <= max) return { shown: sorted, overflow: [] }
    return { shown: sorted.slice(0, max), overflow: sorted.slice(max) }
}
// The Deck args for a status item (deck.openPages: a page instead of the section).
function deckArgs(section, openPages) {
    invariant(typeof section === "string" && section !== "", "no Deck section")
    return openPages ? { page: section } : { section: section }
}
// "2 · zen, kitty" (number or name, then the apps).
function workspaceTooltip(record, appNames) {
    var head = record.name || String(record.id)
    return appNames.length > 0 ? head + " · " + appNames.join(", ") : head
}
// The state glyphs of a window record, in order.
function windowGlyphs(window) {
    var out = []
    if (!window) return out
    if (window.floating) out.push(WINDOW_GLYPHS.floating)
    if (window.pinned) out.push(WINDOW_GLYPHS.pinned)
    if (window.fullscreen) out.push(WINDOW_GLYPHS.fullscreen)
    return out
}
// The window menu rows (bar.md §4) for a window record; monitors: [name]; current monitor.
function windowMenu(window, monitors, monitor) {
    invariant(window && Array.isArray(monitors), "window menu without a window")
    var ws = []
    for (var i = 1; i <= 10; i++) ws.push({ id: "ws:" + i, label: String(i), enabled: window.workspace !== i })
    var others = monitors.filter(function (m) { return m !== monitor })
    var rows = [
        { id: "float", label: window.floating ? "Tile" : "Float", glyph: window.floating ? "grid_view" : "picture_in_picture" },
        { id: "pin", label: "Pin", glyph: "push_pin", checked: !!window.pinned, enabled: !!window.floating },
        { id: "fullscreen", label: "Fullscreen", glyph: "fullscreen", checked: !!window.fullscreen },
        { id: "workspace", label: "Move to workspace", submenu: ws },
        { id: "monitor", label: "Move to monitor", enabled: others.length > 0,
          submenu: others.map(function (m) { return { id: "mon:" + m, label: m } }) },
        { id: "scratch", label: "Send to scratch", glyph: "terminal" },
        { separator: true },
        { id: "close", label: "Close", glyph: "close", risk: true }
    ]
    checkMenu(rows)
    return rows
}
// The pill menu rows (bar.md §3) for a workspace record; monitors: [name]; current monitor.
function pillMenu(record, monitors, monitor) {
    // (a named workspace has a negative id too: `special` alone tells a special one)
    invariant(record && !record.special && Array.isArray(monitors), "pill menu of a special or no workspace")
    var others = monitors.filter(function (m) { return m !== monitor })
    var rows = [
        { id: "rename", label: "Rename…", glyph: "edit" },
        { id: "movehere", label: "Move focused window here" },
        { id: "monitor", label: "Move workspace to", enabled: others.length > 0,
          submenu: others.map(function (m) { return { id: "mon:" + m, label: m } }) },
        { separator: true },
        { id: "closeall", label: "Close all windows…", risk: true, enabled: record.windows > 0,
          confirm: "Close " + record.windows + (record.windows === 1 ? " window?" : " windows?") }
    ]
    checkMenu(rows)
    return rows
}
// The title's width (bar.md §2, §9): what is left between the zones, at most titleMaxWidth (240
// on a narrow monitor), 0 (hidden) below titleMinWidth. tokens: Tokens.surfaces.bar.
// Wheel steps from a wheel event's angleDelta.y (bar.md §3, §4, §6; 05 §4). High-resolution
// wheels, touchpads and TrackPoint scrolling send many small deltas: one step per WHEEL_UNIT (a
// classic wheel notch), the rest carried to the next event and dropped when the direction turns.
// → { steps: signed int (+ = up), carry }
var WHEEL_UNIT = 120
function wheelSteps(carry, delta) {
    var c = isFinite(carry) ? Number(carry) : 0, d = isFinite(delta) ? Number(delta) : 0
    if (c !== 0 && d !== 0 && (c > 0) !== (d > 0)) c = 0
    c += d
    var steps = c >= 0 ? Math.floor(c / WHEEL_UNIT) : -Math.floor(-c / WHEEL_UNIT)
    var r = { steps: steps, carry: c - steps * WHEEL_UNIT }
    invariant(Math.abs(r.carry) < WHEEL_UNIT && (r.steps === 0 || (r.steps > 0) === (d > 0)), "wheel steps " + r.steps + ", carry " + r.carry)
    return r
}
function titleWidth(available, narrow, tokens) {
    checkBarTokens(tokens)
    var w = Math.min(available, narrow ? tokens.narrowTitleMaxWidth : tokens.titleMaxWidth)
    return w < tokens.titleMinWidth ? 0 : w
}

function item(id, glyph, ink, overlay, extra, text, tooltip, section, quietKeeps) {
    return { id: id, glyph: glyph, ink: ink, overlay: overlay, extra: extra, text: text, tooltip: tooltip,
             section: section, quietKeeps: quietKeeps }
}
var PROFILE_LABELS = { "power-saver": "Power saver", "balanced": "Balanced", "performance": "Performance" }

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
