// The workspace strip (surfaces/bar.md §3): the overview button, one pill per workspace of this
// monitor, the accent capsule that slides between pills (M-02) and the scratch pill.
pragma ComponentBehavior: Bound
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // The Hyprland monitor name of this bar.
    property string monitorName: ""
    // This monitor's strip (hypr.js strip record: pills and scratch).
    property var strip: ({ pills: [], scratch: null })
    // bar.workspaces.icons.
    property bool showIcons: true
    // The most the strip may take (bar.md §3: 40 % of the bar's width).
    property real maxWidth: 0
    // 0 → 1 during the session intro (M-01: pills stagger in 30 ms apart).
    property real introProgress: 1

    // Icon collapse (bar.js collapseLevel): 0 icons on every pill, 1 numbers on the inactive
    // pills, 2 numbers only.
    // TODO(phase): bar.js collapseLevel of the pills' measured widths against maxWidth.
    readonly property int collapse: 0
    // M-14: the pills in strip coordinates, [{ workspace, x, y, width, height }] (Bar.pillRects
    // maps them to monitor coordinates).
    // TODO(phase): from the Repeater's pills (updated when they move or resize).
    readonly property var pillRects: []

    // The accent capsule's edges in strip coordinates (M-02: the leading edge leads, the trailing
    // edge follows 40 ms later).
    property real _capsuleLeft: 0
    property real _capsuleRight: 0
    // The active pill's index a moment ago (which edge leads).
    property int _lastActive: -1

    // A pill's actions (bar.md §3): go there; move the focused window there (stay); its menu at a
    // point in strip coordinates; the wheel steps to the previous / next used workspace.
    function _go(record: var): void { throw new Error("not implemented"); }
    function _moveHere(record: var): void { throw new Error("not implemented"); }
    function _menu(record: var, x: real, y: real): void { throw new Error("not implemented"); }
    // The pill menu's rows (bar.js pillMenu): Rename… opens the overview with the workspace for
    // its F2 rename (overview.md §5, S6: args { workspace, rename: true }; the bar never takes the
    // keyboard), Move focused window here, Move workspace to ▸, Close all windows… (confirmed).
    function _menuTriggered(record: var, row: var): void { throw new Error("not implemented"); }
    function _wheel(direction: int): void { throw new Error("not implemented"); }
    // Move the capsule to the active pill (M-02: the leading edge first).
    function _placeCapsule(): void { throw new Error("not implemented"); }

    // TODO(phase): the overview button (grid_view, overviewButtonSize; click opens the overview,
    //   tooltip "Overview  Super+Tab"); a click on the strip's background opens it too.
    // TODO(phase): a Repeater of WorkspacePill over strip.pills: appear staggered by
    //   workspaceStaggerMs from introProgress; showIcons = showIcons && (collapse 0, or 1 and the
    //   pill active); clicked → _go, middleClicked → _moveHere, rightClicked → _menu, wheelStep →
    //   _wheel; an urgent record that was not urgent → pill.nudge().
    // TODO(phase): the scratch pill (clicked → Hypr.toggleScratch); the accent capsule
    //   (spring.snappy, trail workspace.trailDelay); strip/active changes → _placeCapsule; wheel on
    //   the background → _wheel.

    // Found by the probe (phase 5):
    // The trailing edge's target and side (M-02: the far edge follows trailDelay after the near
    // one; set when the trail timer fires).
    property real _trailTo: 0
    property bool _trailIsLeft: false
}
