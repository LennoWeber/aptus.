import QtQuick
import qs.models
import qs.theme
import qs.components

// The notch at rest: the time in the middle, one wing on each side when there is something to show
// (cover and levels while music plays, a recording, a running timer).
Item {
    id: rest

    property var mediaState
    property var timerState
    property var captureState
    property bool mediaWings: true
    property string clockFormat: "24h"
    property color ink: Tokens.ink
    property color inkSoft: Tokens.inkSoft
    readonly property bool hasWings: wingMedia || recording || timerRunning
    readonly property real wingWidth: hasWings ? 78 : 0

    readonly property bool playing: mediaState ? mediaState.available && mediaState.playing : false
    // The wings stay a few seconds after a pause.
    readonly property bool wingMedia: mediaWings && (playing || afterPause.running)
    readonly property bool recording: captureState ? captureState.recording : false
    readonly property bool timerRunning: timerState ? timerState.running : false

    onPlayingChanged: if (!playing) afterPause.restart()
    Timer { id: afterPause; interval: 3000 }

    SystemClock { id: sys; precision: SystemClock.Minutes }
    readonly property var english: Qt.locale("en_GB")

    Label {
        anchors.centerIn: parent
        text: rest.english.toString(sys.date, rest.clockFormat === "12h" ? "h:mm AP" : "HH:mm")
        color: rest.ink
        role: Enums.TextRole.Bar
        font.weight: Font.Medium
        tabularNumbers: true
    }

    // Left wing: cover, recording dot or timer dot.
    Item {
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        width: 24
        height: 24
        opacity: rest.hasWings ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }

        Rectangle {
            visible: rest.wingMedia && !rest.recording
            anchors.fill: parent
            radius: 6
            color: Tokens.surfaceAlt
            clip: true
            Image {
                anchors.fill: parent
                source: rest.mediaState ? rest.mediaState.artUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
        Rectangle {
            visible: rest.recording || (!rest.wingMedia && rest.timerRunning)
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 4
            color: rest.recording ? Tokens.critical : rest.inkSoft
            SequentialAnimation on opacity {
                running: rest.recording
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.3; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.3; to: 1; duration: 900; easing.type: Easing.InOutSine }
            }
        }
    }

    // Right wing: recording time, timer, or the level bars.
    Item {
        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        width: 54
        height: 24
        opacity: rest.hasWings ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }

        Label {
            visible: rest.recording
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: rest.captureState ? Math.floor(rest.captureState.recordingSec / 60) + ":" + (rest.captureState.recordingSec % 60 < 10 ? "0" : "") + rest.captureState.recordingSec % 60 : ""
            role: Enums.TextRole.Bar
            tabularNumbers: true
            color: Tokens.critical
        }
        Label {
            visible: !rest.recording && rest.timerRunning
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: rest.timerState ? rest.timerState.format(rest.timerState.remainingSec) : ""
            role: Enums.TextRole.Bar
            tabularNumbers: true
            color: rest.ink
        }
        LevelBars {
            visible: !rest.recording && !rest.timerRunning && rest.wingMedia
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            running: rest.playing
            color: rest.ink
        }
    }
}
