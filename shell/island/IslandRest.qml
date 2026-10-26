pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.models
import qs.theme
import qs.components

// The island at rest. What it shows depends on the design (setting island.design):
//   capsule  workspaces and window title on the left, time and date in the middle, weather, status and battery on the right (560 px)
//   pill     a floating pill: workspace pips, time, day and date, music wings; as wide as its content
//   ticker   workspaces, one line that rolls through time, weather, music or window, battery; status icons
//   shade    nothing but a line (the body itself)
// While music plays or a recording runs, it takes the place of the window title.
Item {
    id: rest

    property string design: "capsule"
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
    property bool showWorkspaces: true
    property string workspaceStyle  // bar.workspaceStyle: numbers, dots or bubbles
    property color inkOn            // for the number inside the active bubble
    property bool showStatus: true
    property bool showWeather: true
    property string clockFormat
    property color ink
    property color inkSoft
    property bool monoClock

    property bool playing: mediaState ? mediaState.available && mediaState.playing : false
    // The wings stay a few seconds after a pause.
    property bool wingMedia: mediaWings && (playing || afterPause.running)
    property bool recording: captureState ? captureState.recording : false
    property bool timerRunning: timerState ? timerState.running : false
    property bool hasWings: wingMedia || recording || timerRunning

    // Width the design wants at rest.
    readonly property real wantedWidth: {
        switch (design) {
        case "pill": return Math.max(316, Math.ceil(2 * pillSide + pillClock.implicitWidth + 64))
        case "ticker": return 440
        case "shade": return 120
        default: return 560
        }
    }
    readonly property real pillSide: Math.max(pillLeft.implicitWidth, pillRight.implicitWidth)

    signal workspaceClicked(int workspaceId)

    onPlayingChanged: if (!playing) afterPause.restart()
    Timer { id: afterPause; interval: 3000 }
    SystemClock { id: sys; precision: SystemClock.Minutes }
    readonly property var english: Qt.locale("en_GB")
    readonly property string timeText: english.toString(sys.date, clockFormat === "12h" ? "h:mm AP" : "HH:mm")
    readonly property string dateText: english.toString(sys.date, "ddd d MMM")

    // "m:ss" for a time in seconds.
    function formatSeconds(sec: int): string {
        return Math.floor(sec / 60) + ":" + (sec % 60 < 10 ? "0" : "") + sec % 60
    }

    // The window title cut to a length that fits the left side (about 28 characters, with an ellipsis).
    function shortTitle(title: string): string {
        return title.length > 28 ? title.slice(0, 27) + "…" : title
    }

    // The line next to the workspaces: what is recording or playing, else the window title.
    readonly property string leftText: {
        if (recording && captureState) return "Recording " + formatSeconds(captureState.recordingSec)
        if (wingMedia && mediaState && mediaState.title !== "") return shortTitle(mediaState.title)
        return shortTitle(windowTitle || "")
    }

    // ---- shared pieces -------------------------------------------------------------------------------------------

    component Status: Row {
        spacing: 8
        StatusGlyph { visible: rest.caffeineState ? rest.caffeineState.active : false; kind: "cup"; color: Tokens.ok; anchors.verticalCenter: parent.verticalCenter }
        StatusGlyph { visible: rest.focusState ? rest.focusState.active : false; kind: "focus"; color: Tokens.ok; anchors.verticalCenter: parent.verticalCenter }
        StatusGlyph { visible: rest.nightLightState ? rest.nightLightState.enabled : false; kind: "moon"; color: rest.ink; anchors.verticalCenter: parent.verticalCenter }
        StatusGlyph { visible: rest.bluetoothState ? rest.bluetoothState.powered : false; kind: "bluetooth"; color: rest.ink; anchors.verticalCenter: parent.verticalCenter }
        StatusGlyph { kind: "wifi"; color: rest.ink; opacity: rest.networkState && rest.networkState.connected ? 1 : 0.4; anchors.verticalCenter: parent.verticalCenter }
        StatusGlyph { kind: "volume"; color: rest.ink; opacity: rest.audioState && rest.audioState.muted ? 0.4 : 1; anchors.verticalCenter: parent.verticalCenter }
        Label {
            visible: rest.batteryState ? rest.batteryState.present : false
            anchors.verticalCenter: parent.verticalCenter
            text: rest.batteryState ? Math.round(rest.batteryState.percent) + "%" : ""
            role: Enums.TextRole.Bar
            tabularNumbers: true
            color: rest.batteryState && rest.batteryState.severity !== Enums.Severity.Neutral ? Tokens.colorFor(rest.batteryState.severity) : rest.ink
        }
    }

    component Cover: Rectangle {
        width: 22
        height: 22
        radius: 6
        color: Qt.rgba(rest.ink.r, rest.ink.g, rest.ink.b, 0.12)
        clip: true
        Image {
            anchors.fill: parent
            source: rest.mediaState ? rest.mediaState.artUrl : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    component RecDot: Rectangle {
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

    // The workspace numbers (style numbers and dots).
    component WorkspaceLabels: Row {
        Repeater {
            model: rest.workspaces
            delegate: Item {
                id: cell
                required property var modelData
                width: 22
                height: 28
                Label {
                    anchors.centerIn: parent
                    text: cell.modelData.name
                    role: Enums.TextRole.Bar
                    color: cell.modelData.urgent ? Tokens.warn : rest.ink
                    opacity: cell.modelData.active ? 1 : cell.modelData.occupied ? 0.7 : 0.4
                    font.weight: cell.modelData.active ? Font.DemiBold : Font.Normal
                }
                Rectangle {
                    visible: cell.modelData.active
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 2 }
                    width: 10
                    height: 2
                    radius: 1
                    color: rest.ink
                }
                MouseArea { anchors.fill: parent; onClicked: rest.workspaceClicked(cell.modelData.id) }
            }
        }
    }

    // The workspaces: bubbles, or the numbers (bar.workspaceStyle).
    component WorkspaceNumbers: Item {
        implicitWidth: rest.workspaceStyle === "numbers" ? labels.implicitWidth : bubbles.implicitWidth
        implicitHeight: 28
        WorkspaceLabels { id: labels; visible: rest.workspaceStyle === "numbers" }
        WorkspaceBubbles {
            id: bubbles
            visible: rest.workspaceStyle !== "numbers"
            numbered: rest.workspaceStyle === "bubbles"
            workspaces: rest.workspaces
            ink: rest.ink
            inkSoft: rest.inkSoft
            inkOn: rest.inkOn
            cellHeight: 28
            onWorkspaceClicked: id => rest.workspaceClicked(id)
        }
    }

    // ---- capsule -------------------------------------------------------------------------------------------------

    Item {
        visible: rest.design === "capsule"
        anchors.fill: parent

        Row {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 8
            WorkspaceNumbers { visible: rest.showWorkspaces; anchors.verticalCenter: parent.verticalCenter }
            Cover { visible: rest.wingMedia && !rest.recording; anchors.verticalCenter: parent.verticalCenter }
            RecDot { visible: rest.recording || (!rest.wingMedia && rest.timerRunning); anchors.verticalCenter: parent.verticalCenter }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: rest.leftText
                role: Enums.TextRole.Bar
                color: rest.inkSoft
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 170)
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 8
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: rest.timeText
                color: rest.ink
                role: rest.monoClock ? Enums.TextRole.Mono : Enums.TextRole.Bar
                font.pixelSize: Tokens.sizeBar
                font.weight: Font.Medium
                tabularNumbers: true
            }
            Label {
                visible: rest.showWeather
                anchors.verticalCenter: parent.verticalCenter
                text: rest.dateText
                role: Enums.TextRole.Bar
                color: rest.inkSoft
            }
        }

        Row {
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 10
            Label {
                visible: rest.showWeather && rest.weatherState && rest.weatherState.loaded && !rest.timerRunning
                anchors.verticalCenter: parent.verticalCenter
                text: rest.weatherState ? Math.round(rest.weatherState.temperatureC) + "°" : ""
                role: Enums.TextRole.Bar
                color: rest.inkSoft
                tabularNumbers: true
            }
            Label {
                visible: rest.timerRunning && !rest.recording
                anchors.verticalCenter: parent.verticalCenter
                text: rest.timerState ? rest.timerState.format(rest.timerState.remainingSec) : ""
                role: Enums.TextRole.Bar
                tabularNumbers: true
                color: rest.ink
            }
            LevelBars { visible: rest.wingMedia && !rest.recording && !rest.timerRunning; anchors.verticalCenter: parent.verticalCenter; running: rest.playing; color: rest.ink }
            Status { visible: rest.showStatus; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // ---- pill  ---------------------------------------------------------------------------------------------------

    Item {
        visible: rest.design === "pill"
        anchors.fill: parent

        // Workspace pips: the active one is a long pill.
        Row {
            id: pillLeft
            anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
            spacing: 5
            Repeater {
                model: rest.workspaces
                delegate: Item {
                    id: pip
                    required property var modelData
                    width: pipDot.width
                    height: 24
                    Rectangle {
                        id: pipDot
                        anchors.verticalCenter: parent.verticalCenter
                        width: pip.modelData.active ? 18 : 6
                        height: 6
                        radius: 3
                        color: pip.modelData.urgent ? Tokens.warn : rest.ink
                        opacity: pip.modelData.active ? 1 : pip.modelData.occupied ? 0.55 : 0.22
                        Behavior on width { NumberAnimation { duration: Tokens.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
                        Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                    }
                    MouseArea { anchors.fill: parent; anchors.margins: -3; onClicked: rest.workspaceClicked(pip.modelData.id) }
                }
            }
        }

        Label {
            id: pillClock
            anchors.centerIn: parent
            text: rest.timeText
            color: rest.ink
            role: rest.monoClock ? Enums.TextRole.Mono : Enums.TextRole.Bar
            font.pixelSize: Tokens.sizeBar + 1
            font.weight: Font.DemiBold
            tabularNumbers: true
        }

        Row {
            id: pillRight
            anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
            spacing: 8
            Cover { visible: rest.wingMedia && !rest.recording; anchors.verticalCenter: parent.verticalCenter }
            LevelBars { visible: rest.wingMedia && !rest.recording; anchors.verticalCenter: parent.verticalCenter; running: rest.playing; color: rest.ink }
            RecDot { visible: rest.recording || (!rest.wingMedia && rest.timerRunning); anchors.verticalCenter: parent.verticalCenter }
            Label {
                visible: rest.recording || (!rest.wingMedia && rest.timerRunning)
                anchors.verticalCenter: parent.verticalCenter
                text: rest.recording && rest.captureState ? rest.formatSeconds(rest.captureState.recordingSec) : rest.timerState ? rest.timerState.format(rest.timerState.remainingSec) : ""
                role: Enums.TextRole.Bar
                tabularNumbers: true
                color: rest.recording ? Tokens.critical : rest.ink
            }
            Label {
                visible: !rest.hasWings
                anchors.verticalCenter: parent.verticalCenter
                text: rest.dateText.toUpperCase()
                role: Enums.TextRole.Bar
                color: rest.inkSoft
            }
        }
    }

    // ---- ticker --------------------------------------------------------------------------------------------------

    Item {
        id: tickerBox
        visible: rest.design === "ticker"
        anchors.fill: parent

        // The lines it rolls through; a line that has nothing to say is left out.
        readonly property var lines: {
            const l = [rest.timeText + "  " + rest.dateText]
            if (rest.weatherState && rest.weatherState.loaded) l.push(Math.round(rest.weatherState.temperatureC) + "°  " + rest.weatherState.condition)
            if (rest.recording || rest.wingMedia || rest.windowTitle) l.push(rest.leftText)
            if (rest.batteryState && rest.batteryState.present) l.push("Battery " + Math.round(rest.batteryState.percent) + "%")
            return l
        }
        property int index: 0
        Timer {
            interval: 4000
            running: rest.design === "ticker"
            repeat: true
            onTriggered: tickerBox.index = (tickerBox.index + 1) % Math.max(1, tickerBox.lines.length)
        }

        Row {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            visible: rest.showWorkspaces
            WorkspaceNumbers { }
        }

        Item {
            anchors.centerIn: parent
            width: 200
            height: parent.height
            clip: true
            Repeater {
                model: tickerBox.lines
                delegate: Label {
                    id: line
                    required property string modelData
                    required property int index
                    readonly property int n: Math.max(1, tickerBox.lines.length)
                    readonly property int slot: (index - tickerBox.index + n) % n
                    x: parent ? (parent.width - width) / 2 : 0
                    y: !parent ? 0 : slot === 0 ? (parent.height - height) / 2 : slot === n - 1 ? -height : parent.height
                    opacity: slot === 0 ? 1 : 0
                    text: modelData
                    role: Enums.TextRole.Bar
                    color: rest.ink
                    font.weight: Font.Medium
                    tabularNumbers: true
                    Behavior on y { NumberAnimation { duration: Tokens.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
                    Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                }
            }
        }

        Row {
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 8
            visible: rest.showStatus
            RecDot { visible: rest.recording; anchors.verticalCenter: parent.verticalCenter }
            StatusGlyph { kind: "wifi"; color: rest.ink; opacity: rest.networkState && rest.networkState.connected ? 1 : 0.4; anchors.verticalCenter: parent.verticalCenter }
            StatusGlyph { kind: "volume"; color: rest.ink; opacity: rest.audioState && rest.audioState.muted ? 0.4 : 1; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
