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
    // TODO(phase): notch.js bulgeSize("card", …): 420 × the activity's cardHeight (+ pager).
    readonly property real bulgeWidth: 0
    readonly property real bulgeHeight: 0
    // TODO(phase): a HoverHandler over the card.
    readonly property bool hovered: false

    // Tab / ←/→ / a pager dot picked another activity.
    signal picked(string activity)

    // Hand the card item what it may declare: monitorName, activity, pinned (the card contract
    // documented on Activity.card).
    function _setUp(item: var): void { throw new Error("not implemented"); }

    // TODO(phase): a Loader of the current activity's card (→ _setUp), PagerDots when more than
    //   one is live; Tab / ←/→ (notch.js pagerStep) → picked while pinned.

    // Found by the probe (phase 5):
    // The shown activity, whether the pager shows (more than one live activity) and the card's
    // size: 420 × the activity's cardHeight (+ the pager).
    // TODO(phase): activities.find(current); notch.js bulgeSize("card", …).
    readonly property var _activity: null
    readonly property bool _pager: false
    readonly property var _size: ({ width: 0, height: 0 })
    // Page one activity left or right (notch.js pagerStep), then `picked`.
    function _step(delta: int): void { throw new Error("not implemented"); }
}
