import QtQuick
import Quickshell
import qs.models
import qs.theme
import qs.components

// The island at rest, about 560 px wide: workspaces and window title on the left, time and date in the middle,
// weather, status icons and battery on the right. While music plays, a recording or a timer runs, the music or
// recording info replaces the window title and the weather.
Item {
    id: rest

    property var mediaState
    property var timerState
    property var captureState
    property var workspaces
    property string windowTitle
    property var audioState
    property var networkState
    property var bluetoothState
    property var batteryState
    property var nightLightState
    property var caffeineState
    property var focusState
    property var weatherState
    property bool mediaWings
    property bool showWorkspaces
    property bool showStatus
    property bool showWeather
    property string clockFormat
    property color ink
    property color inkSoft
    property bool monoClock
    property bool hasWings
    property bool playing
    property bool wingMedia
    property bool recording
    property bool timerRunning

    signal workspaceClicked(int workspaceId)

    // The wings stay a few seconds after a pause.
    Timer { id: afterPause; interval: 3000 }
    SystemClock { id: sys; precision: SystemClock.Minutes }
    readonly property var english: Qt.locale("en_GB")

    // "m:ss" for a time in seconds.
    function formatSeconds(sec: int): string {
        throw new Error("not implemented")
    }

    // The window title cut to a length that fits the left side (about 28 characters, with an ellipsis).
    function shortTitle(title: string): string {
        throw new Error("not implemented")
    }
}
