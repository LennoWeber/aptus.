// The card frame of an expanded activity (surfaces/notch.md §5, M-08): 420 wide, padding 12, the
// activity's own card content, and the pager (6 px dots) when more than one activity is live;
// Tab and ←/→ switch while the card has the keyboard (pinned).
pragma ComponentBehavior: Bound
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // The Hyprland monitor name.
    property string monitorName: ""
    // The live activities in pager order (Activity objects) and the one shown.
    property var activities: []
    property string current: ""
    // Opened by click: the card has the keyboard (Tab, ←/→, its buttons).
    property bool pinned: false

    // 420 × the activity's cardHeight (+ the pager).
    readonly property real bulgeWidth: 0
    readonly property real bulgeHeight: 0
    readonly property bool hovered: false

    // Tab / ←/→ / a pager dot picked another activity.
    signal picked(string activity)

    // Hand the card item what it may declare: monitorName, activity, pinned (the card contract
    // documented on Activity.card).
    function _setUp(item: var): void { throw new Error("not implemented"); }
}
