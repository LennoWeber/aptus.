// Badge: Badge (03 §9): a 6 px dot, or a pill with a count.
// It pops in on the snappy spring when it appears (M-35).
import QtQuick
import qs.core

Item {
    id: root

    // -1: a dot; ≥ 0: a count pill.
    property int count: -1
    property color colour

    readonly property bool _dot: count < 0
    property real _pop: 1

    implicitHeight: _dot ? Tokens.badge.dot : Tokens.badge.pillHeight
    implicitWidth: _dot ? Tokens.badge.dot : Math.max(implicitHeight, label.implicitWidth + 2 * Tokens.s2)
    scale: _pop
    Accessible.role: Accessible.StaticText
    Accessible.name: _dot ? "Unread" : String(count)

    onVisibleChanged: if (visible) _popIn()
    Component.onCompleted: _popIn()
    function _popIn(): void {
        if (Motion.reduced) return;
        _pop = 0;
        pop.restart();
    }

    SpringAnimation {
        id: pop
        target: root
        property: "_pop"
        to: 1
        spring: Motion.snappySpring
        damping: Motion.snappyDamping
        mass: Motion.snappyMass
        // _pop is a scale (0..1): the pixel epsilon of the token, relative to the badge size
        epsilon: Motion.snappyEpsilon / Math.max(1, root.implicitWidth)
    }
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.colour.valid ? root.colour : Tokens.accent
    }
    Label {
        id: label
        anchors.centerIn: parent
        visible: !root._dot
        text: root.count > 99 ? "99+" : String(Math.max(0, root.count))
        type: "micro"
        ink: "onAccent"
        tabular: true
    }
}
