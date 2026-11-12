pragma ComponentBehavior: Bound
// The nudge (04 §M-36): one scale pulse to nudge.scale and back over nudge.duration, never with
// reduced motion and at most once per minInterval. The nudged item binds its scale to `scale`.
import QtQuick
import qs.core

QtObject {
    id: root

    // The least time between two nudges in ms (nudge.minInterval; 0 = every fire runs).
    property real minInterval: Motion.catalogueValue("nudge.minInterval")
    // The scale to show (1 at rest).
    property real scale: 1
    // When the last nudge ran (ms since the epoch, 0 = never).
    property real _last: 0

    // One nudge, unless motion is reduced or one ran within minInterval.
    function fire(): void {
        const now = Date.now();
        if (Motion.reduced || (_last > 0 && now - _last < minInterval)) return;
        _last = now;
        _anim.restart();
    }

    readonly property SequentialAnimation _anim: SequentialAnimation {
        StandardAnimation { target: root; property: "scale"; to: Motion.catalogueValue("nudge.scale"); duration: Motion.catalogueValue("nudge.duration") / 2 }
        StandardAnimation { target: root; property: "scale"; to: 1; duration: Motion.catalogueValue("nudge.duration") / 2 }
    }
}
