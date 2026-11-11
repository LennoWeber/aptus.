pragma ComponentBehavior: Bound
// One status item (surfaces/bar.md §6): a 16 px glyph (with the charging bolt or the VPN key),
// optional text, a tooltip; opens 0 → w and then fades its glyph in (M-04).
import QtQuick
import qs.core
import qs.components
import "js/bar.js" as B

Item {
    id: root

    // The status item record (bar.js).
    property var item: ({})
    // The item is wanted (M-04: width opens, then the glyph fades in; reverse to leave).
    property bool shown: true

    readonly property bool hovered: mouse.containsMouse

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
    // Found in review: the wheel's carried delta (bar.js wheelSteps: small deltas add up).
    property real _wheelCarry: 0

    // One nudge (M-36), unless one ran within nudge.minInterval.
    function nudge(): void {
        const now = Date.now();
        if (Motion.reduced || (_lastNudge > 0 && now - _lastNudge < Motion.catalogueValue("nudge.minInterval"))) return;
        _lastNudge = now;
        nudgeAnim.restart();
    }

    // Found by the probe (phase 5):
    // The item's width with its label (the cluster's collapse measures it before hiding labels).
    readonly property real _fullWidth: content.implicitWidth
    implicitWidth: _fullWidth * _open
    implicitHeight: Tokens.surfaces.bar.statusPillHeight
    clip: _open < 1

    states: State {
        name: "shown"
        when: root.shown
        PropertyChanges { root._open: 1; root._glyph: 1 }
    }
    transitions: [
        Transition {
            to: "shown"
            SequentialAnimation {
                StandardAnimation { target: root; property: "_open"; duration: Motion.ms("small", false) }
                StandardAnimation { target: root; property: "_glyph"; duration: Motion.ms("fade", false) }
            }
        },
        Transition {
            from: "shown"
            SequentialAnimation {
                StandardAnimation { target: root; property: "_glyph"; duration: Motion.ms("fade", true) }
                StandardAnimation { target: root; property: "_open"; duration: Motion.ms("small", true) }
            }
        }
    ]

    Row {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.s1
        opacity: root._glyph
        scale: root._nudge

        Item {
            width: Tokens.surfaces.bar.statusIconSize
            height: width
            anchors.verticalCenter: parent.verticalCenter
            Glyph {
                anchors.centerIn: parent
                name: root.item.glyph || ""
                size: Tokens.surfaces.bar.statusIconSize
                colour: ComponentShared.ink(root.item.ink || "main")
                active: root.hovered
            }
            Glyph {
                visible: (root.item.overlay || "") !== ""
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -Tokens.s1
                name: root.item.overlay || ""
                size: Tokens.surfaces.bar.statusOverlaySize
                on: true
                colour: ComponentShared.ink(root.item.ink || "main")
            }
        }
        Glyph {
            visible: (root.item.extra || "") !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: root.item.extra || ""
            size: Tokens.surfaces.bar.statusExtraSize
            colour: ComponentShared.ink("sec")
        }
        Label {
            visible: text !== ""
            anchors.verticalCenter: parent.verticalCenter
            type: "bar"
            tabular: true
            ink: root.item.ink === "main" ? "sec" : (root.item.ink || "sec")
            text: root.item.text || ""
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: e => {
            if (e.button === Qt.MiddleButton) root.middleClicked();
            else if (e.button === Qt.RightButton) root.rightClicked(e.x, e.y);
            else root.clicked();
        }
        onWheel: w => {
            const r = B.wheelSteps(root._wheelCarry, w.angleDelta.y);
            root._wheelCarry = r.carry;
            for (let i = 0; i < Math.abs(r.steps); i++) root.wheelStep(r.steps > 0 ? 1 : -1);
        }
    }
    // The tooltip's text follows the item only while the pointer is on it: the Wi-Fi strength
    // and the battery's time left change every few seconds, and a hidden tooltip's label would
    // redraw the whole layer each time (07 §12 idle wakeups).
    readonly property string _liveTip: item.tooltip || ""
    property string _tip: ""
    on_LiveTipChanged: if (hovered) _tip = _liveTip
    onHoveredChanged: if (hovered) _tip = _liveTip
    Tooltip {
        target: root
        text: root._tip
        active: root.hovered
    }
    SequentialAnimation {
        id: nudgeAnim
        StandardAnimation { target: root; property: "_nudge"; to: Motion.catalogueValue("nudge.scale"); duration: Motion.catalogueValue("nudge.duration") / 2 }
        StandardAnimation { target: root; property: "_nudge"; to: 1; duration: Motion.catalogueValue("nudge.duration") / 2 }
    }
}
