pragma ComponentBehavior: Bound
// The card frame of an expanded activity (surfaces/notch.md §5, M-08): 420 wide, padding 12, the
// activity's own card content, and the pager (6 px dots) when more than one activity is live;
// Tab and ←/→ switch while the card has the keyboard (pinned).
import QtQuick
import qs.core
import qs.components
import "js/notch.js" as NJ

Item {
    id: root

    // The Hyprland monitor name.
    property string monitorName: ""
    // The live activities in pager order (Activity objects) and the one shown.
    property var activities: []
    property string current: ""
    // Opened by click: the card has the keyboard (Tab, ←/→, its buttons).
    property bool pinned: false

    // Found by the probe (phase 5):
    // The shown activity, whether the pager shows (more than one live activity) and the card's
    // size: 420 × the activity's cardHeight (+ the pager).
    readonly property var _activity: activities.find(a => a.activity === current) || null
    readonly property bool _pager: activities.length > 1
    // 420 × the activity's cardHeight (+ the pager).
    readonly property var _size: NJ.bulgeSize("card", null, { height: _activity ? _activity.cardHeight : 0, pager: _pager }, Tokens.surfaces)
    // 420 × the activity's cardHeight (+ the pager).
    readonly property real bulgeWidth: _size.width
    readonly property real bulgeHeight: _size.height
    readonly property bool hovered: hover.hovered

    // Tab / ←/→ / a pager dot picked another activity.
    signal picked(string activity)

    // Hand the card item what it may declare: monitorName, activity, pinned (the card contract
    // documented on Activity.card).
    function _setUp(item: var): void {
        if (!item) return;
        if ("monitorName" in item) item.monitorName = Qt.binding(() => root.monitorName);
        if ("activity" in item) item.activity = Qt.binding(() => root._activity);
        if ("pinned" in item) item.pinned = Qt.binding(() => root.pinned);
    }
    // Page one activity left or right (notch.js pagerStep), then `picked`.
    function _step(delta: int): void {
        const id = NJ.pagerStep(activities.map(a => a.activity), current, delta);
        if (id !== "" && id !== current) picked(id);
    }

    focus: pinned
    Keys.onTabPressed: _step(1)
    Keys.onBacktabPressed: _step(-1)
    Keys.onLeftPressed: _step(-1)
    Keys.onRightPressed: _step(1)
    onPinnedChanged: if (pinned) forceActiveFocus()

    HoverHandler { id: hover }
    Loader {
        id: loader
        x: Tokens.surfaces.card.padding
        y: Tokens.surfaces.card.padding
        width: root.width - 2 * Tokens.surfaces.card.padding
        height: (root._activity ? root._activity.cardHeight : 0) - 2 * Tokens.surfaces.card.padding
        sourceComponent: root._activity ? root._activity.card : null
        onLoaded: root._setUp(item)
    }
    PagerDots {
        visible: root._pager
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.surfaces.card.padding / 2
        count: root.activities.length
        current: Math.max(0, root.activities.findIndex(a => a.activity === root.current))
        onPicked: i => root.picked(root.activities[i].activity)
    }
}
