pragma ComponentBehavior: Bound
import QtQuick
import qs.models
import qs.theme
import qs.components

// Content of the TimerTile. Compact: countdown with a play button; expanded: ring, presets and pomodoro.
Item {
    id: tile

    property bool expanded
    property var timerState

    readonly property bool running: timerState ? timerState.running : false
    readonly property int shown: timerState ? (timerState.remainingSec > 0 || running ? timerState.remainingSec : timerState.totalSec) : 0
    readonly property var presets: [
        { label: "5 min", sec: 300 }, { label: "10 min", sec: 600 }, { label: "15 min", sec: 900 },
        { label: "25 min", sec: 1500 }, { label: "45 min", sec: 2700 }, { label: "1 hour", sec: 3600 }
    ]

    Item {
        anchors.fill: parent
        visible: !tile.expanded

        Label {
            y: -4
            text: tile.timerState ? tile.timerState.format(tile.shown > 0 ? tile.shown : 300) : ""
            role: Enums.TextRole.Display
            tabularNumbers: true
            color: tile.shown > 0 ? Tokens.ink : Tokens.inkFaint
        }
        Label {
            anchors { left: parent.left; bottom: parent.bottom }
            text: !tile.timerState ? "" : tile.timerState.mode === Enums.TimerMode.Pomodoro && tile.shown > 0
                ? tile.timerState.phaseName + " " + tile.timerState.pomodoroRound + "/4" : (tile.shown > 0 ? "Timer" : "Ready for 5 min")
            color: tile.running ? Tokens.ok : Tokens.inkSoft
        }
        // Play and pause without opening the detail view.
        Item {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 44
            height: 44
            Rectangle {
                anchors.fill: parent
                radius: 22
                color: playArea.pressed ? Tokens.surfaceAlt : "transparent"
                border.width: 1
                border.color: playArea.containsMouse ? Tokens.inkFaint : Tokens.line
                Behavior on border.color { ColorAnimation { duration: Tokens.durFast } }
            }
            StatusGlyph {
                anchors.centerIn: parent
                width: 18
                height: 18
                kind: tile.running ? "pause" : "play"
            }
            MouseArea {
                id: playArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: tile.timerState.toggle()
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: tile.expanded

        // Left: ring with the countdown and the controls.
        Item {
            id: left
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: parent.width * 0.46

            Canvas {
                id: ring
                width: 230
                height: 230
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 6 }
                property real fraction: tile.timerState ? tile.timerState.progress : 0
                property color inkColor: Tokens.ink
                property color trackColor: Tokens.line
                onFractionChanged: requestPaint()
                onInkColorChanged: requestPaint()
                onTrackColorChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.lineWidth = 6
                    ctx.lineCap = "round"
                    ctx.strokeStyle = trackColor
                    ctx.beginPath(); ctx.arc(width / 2, height / 2, width / 2 - 6, 0, 2 * Math.PI); ctx.stroke()
                    if (fraction > 0.002) {
                        ctx.strokeStyle = inkColor
                        ctx.beginPath(); ctx.arc(width / 2, height / 2, width / 2 - 6, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * fraction); ctx.stroke()
                    }
                }
            }
            Column {
                anchors.centerIn: ring
                spacing: 2
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: tile.timerState ? tile.timerState.format(tile.shown) : ""
                    font.pixelSize: 44
                    font.weight: Font.Light
                    role: Enums.TextRole.Display
                    tabularNumbers: true
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: tile.timerState ? (tile.timerState.mode === Enums.TimerMode.Pomodoro ? tile.timerState.phaseName + ", round " + tile.timerState.pomodoroRound + " of 4" : "Timer") : ""
                    color: Tokens.inkSoft
                }
            }
            Row {
                anchors { horizontalCenter: parent.horizontalCenter; top: ring.bottom; topMargin: 14 }
                spacing: 8
                ActionButton {
                    text: tile.running ? "Pause" : (tile.timerState && tile.timerState.remainingSec > 0 ? "Resume" : "Start")
                    primary: true
                    onClicked: tile.timerState.toggle()
                }
                ActionButton {
                    text: "Reset"
                    active: tile.timerState ? (tile.timerState.running || tile.timerState.remainingSec > 0 || tile.timerState.totalSec > 0) : false
                    onClicked: tile.timerState.reset()
                }
            }
        }

        Rectangle {
            id: divider
            anchors { left: left.right; leftMargin: 12; top: parent.top; bottom: parent.bottom }
            width: 1
            color: Tokens.line
        }

        // Right: presets and the pomodoro.
        Column {
            anchors { left: divider.right; leftMargin: 24; top: parent.top; right: parent.right }
            spacing: 8

            Label { text: "Timer"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
            Grid {
                columns: 3
                spacing: 8
                Repeater {
                    model: tile.presets
                    delegate: ActionButton {
                        required property var modelData
                        text: modelData.label
                        onClicked: tile.timerState.startTimer(modelData.sec)
                    }
                }
            }

            Item { width: 1; height: 14 }
            Label { text: "Pomodoro"; role: Enums.TextRole.Bar; color: Tokens.inkFaint }
            Label {
                width: parent.width
                wrapMode: Text.Wrap
                color: Tokens.inkSoft
                text: tile.timerState ? Math.round(tile.timerState.workSec / 60) + " min focus, " + Math.round(tile.timerState.shortBreakSec / 60) + " min break, "
                    + Math.round(tile.timerState.longBreakSec / 60) + " min after four rounds." : ""
            }
            Row {
                spacing: 6
                Repeater {
                    model: 4
                    delegate: Rectangle {
                        required property int index
                        readonly property bool inPomodoro: tile.timerState && tile.timerState.mode === Enums.TimerMode.Pomodoro && tile.shown > 0
                        width: 10
                        height: 10
                        radius: 5
                        color: inPomodoro && index < tile.timerState.pomodoroRound ? Tokens.ink : "transparent"
                        border.width: 1
                        border.color: inPomodoro && index < tile.timerState.pomodoroRound ? Tokens.ink : Tokens.inkFaint
                    }
                }
            }
            ActionButton {
                text: "Start pomodoro"
                onClicked: tile.timerState.startPomodoro()
            }
        }
    }
}
