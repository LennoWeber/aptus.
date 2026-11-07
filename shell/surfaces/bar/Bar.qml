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
}
