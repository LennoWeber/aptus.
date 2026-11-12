pragma ComponentBehavior: Bound
// One status item (surfaces/bar.md §6): a 16 px glyph (with the charging bolt or the VPN key),
// optional text, a tooltip; opens 0 → w and then fades its glyph in (M-04).
import QtQuick
import qs.core
import qs.components

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
    // M-36: the nudge (the battery item at critical, 04 §M-36; at most once per nudge.minInterval).
    readonly property Nudge _nudge: Nudge {}
    // Found in review: the wheel's carried delta (small deltas add up).
    readonly property WheelStepper _wheel: WheelStepper {}

    // One nudge (M-36), unless one ran within nudge.minInterval.
    function nudge(): void { _nudge.fire(); }

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
        scale: root._nudge.scale

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
            const steps = root._wheel.feed(w.angleDelta.y);
            for (let i = 0; i < Math.abs(steps); i++) root.wheelStep(steps > 0 ? 1 : -1);
        }
    }
    Tooltip {
        target: root
        text: root.item.tooltip || ""
        active: root.hovered
    }
}
