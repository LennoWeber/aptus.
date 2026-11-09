// The bar: the frame's top edge with workspaces, active window, tray and status cluster (surfaces/bar.md).
// Owner: S1 (static skeleton), S3 (contents).
import QtQuick
import qs.core

Item {
    id: root

    property MonitorState monitor
    property real introProgress: 1
    // The notch's rest width; the left and right zones stay clear of it.
    property real notchWidth: 0
    // M-14: the workspace pills in monitor coordinates, [{ workspace, x, y, width, height }],
    // for the overview's shared-element morph.
    // TODO(phase): the strip's pillRects mapped to monitor coordinates.
    readonly property var pillRects: []
    // How far the frame is slid out under a fullscreen window (Frame.hide, M-31); the bar follows.
    property real hide: 0

    // Quiet bar (M-31b, Focus.quietBar): title, tray, date and non-critical status collapse.
    // TODO(phase): Focus.quietBar (the hover reveal is S8's: TODO(S8)).
    readonly property bool quiet: false
    // A monitor narrower than surfaces.bar.narrowMonitorWidth (bar.md §9): date hidden, title
    // ≤ 240, tray ≤ 2.
    // TODO(phase): width < Tokens.surfaces.bar.narrowMonitorWidth.
    readonly property bool narrow: false

    height: Tokens.barHeight
    // M-01 slides the bar down from above the screen; M-31 slides it up again.
    y: -Tokens.barHeight * (1 - introProgress) - Tokens.barHeight * hide
    opacity: 1 - hide

    // Content starts padBar from the frame edge (03 §7); the centre stays clear for the notch.
    readonly property real _inset: Tokens.frameEdge + Tokens.padBar
    // Width of each side zone (left, right) around the notch.
    readonly property real _sideWidth: Math.max(0, (width - notchWidth) / 2 - _inset - Tokens.gapBarZone)

    // Zones (S3 fills them: workspaces and window title left, tray and status right).
    // TODO(phase): left: WorkspaceStrip (monitorName, Hypr.stripFor(monitor.name), maxWidth =
    //   stripMaxWidthFraction of the bar, bar.workspaces.icons, introProgress).
    // TODO(phase): left: ActiveWindow while bar.title.show and not quiet: window = Hypr.activeWindow
    //   when it is on this monitor's active workspace, fallback = that workspace's name, maxWidth =
    //   bar.js titleWidth(the space left, narrow).
    // TODO(phase): right: StatusCluster (quiet), then Tray unless quiet: maxItems bar.tray.max
    //   (narrowTrayMax on a narrow monitor), hidden, order; shown = bar.tray.monitor "all", or this
    //   is the primary monitor (10-settings: the external one when connected, else eDP-1).
    Row {
        id: leftZone
        x: root._inset
        width: root._sideWidth
        height: parent.height
        spacing: Tokens.gapBarItem
        layoutDirection: Qt.LeftToRight
    }
    Row {
        id: rightZone
        x: root.width - root._inset - width
        width: root._sideWidth
        height: parent.height
        spacing: Tokens.gapBarItem
        layoutDirection: Qt.RightToLeft
    }
}
