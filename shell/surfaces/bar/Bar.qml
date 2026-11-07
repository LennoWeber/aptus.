// The bar: the frame's top edge with workspaces, active window, tray and status cluster (surfaces/bar.md).
// Owner: S1 (static skeleton), S3 (contents).
import QtQuick
import qs.core

Item {
    id: root

    // TODO(phase): static skeleton: band height Tokens.barHeight, left/centre/right zones with
    //   padBar and gapBarZone, the centre kept clear for notchWidth; slides down with introProgress.
    // TODO(phase): M-31: slides up with the frame's hide under a fullscreen window (Frame.hide).

    property MonitorState monitor
    property real introProgress: 1
    // The notch's rest width; the left and right zones stay clear of it.
    property real notchWidth: 0
    // M-14: the workspace pills in monitor coordinates, [{ workspace, x, y, width, height }],
    // for the overview's shared-element morph.
    readonly property var pillRects: []

    // How far the frame is slid out under a fullscreen window (Frame.hide, M-31); the bar follows.
    property real hide: 0

    // Private state.
    // Content starts padBar from the frame edge (03 §7); the centre stays clear for the notch.
    readonly property real _inset: 0
    // Width of each side zone (left, right) around the notch.
    readonly property real _sideWidth: 0
}
