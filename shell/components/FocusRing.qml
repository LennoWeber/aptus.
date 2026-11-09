// FocusRing: The keyboard focus ring (03 §6.3): 2 px accent, 2 px outside the target, radius + 2; only after keyboard navigation.
// Place it as a child or sibling of the target (it anchors to it).
import QtQuick
import qs.core

Item {
    id: root

    property Item target: null
    property real targetRadius: 0
    property bool shown: false

    // Gap plus stroke: the ring's outer edge from the target's edge.
    readonly property real _out: Tokens.focusRingGap + Tokens.focusRingWidth

    anchors.fill: target
    anchors.margins: -_out
    opacity: shown && target !== null ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        StandardAnimation { duration: Motion.ms("hover", !root.shown) }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: Tokens.accent
        border.width: Tokens.focusRingWidth
        // concentric: the ring's inner edge has the target's radius + gap
        radius: root.targetRadius + root._out
    }
}
