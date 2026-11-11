.pragma library
// The workspace model of surfaces/bar.md §3 and §8 from Hyprland's plain records. Hypr.qml feeds
// it Hyprland's workspaces, windows and monitors; the bar draws what comes out.
//
// A window record (Hypr.windows, from a toplevel's lastIpcObject; the title is patched from
// `windowtitlev2` events without a refresh):
//   { address, class, title, monitor, workspace: int, x, y, width, height, floating, pinned,
//     fullscreen, hidden, focusHistoryId }
//
// A workspace record (Hypr.workspaces):
//   { id: int, name: string ("" when it has none: a name equal to its id is no name),
//     label: string (the name, else the id; ≤ bar.workspaceNameMaxChars), monitor: string,
//     windows: int, apps: [class] (distinct, most recently focused first), urgent: bool,
//     special: bool, active: bool (shown on its monitor), focused: bool (active on the focused
//     monitor) }
//
// A strip (one monitor's pills, bar.workspaces.show):
//   { pills: [workspace record, also empty ones in `fixed` mode or when active], scratch: null |
//     { name, windows, shown: bool } }
//
// The `fixed` assignment follows `auto-workspace-monitors.sh` (05 §7) exactly: without an
// external monitor eDP-1 holds 1–10; otherwise the first monitor Hyprland lists that is not
// eDP-1 holds 1–5 and eDP-1 6–10. Any further monitor has no fixed ids and shows `used`.

// The internal monitor of `auto-workspace-monitors.sh`.
var INTERNAL = "eDP-1"
// The scratch workspace (09: `special:scratch`).
var SCRATCH = "special:scratch"

