// One status item (surfaces/bar.md §6): a 16 px glyph (with the charging bolt or the VPN key),
// optional text, a tooltip; opens 0 → w and then fades its glyph in (M-04).
pragma ComponentBehavior: Bound
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // The status item record (bar.js).
    property var item: ({})
    // The item is wanted (M-04: width opens, then the glyph fades in; reverse to leave).
    property bool shown: true

    // TODO(phase): the MouseArea's containsMouse.
    readonly property bool hovered: false

    signal clicked()
    signal middleClicked()
    signal rightClicked(real x, real y)
    signal wheelStep(int direction)

    // M-04 progress: width 0 → 1, then the glyph 0 → 1.
    property real _open: 0
    property real _glyph: 0
    // M-36: the nudge's scale and when it last ran (ms; the battery item at critical, 04 §M-36).
    property real _nudge: 1
    property real _lastNudge: 0

    // One nudge (M-36), unless one ran within nudge.minInterval.
    function nudge(): void { throw new Error("not implemented"); }

    // TODO(phase): Glyph (ink by item.ink; bolt overlay; extra glyph; percentage text), Tooltip
    //   item.tooltip, width animated with M-04 by `shown`; MouseArea → the signals.

    // Found by the probe (phase 5):
    // The item's width with its label (the cluster's collapse measures it before hiding labels).
    // TODO(phase): the content row's implicitWidth.
    readonly property real _fullWidth: 0
}
