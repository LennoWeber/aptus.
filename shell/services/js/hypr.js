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
function fixedIds(monitorNames, monitor) { throw new Error("not implemented") }
// Workspace records from Hyprland's workspaces ([{ id, name, monitor, windows }]), the window
// records, monitors ([{ name, activeWorkspace }]), the focused monitor, the focus order
// (addresses, MRU), urgent addresses and workspace names (id → name).
function workspaceRecords(workspaces, windows, monitors, focusedMonitor, focusOrder, urgent, names, maxChars) { throw new Error("not implemented") }
// Distinct app classes on a workspace, most recently focused first.
function appsOf(windows, workspaceId, focusOrder) { throw new Error("not implemented") }
// The pill's label: the name (≤ maxChars, ellipsised) or the id.
function labelOf(id, name, maxChars) { throw new Error("not implemented") }
// One monitor's strip (mode: "used" | "fixed").
function stripFor(records, monitor, mode, monitorNames, specialOpen) { throw new Error("not implemented") }
// The previous / next used workspace id of a strip from `current` (wheel), or `current`.
function neighbour(strip, current, direction) { throw new Error("not implemented") }
// `windowtitlev2` data ("address,title") → { address: "0x…", title }.
function parseTitleEvent(data) { throw new Error("not implemented") }
// The window list with one title replaced, or null when the address is unknown (then refresh).
function patchTitle(windows, address, title) { throw new Error("not implemented") }
// The focus order with `address` first.
function bumpFocus(order, address) { throw new Error("not implemented") }
// An event's data split into `count` fields at the first count-1 commas (the last field keeps
// its commas: titles, layout names), e.g. `activespecialv2` "id,name,monitor", `screencast`
// "state,owner", `activelayout` "keyboard,layout".
function splitEvent(data, count) { throw new Error("not implemented") }