// The fixed workspace ids of `monitor` given every monitor name in Hyprland's order ([] = none).
function fixedIds(monitorNames, monitor) {
    invariant(Array.isArray(monitorNames), "monitor names " + monitorNames)
    var external = ""
    for (var i = 0; i < monitorNames.length; i++) if (monitorNames[i] !== INTERNAL) { external = monitorNames[i]; break }
    var range = function (a, b) { var r = []; for (var k = a; k <= b; k++) r.push(k); return r }
    if (external === "") return monitor === INTERNAL ? range(1, 10) : []
    if (monitor === external) return range(1, 5)
    if (monitor === INTERNAL) return range(6, 10)
    return []
}
// Workspace records from Hyprland's workspaces ([{ id, name, monitor, windows }]), the window
// records, monitors ([{ name, activeWorkspace }]), the focused monitor, the focus order
// (addresses, MRU), urgent addresses and workspace names (id → name).
function workspaceRecords(workspaces, windows, monitors, focusedMonitor, focusOrder, urgent, names, maxChars) {
    invariant(maxChars >= 2, "name limit " + maxChars)
    invariant(unique(focusOrder), "an address twice in the focus order")
    var shown = {}
    for (var i = 0; i < monitors.length; i++) shown[monitors[i].activeWorkspace] = monitors[i].name
    var urgentWs = {}
    for (var j = 0; j < windows.length; j++) if (urgent.indexOf(windows[j].address) >= 0) urgentWs[windows[j].workspace] = true
    var out = [], seen = {}
    for (var k = 0; k < workspaces.length; k++) {
        var w = workspaces[k]
        if (seen[w.id]) continue                         // a placeholder of an id already listed
        seen[w.id] = true
        var wn = String(w.name)
        var special = wn === "special" || wn.indexOf("special:") === 0   // named ones are negative too
        var raw = names && names[w.id] !== undefined ? names[w.id] : (special || String(w.name) === String(w.id) ? "" : w.name)
        var name = special ? String(w.name) : String(raw || "")
        var count = 0
        for (var m = 0; m < windows.length; m++) if (windows[m].workspace === w.id) count++
        out.push({ id: w.id, name: name, label: special ? name : labelOf(w.id, name, maxChars), monitor: w.monitor,
                   windows: count, apps: appsOf(windows, w.id, focusOrder), urgent: !!urgentWs[w.id],
                   special: special, active: shown[w.id] === w.monitor && shown[w.id] !== undefined,
                   focused: shown[w.id] === w.monitor && w.monitor === focusedMonitor })
    }
    out.sort(function (a, b) { return a.special !== b.special ? (a.special ? 1 : -1) : a.id - b.id })
    invariant(unique(out.map(function (r) { return r.id })), "a workspace record twice")
    return out
}
// Distinct app classes on a workspace, most recently focused first (workspaceRecords checks the
// focus order once for all its workspaces).
function appsOf(windows, workspaceId, focusOrder) {
    var on = windows.filter(function (w) { return w.workspace === workspaceId })
    on.sort(function (a, b) {
        var ia = focusOrder.indexOf(a.address), ib = focusOrder.indexOf(b.address)
        if (ia < 0) ia = 1e9 + (a.focusHistoryId || 0)
        if (ib < 0) ib = 1e9 + (b.focusHistoryId || 0)
        return ia - ib
    })
    var apps = []
    for (var i = 0; i < on.length; i++) if (on[i]["class"] && apps.indexOf(on[i]["class"]) < 0) apps.push(on[i]["class"])
    return apps
}
// The pill's label: the name (≤ maxChars, ellipsised) or the id.
function labelOf(id, name, maxChars) {
    invariant(maxChars >= 2, "name limit " + maxChars)
    if (!name) return String(id)
    return name.length > maxChars ? name.substring(0, maxChars - 1) + "…" : name
}
// One monitor's strip (mode: "used" | "fixed").
function stripFor(records, monitor, mode, monitorNames, specialOpen) {
    invariant(mode === "used" || mode === "fixed", "strip mode " + mode)
    invariant(unique(records.map(function (r) { return r.id })), "a workspace record twice")
    var mine = records.filter(function (r) { return !r.special && r.monitor === monitor })
    var pills = []
    var fixed = mode === "fixed" ? fixedIds(monitorNames, monitor) : []
    if (fixed.length > 0) {
        var byId = {}
        for (var i = 0; i < records.length; i++) if (!records[i].special) byId[records[i].id] = records[i]
        for (var j = 0; j < fixed.length; j++) {
            var r = byId[fixed[j]]
            pills.push(r && r.monitor === monitor ? r : { id: fixed[j], name: "", label: String(fixed[j]), monitor: monitor,
                       windows: 0, apps: [], urgent: false, special: false, active: false, focused: false })
        }
        for (var k = 0; k < mine.length; k++) if (fixed.indexOf(mine[k].id) < 0 && (mine[k].windows > 0 || mine[k].active)) pills.push(mine[k])
    } else {
        for (var m = 0; m < mine.length; m++) if (mine[m].windows > 0 || mine[m].active) pills.push(mine[m])
    }
    pills.sort(function (a, b) { return a.id - b.id })
    var scratch = null
    for (var n = 0; n < records.length; n++) {
        if (records[n].special && records[n].name === SCRATCH && records[n].windows > 0)
            scratch = { name: SCRATCH, windows: records[n].windows, shown: (specialOpen || {})[monitor] === SCRATCH }
    }
    var strip = { pills: pills, scratch: scratch }
    checkStrip(strip)
    return strip
}
// The previous / next used workspace id of a strip from `current` (wheel), or `current`.
function neighbour(strip, current, direction) {
    invariant(direction === 1 || direction === -1, "wheel direction " + direction)
    var ids = strip.pills.filter(function (p) { return p.windows > 0 }).map(function (p) { return p.id })
    ids.sort(function (a, b) { return a - b })
    if (direction > 0) {
        for (var i = 0; i < ids.length; i++) if (ids[i] > current) return ids[i]
    } else {
        for (var j = ids.length - 1; j >= 0; j--) if (ids[j] < current) return ids[j]
    }
    return current
}
// `windowtitlev2` data ("address,title") → { address: "0x…", title }.
function parseTitleEvent(data) {
    invariant(typeof data === "string", "event data is not a string")
    var p = splitEvent(data, 2)
    var a = p[0]
    return { address: a.indexOf("0x") === 0 ? a : "0x" + a, title: p[1] }
}
// The window list with one title replaced, or null when the address is unknown (then refresh).
// Hypr._onTitle skips an event whose address is not one (isAddress) before it calls this.
function patchTitle(windows, address, title) {
    invariant(isAddress(address), "address " + address)
    for (var i = 0; i < windows.length; i++) {
        if (windows[i].address !== address) continue
        var out = windows.slice(), w = {}
        for (var k in windows[i]) w[k] = windows[i][k]
        w.title = title
        out[i] = w
        return out
    }
    return null
}
// The focus order with `address` first.
function bumpFocus(order, address) {
    invariant(unique(order), "an address twice in the focus order")
    invariant(isAddress(address), "address " + address)
    if (!address) return order
    var out = [address]
    for (var i = 0; i < order.length && out.length < 200; i++) if (order[i] !== address) out.push(order[i])
    return out
}
// An event's data split into `count` fields at the first count-1 commas (the last field keeps
// its commas: titles, layout names), e.g. `activespecialv2` "id,name,monitor", `screencast`
// "state,owner", `activelayout` "keyboard,layout".
function splitEvent(data, count) {
    invariant(typeof data === "string", "event data is not a string")
    invariant(count >= 1 && Math.floor(count) === count, "field count " + count)
    var s = String(data || ""), out = []
    for (var i = 0; i < count - 1; i++) {
        var c = s.indexOf(",")
        if (c < 0) { out.push(s); s = ""; continue }
        out.push(s.substring(0, c))
        s = s.substring(c + 1)
    }
    out.push(s)
    return out
}

// Invariants (phase 6): they throw "hypr invariant: …". Hyprland's own data is taken as it comes
// (ids and names unique); what is checked is the model's own state and the callers' arguments.
function invariant(cond, message) { if (!cond) throw new Error("hypr invariant: " + message) }
function unique(list) {
    for (var i = 0; i < list.length; i++) if (list.indexOf(list[i]) !== i) return false
    return true
}
// A window address as Hyprland writes it ("0x" and hex digits; never the bare "0x" of an empty
// `activewindowv2`).
function isAddress(a) { return typeof a === "string" && /^0x[0-9a-fA-F]+$/.test(a) }
// A strip: its pills unique and in id order, the active one among them, a scratch pill only for
// the scratch workspace.
function checkStrip(strip) {
    var ids = strip.pills.map(function (p) { return p.id })
    invariant(unique(ids), "a pill twice")
    invariant(ids.every(function (id, i) { return i === 0 || ids[i - 1] < id }), "pills out of order")
    invariant(strip.pills.filter(function (p) { return p.active }).length <= 1, "two active pills")
    invariant(strip.pills.every(function (p) { return !p.special }), "a special workspace as a pill")
}
