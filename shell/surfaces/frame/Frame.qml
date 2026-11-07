// The frame: the screen-edge band and every open drawer's bulge, painted as one shape (03 §6, 07 §4).
// Owner: S1.
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    property MonitorState monitor
    // The drawers' bulges (BulgeSpec), drawn as dents in the content area's outline.
    property list<BulgeSpec> bulges
    // 0 → 1 during the session intro (M-01): edges thicken, the bar slides down.
    property real introProgress: 1
    // A fullscreen window: frame and bar slide out (M-31) unless revealed by the hot edge.
    property bool hidden: false
    // The hot edge brought the bar back over the fullscreen window.
    property bool revealed: false
    // How far the frame is slid out (0 shown, 1 hidden), animated.
    property real hide: 0
}
