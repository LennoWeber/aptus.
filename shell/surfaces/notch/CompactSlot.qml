// One compact-activity slot beside the clock (surfaces/notch.md §4): it opens to the width of the
// activity's compact look (M-05, spring.notch) and reports the pointer: resting 300 ms opens the
// card transiently, leaving collapses it after 400 ms; click pins the card.
pragma ComponentBehavior: Bound
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
    // TODO(phase): the compact item's implicitWidth (0 without an activity), cached per activity.
    readonly property real openWidth: 0
    // TODO(phase): the MouseArea's containsMouse.
    readonly property bool hovered: false

    // The pointer rested activityHover.rest ms on the slot / left it.
    signal hoverRested()
    signal hoverLeft()
    signal clicked()
    signal middleClicked()
    signal rightClicked(real x, real y)

    // The slot's animated width (M-05).
    property real _width: 0

    // TODO(phase): a Loader of activity.compact (sets activity, monitorName), width animated
    //   (M-05); hover 300 ms (activityHover) → hoverRested, exit → hoverLeft; click, middle,
    //   right → the signals; pulseSerial → one pulse.

    // Found by the probe (phase 5):
    // One pulse when the activity asks for it (its pulseSerial changes).
    // TODO(phase): activity ? activity.pulseSerial : 0.
    readonly property int _pulse: 0
}
