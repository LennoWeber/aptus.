import QtQuick
import qs.models
import qs.theme
import qs.components

// The island at rest: the time in the middle, one wing on each side when there is something to show
// (cover and levels while music plays, a recording, a running timer).
Item {
    id: rest

    property var mediaState
    property var timerState
    property var captureState
    property bool mediaWings
    property string clockFormat
    property color ink
    property color inkSoft
    property bool monoClock
    property bool hasWings
    property real wingWidth
    property bool playing
    property bool wingMedia
    property bool recording
    property bool timerRunning

    // "m:ss" for a time in seconds.
    function formatSeconds(sec: int): string {
        throw new Error("not implemented")
    }
}
