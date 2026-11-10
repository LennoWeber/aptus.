pragma ComponentBehavior: Bound
// One content layer inside the notch's bulge (surfaces/notch.md §10): when the notch changes from
// one content to another the geometry retargets its spring while the old layer fades out over
// 110 ms and the new one fades in from 60 ms. Holds a toast, OSD, event, card or mode.
import QtQuick
import qs.core

Item {
    id: root

    // The layer record (notch.js): { uid, kind, key, entryId, activity, mode, leaving }.
    property var record: ({})
    // False once a newer layer replaced this one: it fades out, then the Notch drops it.
    property bool shown: true
    // A plain crossfade (an in-place update such as replaces_id, or reduced motion): no entrance
    // choreography of the content.
    property bool plain: false
    // What the content needs (set by the Notch): the monitor, the passive entry's payload (updated
    // in place: stack, replaces_id, OSD value), the Component of a mode or result card, the mode's
    // args, the live activities and whether the card is pinned (ActivityCard).
    property string monitorName: ""
    property var payload: ({})
    property Component component: null
    property var args: ({})
    property var activities: []
    property bool pinned: false

    // The size the content wants for the bulge.
    readonly property real bulgeWidth: content && content.bulgeWidth !== undefined ? content.bulgeWidth : 0
    readonly property real bulgeHeight: content && content.bulgeHeight !== undefined ? content.bulgeHeight : 0
    // The fade-out has finished (the Notch removes the layer).
    readonly property bool gone: !shown && _fade <= 0
    // The loaded content item.
    readonly property var content: loader.item

    // 0 → 1 fade (in after morphInDelayMs, out over morphOutMs) and the entrance rise.
    property real _fade: 0
    states: State {
        name: "in"
        when: root.shown
        PropertyChanges { root._fade: 1 }
    }
    transitions: [
        Transition {
            to: "in"
            SequentialAnimation {
                PauseAnimation { duration: root.plain || Motion.reduced ? 0 : Tokens.surfaces.notch.morphInDelayMs }
                NumberAnimation { target: root; property: "_fade"; duration: Motion.ms("fade", false); easing.bezierCurve: Motion.enter }
            }
        },
        Transition {
            from: "in"
            NumberAnimation { target: root; property: "_fade"; duration: Tokens.surfaces.notch.morphOutMs; easing.bezierCurve: Motion.exit }
        }
    ]
    opacity: _fade
    transform: Translate { y: root.plain || Motion.reduced || !root.shown ? 0 : Motion.contentRise * (1 - root._fade) }

    Component {
        id: toastComponent
        Toast {
            monitorName: root.monitorName
            payload: root.payload
            entrance: !root.plain
        }
    }
    Component { id: osdComponent; Osd { payload: root.payload } }
    Component { id: eventComponent; EventLine { payload: root.payload } }
    Component {
        id: cardComponent
        ActivityCard {
            monitorName: root.monitorName
            activities: root.activities
            current: root.record.activity || ""
            pinned: root.pinned
        }
    }
    Loader {
        id: loader
        anchors.fill: parent
        sourceComponent: {
            switch (root.record.kind) {
            case "toast": return toastComponent;
            case "osd": return osdComponent;
            case "event": return eventComponent;
            case "card": return cardComponent;
            case "result": case "mode": return root.component;
            default: return null;
            }
        }
        onLoaded: {
            const it = item as Item;
            if (root.record.kind !== "result" && root.record.kind !== "mode") return;
            if ("monitorName" in it) it.monitorName = root.monitorName;
            if ("payload" in it) it.payload = Qt.binding(() => root.payload);
            if ("args" in it) it.args = Qt.binding(() => root.args);
            if ("active" in it) it.active = Qt.binding(() => root.shown);
        }
    }
}
