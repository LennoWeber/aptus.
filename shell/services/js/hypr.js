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
