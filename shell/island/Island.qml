import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.models
import qs.theme

// The island on one screen: a layer window of fixed size at the top centre (so the compositor never animates a
// resize). Only the island inside it takes input; the rest of the window lets clicks through.
PanelWindow {
    id: win

    required property var modelData
    property var shellState         // ShellState
    property var appSettings        // AppSettings
    property var islandState        // IslandState
    property var lockState          // LockState
    property var audioState
    property var networkState
    property var bluetoothState
    property var batteryState
    property var nightLightState
    property var caffeineState
    property var focusState
    property var mediaState
    property var timerState
    property var captureState
    property var displayState
    property var weatherState
    property var workspaces
    property string windowTitle
    property bool slidOut

    // Settings, as read from appSettings.
    property bool hoverOpen
    property bool reserveSpace
    property bool mediaWings
    property bool showWorkspaces
    property bool showStatus
    property bool showWeather
    property string clockFormat

    // This screen's stage and view: Open and Hover only on the screen that was opened; an alert shows on every screen.
    property int stage
    property int view
    property bool isOpen
    property bool isHover
    property bool isAlert

    // Colours of the current stage: the look's ink for the pill, or for the opened island.
    property bool openLike
    property color fg
    property color fgSoft
    property color hairline

    // Morph: how far the island has grown toward the launcher or control center (0 = itself, 1 = fully there).
    property real morphProgress
    property real slide

    // Size of the body for the current stage and view.
    readonly property real restWidthPx: 560   // the island at rest, wide enough for workspaces, time and status icons
    // TODO(phase 7, Island): restWidth = restWidthPx; the rest content comes from the settings island.showWorkspaces, island.showStatus, island.showWeather.
    property real restWidth
    property real targetWidth
    property real targetHeight

    // Hover bookkeeping.
    property bool openedByHover

    signal dropdownRequested(int dropdownId, var anchorItem, var targetScreen, real offsetX)
    signal tileRequested(int tileId)
    signal controlCenterRequested()
    signal launcherRequested()

    // Sizes of the body (px) for each stage and view; Home and Hover take the height of their content.
    readonly property real alertWidth: 380
    readonly property real alertHeight: 38
    readonly property real hoverWidth: 380
    readonly property real homeWidth: 520
    readonly property var viewSizes: ({
        power: { w: 480, h: 150 },
        screenshot: { w: 440, h: 150 },
        clipboard: { w: 520, h: 380 },
        emoji: { w: 480, h: 340 },
        wallpaper: { w: 900, h: 270 }
    })
    // The island grows to this size toward the launcher (its pill) and the control center before it fades out.
    readonly property var morphSizes: ({ launcher: { w: 640, h: 52 }, controlCenter: { w: 760, h: 150 } })

    // Body size (object with w and h) for a stage and view (Enums.IslandStage, Enums.IslandView); contentHeight is the content height of Home or Hover. While morph is not None the morph size wins.
    function sizeFor(stageId: int, viewId: int, contentHeight: real, morph: int): var {
        throw new Error("not implemented")
    }

    // Open the island of this screen at a view.
    function openView(viewId: int): void {
        throw new Error("not implemented")
    }

    // Close it and tell the host that something else was asked for.
    function closeAndThen(action: string): void {
        throw new Error("not implemented")
    }

    // TODO(phase 7, Island): call viewShown() when `view` or `isOpen` changes (onViewChanged, onIsOpenChanged).
    // The opened view changed: reset the view that is shown now (selection, query, armed action), start its reveal.
    function viewShown(): void {
        throw new Error("not implemented")
    }
}
