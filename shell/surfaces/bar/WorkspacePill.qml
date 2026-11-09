// One workspace pill (surfaces/bar.md §3): number or name, up to three app icons and "+n", the
// urgent dot with its nudge (M-36); the scratch pill is a pill with `scratch`.
pragma ComponentBehavior: Bound
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // The workspace record (hypr.js); for the scratch pill: { name, windows, shown }.
    property var workspace: ({})
    // The scratch pill (a `terminal` glyph, accent ring while shown).
    property bool scratch: false
    // Draw the app icons (bar.workspaces.icons and the strip's collapse level).
    property bool showIcons: true
    // M-01: this pill's share of the intro (0 → 1, staggered by the strip).
    property real appear: 1

    // The pointer is over the pill (wash, tooltip after 600 ms).
    readonly property bool hovered: false

    signal clicked()
    signal middleClicked()
    // A right click at a point in this pill's coordinates (the strip opens the menu there).
    signal rightClicked(real x, real y)
    // A wheel step: -1 previous, +1 next.
    signal wheelStep(int direction)

    // M-36: the nudge's scale and when it last ran (ms; at most once per nudge.minInterval).
    property real _nudge: 1
    property real _lastNudge: 0

    // One nudge (M-36), unless one ran within nudge.minInterval.
    function nudge(): void { throw new Error("not implemented"); }
}
