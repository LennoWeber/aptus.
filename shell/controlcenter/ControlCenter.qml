pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.models
import qs.theme
import qs.controlcenter.tiles

// Fullscreen overlay with blurred background and tiles.
PanelWindow {
    id: cc

    property var shellState  // ShellState
    property var audioState
    property var displayState
    property var nightLightState
    property var networkState
    property var bluetoothState
    property var mediaState
    property var caffeineState
    property var powerProfileState
    property var calendarState
    property var batteryState
    property var focusState
    property var timerState
    property var weatherState
    property var systemMonitorState
    property var captureState
    property var aiUsageState
    property int unreadNotifications

    // Layout of the tiles on a 6 x 5 grid: { tileId, title, column, row, columnSpan, rowSpan }.
    property var tiles: [
        { tileId: Enums.TileId.Audio, title: "Sound", column: 0, row: 0, columnSpan: 2, rowSpan: 1 },
        { tileId: Enums.TileId.Display, title: "Display", column: 2, row: 0, columnSpan: 2, rowSpan: 1 },
        { tileId: Enums.TileId.Network, title: "Network", column: 4, row: 0, columnSpan: 1, rowSpan: 1 },
        { tileId: Enums.TileId.Bluetooth, title: "Bluetooth", column: 5, row: 0, columnSpan: 1, rowSpan: 1 },
        { tileId: Enums.TileId.PowerProfile, title: "Power", column: 0, row: 1, columnSpan: 1, rowSpan: 1 },
        { tileId: Enums.TileId.Caffeine, title: "Caffeine", column: 1, row: 1, columnSpan: 1, rowSpan: 1 },
        { tileId: Enums.TileId.Focus, title: "Focus", column: 2, row: 1, columnSpan: 1, rowSpan: 1 },
        { tileId: Enums.TileId.Vpn, title: "VPN", column: 3, row: 1, columnSpan: 1, rowSpan: 1 },
        { tileId: Enums.TileId.Hotspot, title: "Hotspot", column: 4, row: 1, columnSpan: 1, rowSpan: 1 },
        { tileId: Enums.TileId.Capture, title: "Capture", column: 5, row: 1, columnSpan: 1, rowSpan: 1 },
        { tileId: Enums.TileId.Timer, title: "Timer", column: 0, row: 2, columnSpan: 2, rowSpan: 1 },
        { tileId: Enums.TileId.Weather, title: "Weather", column: 2, row: 2, columnSpan: 2, rowSpan: 1 },
        { tileId: Enums.TileId.Notifications, title: "Notifications", column: 4, row: 2, columnSpan: 2, rowSpan: 1 },
        { tileId: Enums.TileId.Media, title: "Media", column: 0, row: 3, columnSpan: 2, rowSpan: 2 },
        { tileId: Enums.TileId.Calendar, title: "Calendar", column: 2, row: 3, columnSpan: 2, rowSpan: 2 },
        { tileId: Enums.TileId.AiUsage, title: "AI usage", column: 4, row: 3, columnSpan: 2, rowSpan: 1 },
        { tileId: Enums.TileId.SystemMonitor, title: "System", column: 4, row: 4, columnSpan: 2, rowSpan: 1 }
    ]
    property int activeTile: shellState ? shellState.activeTile : Enums.TileId.None  // Enums.TileId
    readonly property bool isOpen: shellState ? (shellState.stage === Enums.Stage.ControlCenter || shellState.stage === Enums.Stage.Detail) : false
    property real blurAmount: isOpen ? 1 : 0  // 0..1
    property real detailProgress: detail.progress  // 0 grid, 1 detail

    readonly property int gap: 12
    readonly property int cellHeight: 124
    readonly property int columns: 6
    readonly property int rows: 5
    readonly property real boardWidth: Math.min(width - 40, 1080)
    readonly property real cellWidth: (boardWidth - (columns - 1) * gap) / columns
    readonly property real boardHeight: rows * cellHeight + (rows - 1) * gap
    // The detail view is a fixed, comfortable size in the middle of the board.
    readonly property real detailWidth: Math.min(boardWidth, 800)
    readonly property real detailHeight: Math.min(boardHeight, 540)

    Behavior on blurAmount { NumberAnimation { duration: Tokens.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }

    function show(): void {
        shellState.openControlCenter()
    }

    function hide(): void {
        shellState.closeAll()
    }

    // Grow a tile to the whole area.
    function openTile(tileId: int, originRect: var): void {
        detail.originRect = originRect
        detail.tileId = tileId
        detail.title = titleOf(tileId)
        detail.contentComponent = componentFor(tileId)
        shellState.openTile(tileId)
    }

    // Detail -> grid -> closed.
    function back(): void {
        shellState.back()
    }

    function titleOf(tileId: int): string {
        const t = tiles.find(x => x.tileId === tileId)
        return t ? t.title : ""
    }

    function componentFor(tileId: int): var {
        switch (tileId) {
        case Enums.TileId.Audio: return audioContent
        case Enums.TileId.Display: return displayContent
        case Enums.TileId.Network: return networkContent
        case Enums.TileId.Bluetooth: return bluetoothContent
        case Enums.TileId.PowerProfile: return powerContent
        case Enums.TileId.Caffeine: return caffeineContent
        case Enums.TileId.Media: return mediaContent
        case Enums.TileId.Calendar: return calendarContent
        case Enums.TileId.Focus: return focusContent
        case Enums.TileId.Timer: return timerContent
        case Enums.TileId.Weather: return weatherContent
        case Enums.TileId.SystemMonitor: return systemMonitorContent
        case Enums.TileId.Capture: return captureContent
        case Enums.TileId.Vpn: return vpnContent
        case Enums.TileId.Hotspot: return hotspotContent
        case Enums.TileId.AiUsage: return aiUsageContent
        case Enums.TileId.Notifications: return notificationsContent
        default: return null
        }
    }

    // A tile tap opens its detail view; the caffeine and focus tiles just toggle.
    function activate(tileId: int, originRect: var): void {
        if (tileId === Enums.TileId.Caffeine) caffeineState.toggle()
        else if (tileId === Enums.TileId.Focus) focusState.toggle()
        else if (tileId === Enums.TileId.Capture && captureState.recording) captureState.stopRecording()
        else openTile(tileId, originRect)
    }

    screen: {
        const m = Hyprland.focusedMonitor
        if (m) for (const s of Quickshell.screens) if (s.name === m.name) return s
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }
    // Unmapped at once (no fade) while a capture is about to be taken.
    property bool capturing
    onIsOpenChanged: if (isOpen) capturing = false
    visible: !capturing && (isOpen || blurAmount > 0.001)
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aptus-controlcenter"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    readonly property Item blurTarget: scrim
    // The Wayland blur type is not known to qmllint; it was verified at runtime (probe R2).
    // qmllint disable unresolved-type unqualified
    BackgroundEffect.blurRegion: Region { item: cc.blurTarget }
    // qmllint enable unresolved-type unqualified

    // Esc goes one step back: detail -> control center -> closed (works whatever has the focus).
    Shortcut {
        sequence: "Escape"
        enabled: cc.isOpen
        onActivated: cc.back()
    }

    // System sampling runs only while the control center is on screen.
    Binding {
        target: cc.systemMonitorState
        property: "sampling"
        value: cc.isOpen
        when: cc.systemMonitorState !== undefined && cc.systemMonitorState !== null
    }

    // A screenshot or recording must not contain the control center.
    Connections {
        target: cc.captureState

        function onHideShellRequested() {
            cc.capturing = true
            cc.hide()
        }
    }

    Connections {
        target: cc.shellState

        function onStageChanged() {
            if (cc.shellState.stage === Enums.Stage.Detail) detail.grow()
            else if (detail.progress > 0) detail.shrink()
        }
    }

    // Blur plus a light veil; a click outside the board closes everything.
    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Tokens.bg
        opacity: Tokens.overlayDim * 2 * cc.blurAmount
        MouseArea {
            anchors.fill: parent
            onClicked: cc.hide()
        }
    }

    Item {
        id: board
        width: cc.boardWidth
        height: cc.boardHeight
        x: (parent.width - width) / 2
        y: Math.max(Tokens.barHeight + 24, (parent.height - height) * 0.38) + 10 * (1 - cc.blurAmount)
        opacity: cc.blurAmount

        Repeater {
            model: cc.tiles
            delegate: Tile {
                id: tile
                required property var modelData
                tileId: modelData.tileId
                title: modelData.title
                spec: modelData
                x: modelData.column * (cc.cellWidth + cc.gap)
                y: modelData.row * (cc.cellHeight + cc.gap)
                width: modelData.columnSpan * cc.cellWidth + (modelData.columnSpan - 1) * cc.gap
                height: modelData.rowSpan * cc.cellHeight + (modelData.rowSpan - 1) * cc.gap
                opacity: 1 - detail.progress
                onActivated: tid => cc.activate(tid, Qt.rect(x, y, width, height))

                Loader {
                    anchors.fill: parent
                    sourceComponent: cc.componentFor(tile.tileId)
                    onLoaded: item.expanded = false
                }
            }
        }

        DetailFrame {
            id: detail
            anchors.fill: parent
            targetRect: Qt.rect((board.width - cc.detailWidth) / 2, (board.height - cc.detailHeight) / 2, cc.detailWidth, cc.detailHeight)
            onBackRequested: cc.back()
        }
    }

    // One content component per tile; the same one is used compact in the grid and expanded in the detail view.
    Component { id: audioContent; AudioTile { audioState: cc.audioState } }
    Component { id: displayContent; DisplayTile { displayState: cc.displayState; nightLightState: cc.nightLightState } }
    Component { id: networkContent; NetworkTile { networkState: cc.networkState } }
    Component { id: bluetoothContent; BluetoothTile { bluetoothState: cc.bluetoothState } }
    Component { id: powerContent; PowerProfileTile { powerProfileState: cc.powerProfileState; batteryState: cc.batteryState } }
    Component { id: caffeineContent; CaffeineTile { caffeineState: cc.caffeineState } }
    Component { id: mediaContent; MediaTile { mediaState: cc.mediaState } }
    Component { id: calendarContent; CalendarTile { calendarState: cc.calendarState } }
    Component { id: focusContent; FocusTile { focusState: cc.focusState } }
    Component { id: timerContent; TimerTile { timerState: cc.timerState } }
    Component { id: weatherContent; WeatherTile { weatherState: cc.weatherState } }
    Component { id: systemMonitorContent; SystemMonitorTile { systemMonitorState: cc.systemMonitorState } }
    Component { id: captureContent; CaptureTile { captureState: cc.captureState } }
    Component { id: vpnContent; VpnTile { networkState: cc.networkState } }
    Component { id: hotspotContent; HotspotTile { networkState: cc.networkState } }
    Component { id: aiUsageContent; AiUsageTile { aiUsageState: cc.aiUsageState } }
    Component { id: notificationsContent; NotificationsTile { unreadCount: cc.unreadNotifications } }
}
