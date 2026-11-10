pragma ComponentBehavior: Bound
// One compact-activity slot beside the clock (surfaces/notch.md §4): it opens to the width of the
// activity's compact look (M-05, spring.notch) and reports the pointer: resting 300 ms opens the
// card transiently, leaving collapses it after 400 ms; click pins the card.
import QtQuick
import qs.core
import qs.components

Item {
    id: root

    // The Activity shown here, or null (the slot closes).
    property var activity: null
    // "left" | "right" (which side of the clock; the slot opens away from it).
    property string side: "left"
    // The Hyprland monitor name.
    property string monitorName: ""

    // The width the slot wants (the compact item's implicit width, 0 when empty).
    readonly property real openWidth: activity && loader.item ? (loader.item as Item).implicitWidth : 0
    readonly property bool hovered: mouse.containsMouse

    // The pointer rested activityHover.rest ms on the slot / left it.
    signal hoverRested()
    signal hoverLeft()
    signal clicked()
    signal middleClicked()
    signal rightClicked(real x, real y)

    // The slot's animated width (M-05).
    property real _width: openWidth
    Behavior on _width {
        SpringAnimation {
            spring: Motion.springs.notch.spring
            damping: Motion.springs.notch.damping
            mass: Motion.springs.notch.mass
            epsilon: Motion.springs.notch.epsilon
        }
    }

    implicitWidth: _width
    implicitHeight: Tokens.barHeight
    clip: _width < openWidth

    Loader {
        id: loader
        anchors.verticalCenter: parent.verticalCenter
        x: root.side === "left" ? root.width - width : 0
        sourceComponent: root.activity ? root.activity.compact : null
        opacity: root.openWidth > 0 ? Math.min(1, root._width / root.openWidth) : 0
        onLoaded: {
            if ("activity" in item) item.activity = Qt.binding(() => root.activity);
            if ("monitorName" in item) item.monitorName = Qt.binding(() => root.monitorName);
        }
    }
    // one pulse when the activity asks for it (pulseSerial)
    readonly property int _pulse: activity ? activity.pulseSerial : 0
    on_PulseChanged: if (_pulse > 0 && !Motion.reduced) pulseAnim.restart()
    SequentialAnimation {
        id: pulseAnim
        StandardAnimation { target: loader; property: "scale"; to: Motion.catalogueValue("nudge.scale"); duration: Motion.catalogueValue("nudge.duration") / 2 }
        StandardAnimation { target: loader; property: "scale"; to: 1; duration: Motion.catalogueValue("nudge.duration") / 2 }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onContainsMouseChanged: {
            if (containsMouse) { leaveTimer.stop(); restTimer.restart(); }
            else { restTimer.stop(); root.hoverLeft(); }
        }
        onClicked: m => {
            if (m.button === Qt.MiddleButton) root.middleClicked();
            else if (m.button === Qt.RightButton) root.rightClicked(m.x, m.y);
            else root.clicked();
        }
    }
    Timer {
        id: restTimer
        interval: Motion.catalogueMs("activityHover.rest", false)
        onTriggered: root.hoverRested()
    }
    Timer { id: leaveTimer }
}
