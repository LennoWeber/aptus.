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
    // TODO(phase): a name Hyprland lists twice counts once (its data is taken as it comes).
    throw new Error("not implemented")
}
// Workspace records from Hyprland's workspaces ([{ id, name, monitor, windows }]), the window
// records, monitors ([{ name, activeWorkspace }]), the focused monitor, the focus order
// (addresses, MRU), urgent addresses and workspace names (id → name).
function workspaceRecords(workspaces, windows, monitors, focusedMonitor, focusOrder, urgent, names, maxChars) {
    invariant(maxChars >= 2, "name limit " + maxChars)
    invariant(unique(focusOrder), "an address twice in the focus order")
    // TODO(phase): a later workspace with an id already seen is dropped (Quickshell's lists hold
    //   a placeholder for a moment); special = the name is "special" or starts with "special:"
    //   (named workspaces have negative ids too, from −1337 down); each id once in the result.
    throw new Error("not implemented")
}
// Distinct app classes on a workspace, most recently focused first (workspaceRecords checks the
// focus order once for all its workspaces).
function appsOf(windows, workspaceId, focusOrder) { throw new Error("not implemented") }
// The pill's label: the name (≤ maxChars, ellipsised) or the id.
function labelOf(id, name, maxChars) {
    invariant(maxChars >= 2, "name limit " + maxChars)
    throw new Error("not implemented")
}
// One monitor's strip (mode: "used" | "fixed").
function stripFor(records, monitor, mode, monitorNames, specialOpen) {
    invariant(mode === "used" || mode === "fixed", "strip mode " + mode)
    invariant(unique(records.map(function (r) { return r.id })), "a workspace record twice")
    // TODO(phase): checkStrip(result).
    throw new Error("not implemented")
}
// The previous / next used workspace id of a strip from `current` (wheel), or `current`.
function neighbour(strip, current, direction) {
    invariant(direction === 1 || direction === -1, "wheel direction " + direction)
    throw new Error("not implemented")
}
// `windowtitlev2` data ("address,title") → { address: "0x…", title }.
function parseTitleEvent(data) {
    invariant(typeof data === "string", "event data is not a string")
    throw new Error("not implemented")
}
// The window list with one title replaced, or null when the address is unknown (then refresh).
// Hypr._onTitle skips an event whose address is not one (isAddress) before it calls this.
function patchTitle(windows, address, title) {
    invariant(isAddress(address), "address " + address)
    throw new Error("not implemented")
}
// The focus order with `address` first.
function bumpFocus(order, address) {
    invariant(unique(order), "an address twice in the focus order")
    invariant(isAddress(address), "address " + address)
    throw new Error("not implemented")
}
// An event's data split into `count` fields at the first count-1 commas (the last field keeps
// its commas: titles, layout names), e.g. `activespecialv2` "id,name,monitor", `screencast`
// "state,owner", `activelayout` "keyboard,layout".
function splitEvent(data, count) {
    invariant(typeof data === "string", "event data is not a string")
    invariant(count >= 1 && Math.floor(count) === count, "field count " + count)
    throw new Error("not implemented")
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
