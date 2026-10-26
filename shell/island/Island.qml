import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.models
import qs.theme
import qs.services

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
    property var powerProfileState
    property var workspaces
    property string windowTitle
    property bool slidOut

    // Settings, as read from appSettings.
    property bool reserveSpace: appSettings ? appSettings.get("island.reserveSpace") !== false : true
    property bool mediaWings: appSettings ? appSettings.get("island.mediaWings") !== false : true
    property string workspaceStyle: appSettings ? appSettings.get("bar.workspaceStyle") || "bubbles" : "bubbles"   // bar.workspaceStyle
    property bool showWorkspaces: appSettings ? appSettings.get("island.showWorkspaces") !== false : true
    property bool showStatus: appSettings ? appSettings.get("island.showStatus") !== false : true
    property bool showWeather: appSettings ? appSettings.get("island.showWeather") !== false : true
    property string clockFormat: appSettings ? appSettings.get("bar.clockFormat") || "24h" : "24h"

    // This screen's stage and view: Open only on the screen that was opened; an alert shows on every screen.
    property int stage: {
        if (!islandState) return Enums.IslandStage.Rest
        const s = islandState.stage
        if (s === Enums.IslandStage.Open && islandState.openScreen !== modelData.name)
            return islandState.alert ? Enums.IslandStage.Alert : Enums.IslandStage.Rest
        return s
    }
    property int view: islandState ? islandState.view : Enums.IslandView.Home
    property bool isOpen: stage === Enums.IslandStage.Open
    onStageChanged: if (stage < Enums.IslandStage.Rest || stage > Enums.IslandStage.Open) throw new Error("invariant: Island: unknown stage")
    property bool homeWithQuick: isOpen && view === Enums.IslandView.Home   // the opened Home shows the quick settings below the header (every design)
    // TODO(phase 7): openGrowMs 200.
    readonly property int openGrowMs: 220   // ms: the body grows to an opened view in this time
    // TODO(phase 7): add isOsd (stage === Osd); the stage getter shows Osd on every screen like an alert.
    property bool isAlert: stage === Enums.IslandStage.Alert

    // The design (setting island.design): capsule, pill, ticker or shade. It sets the size at rest and the shape.
    readonly property string design: IslandLook.design
    readonly property real radiusRest: design === "pill" ? IslandLook.restHeight / 2 : design === "shade" ? 3 : IslandLook.radiusRest
    readonly property real radiusOpen: design === "pill" ? 26 : design === "shade" ? 18 : IslandLook.radiusOpen

    // Morph: how far the island has grown toward the launcher or control center (0 = itself, 1 = fully there).
    property real morphProgress: islandState && islandState.morph !== Enums.MorphTarget.None ? 1 : 0
    property real slide: slidOut ? 1 : 0
    Behavior on morphProgress { NumberAnimation { duration: Tokens.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
    Behavior on slide { NumberAnimation { duration: Tokens.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }

    // Size of the body for the current stage and view.
    property real restWidth: rest.wantedWidth
    property real targetWidth: sizeFor(stage, view, home.implicitHeight + (homeWithQuick ? quick.implicitHeight : 0), islandState ? islandState.morph : Enums.MorphTarget.None).w
    property real targetHeight: sizeFor(stage, view, home.implicitHeight + (homeWithQuick ? quick.implicitHeight : 0), islandState ? islandState.morph : Enums.MorphTarget.None).h

    signal dropdownRequested(int dropdownId, var anchorItem, var targetScreen, real offsetX)
    signal tileRequested(int tileId)
    signal controlCenterRequested()
    signal launcherRequested()

    // Sizes of the body (px) for each stage and view; Home takes the height of its content.
    readonly property real alertWidth: 380
    readonly property real osdWidth: 320      // the on-screen indicator
    readonly property real osdHeight: 46
    readonly property int osdGrowMs: 160      // ms: the body grows to the indicator in this time
    readonly property int hoverGrowMs: 180    // ms: the body grows to the card when the pointer opened it
    readonly property real alertHeight: 38
    readonly property real homeWidth: design === "pill" ? 480 : 520
    readonly property var viewSizes: ({
        power: { w: 480, h: 150 },
        screenshot: { w: 440, h: 150 },
        clipboard: { w: 520, h: 380 },
        emoji: { w: 480, h: 340 }
    })
    // The island grows to this size toward the launcher (its pill) and the control center before it fades out.
    readonly property var morphSizes: ({ launcher: { w: 640, h: 52 }, controlCenter: { w: 760, h: 150 } })

    // Body size (object with w and h) for a stage and view (Enums.IslandStage, Enums.IslandView); contentHeight is the
    // content height of Home. While morph is not None the morph size wins.
    function sizeFor(stageId: int, viewId: int, contentHeight: real, morph: int): var {
        if (morph === Enums.MorphTarget.Launcher) return morphSizes.launcher
        if (morph === Enums.MorphTarget.ControlCenter) return morphSizes.controlCenter
        // TODO(phase 7): sizeFor: Osd returns { w: osdWidth, h: osdHeight }.
        if (stageId === Enums.IslandStage.Alert) return { w: alertWidth, h: alertHeight }
        if (stageId === Enums.IslandStage.Open) {
            switch (viewId) {
            case Enums.IslandView.Power: return viewSizes.power
            case Enums.IslandView.Screenshot: return viewSizes.screenshot
            case Enums.IslandView.Clipboard: return viewSizes.clipboard
            case Enums.IslandView.Emoji: return viewSizes.emoji
            case Enums.IslandView.Wallpaper: return { w: wallpaper.contentWidth, h: wallpaper.contentHeight }
            default: return { w: homeWidth, h: contentHeight + 4 }
            }
        }
        return { w: restWidth, h: IslandLook.restHeight }
    }

    // Duration (ms) of the body's growth for a stage and a view (Enums.IslandStage, Enums.IslandView): openGrowMs for an opened view, Tokens.durSlow otherwise.
    function growMsFor(stageId: int, viewId: int): int {
        // TODO(phase 7): growMsFor: Osd osdGrowMs, Open after a hover hoverGrowMs, Alert 220, else Tokens.durSlow; fix the range test.
        if (stageId < Enums.IslandStage.Rest || stageId > Enums.IslandStage.Open) throw new Error("invariant: Island.growMsFor: unknown stage")
        return stageId === Enums.IslandStage.Open ? openGrowMs : Tokens.durSlow
    }

    // Open the island of this screen at a view.
    function openView(viewId: int): void {
        islandState.open(modelData.name, viewId)
    }

    // Close it and tell the host that something else was asked for.
    function closeAndThen(action: string): void {
        islandState.close()
        if (action === "launcher") launcherRequested()
        else if (action === "controlCenter") controlCenterRequested()
    }

    readonly property bool darkOpen: IslandLook.fillOpen.hslLightness < 0.5

    screen: modelData
    anchors.top: true
    implicitWidth: 940
    implicitHeight: 660   // the opened Home with an open quick section is the tallest body (about 560 px)
    exclusiveZone: reserveSpace && !slidOut ? Tokens.topInset : 0
    color: "transparent"
    mask: Region { item: body }
    WlrLayershell.namespace: "aptus-island"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Fullscreen windows and caffeine keep the screen awake (policy in Idle); the island holds the inhibitor
    // while it is the top element, as the bar does.
    IdleInhibitor {
        enabled: Idle.inhibit
        window: win
    }

    // A click outside closes the opened island.
    // TODO(phase 7): a click on the body (MouseArea, TapHandler) calls islandState.keepOpen(modelData.name); add a HoverHandler on the body: enter -> hoverEnter, leave -> hoverLeave.
    HyprlandFocusGrab {
        windows: [win]
        active: win.isOpen
        onCleared: if (win.islandState) win.islandState.close()
    }

    readonly property bool openLike: isOpen
    // TODO(phase 7): also keepOpen when a section opens: wire quick.onSectionToggled to islandState.keepOpen.
    onOpenLikeChanged: if (!openLike) quick.expanded = ""
    readonly property color fg: openLike ? IslandLook.inkOpen : IslandLook.inkRest
    readonly property color fgSoft: Qt.rgba(fg.r, fg.g, fg.b, 0.65)
    readonly property color hairline: Qt.rgba(fg.r, fg.g, fg.b, 0.16)

    IslandBody {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        y: IslandLook.gap - (height + IslandLook.gap + 2) * win.slide
        width: win.targetWidth
        height: win.targetHeight
        floating: IslandLook.gap > 0
        cornerRadius: Math.min(win.openLike ? win.radiusOpen : win.radiusRest, Math.min(width, height) / 2)
        fill: win.openLike ? IslandLook.fillOpen : win.design === "shade" && !win.isAlert ? IslandLook.inkRest : IslandLook.fillRest
        stroke: win.openLike ? IslandLook.strokeOpen : IslandLook.strokeRest
        strokeWidth: win.openLike ? IslandLook.strokeWidthOpen : IslandLook.strokeWidthRest
        accent: win.isAlert && win.islandState && win.islandState.alert && win.islandState.alert.severity !== Enums.Severity.Neutral ? Tokens.colorFor(win.islandState.alert.severity) : win.hairline
        accentOpacity: win.isAlert ? 1 : 0.5
        opacity: 1 - win.morphProgress
        Behavior on width { NumberAnimation { duration: win.growMsFor(win.stage, win.view); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
        Behavior on height { NumberAnimation { duration: win.growMsFor(win.stage, win.view); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
        // TODO(phase 7): same duration as the growth (win.growMsFor), so the corners do not lag.
        Behavior on cornerRadius { NumberAnimation { duration: Tokens.durSlow } }

        // Rest: a tap opens.
        IslandRest {
            id: rest
            anchors.fill: parent
            // TODO(phase 7): hide the rest content while isOsd too.
            opacity: !win.openLike && !win.isAlert && win.design !== "shade" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
            design: win.design
            mediaState: win.mediaState
            timerState: win.timerState
            captureState: win.captureState
            workspaces: win.workspaces
            windowTitle: win.windowTitle
            audioState: win.audioState
            networkState: win.networkState
            bluetoothState: win.bluetoothState
            batteryState: win.batteryState
            nightLightState: win.nightLightState
            caffeineState: win.caffeineState
            focusState: win.focusState
            weatherState: win.weatherState
            showWorkspaces: win.showWorkspaces
            workspaceStyle: win.workspaceStyle
            inkOn: win.openLike ? IslandLook.fillOpen : IslandLook.fillRest
            showStatus: win.showStatus
            showWeather: win.showWeather
            onWorkspaceClicked: id => Compositor.focusWorkspace(id)
            mediaWings: win.mediaWings
            clockFormat: win.clockFormat
            ink: win.fg
            inkSoft: win.fgSoft
            monoClock: IslandLook.monoClock

            MouseArea {
                anchors.fill: parent
                onClicked: win.openView(Enums.IslandView.Home)
            }
        }

        // TODO(phase 7): add the IslandOsd instance here (anchors.fill, opacity win.isOsd, osd: islandState.osd, inks from win.fg); hide the alert while isOsd.
        IslandAlert {
            anchors.fill: parent
            opacity: win.isAlert ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
            alert: win.islandState ? win.islandState.alert : null
            ink: win.fg
            inkSoft: win.fgSoft
            onClicked: {
                const a = win.islandState.alert
                win.islandState.dismissAlert()
                if (a && a.tileId) win.tileRequested(a.tileId)
            }
        }

        // The quick settings, under the opened Home.
        IslandQuick {
            id: quick
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: home.implicitHeight }
            opacity: win.homeWithQuick ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
            appSettings: win.appSettings
            audioState: win.audioState
            displayState: win.displayState
            networkState: win.networkState
            bluetoothState: win.bluetoothState
            batteryState: win.batteryState
            nightLightState: win.nightLightState
            caffeineState: win.caffeineState
            focusState: win.focusState
            mediaState: win.mediaState
            powerProfileState: win.powerProfileState
            focus: win.homeWithQuick && expanded !== ""   // a section with a field (the Wi-Fi password) takes the keyboard
            ink: win.fg
            inkSoft: win.fgSoft
            line: win.hairline
            fill: win.openLike ? IslandLook.fillOpen : IslandLook.fillRest
            onControlCenterRequested: win.closeAndThen("controlCenter")
            onViewRequested: v => win.openView(v)
            onCloseRequested: win.islandState.close()
        }

        // Opened: one view at a time, each fades in when the body has grown.
        FocusScope {
            anchors.fill: parent
            focus: win.isOpen && !quick.focus
            opacity: win.isOpen ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
            Keys.onEscapePressed: win.islandState.close()

            IslandHome {
                id: home
                anchors { left: parent.left; right: parent.right; top: parent.top }
                opacity: win.view === Enums.IslandView.Home ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                appSettings: win.appSettings
                audioState: win.audioState
                networkState: win.networkState
                bluetoothState: win.bluetoothState
                batteryState: win.batteryState
                nightLightState: win.nightLightState
                caffeineState: win.caffeineState
                focusState: win.focusState
                mediaState: win.mediaState
                workspaces: win.workspaces
                workspaceStyle: win.workspaceStyle
                inkOn: IslandLook.fillOpen
                clockFormat: win.clockFormat
                ink: win.fg
                inkSoft: win.fgSoft
                line: win.hairline
                // The dropdown is placed first (it reads where the icon is), then the island closes.
                onDropdownRequested: (id, anchor) => {
                    win.dropdownRequested(id, anchor, win.modelData, (win.modelData.width - win.width) / 2)
                    win.islandState.close()
                }
                onLauncherRequested: win.closeAndThen("launcher")
                onControlCenterRequested: win.closeAndThen("controlCenter")
            }

            IslandPower {
                id: power
                anchors.fill: parent
                opacity: win.view === Enums.IslandView.Power ? 1 : 0
                visible: opacity > 0.01
                focus: win.view === Enums.IslandView.Power
                Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                lockState: win.lockState
                ink: win.fg
                inkSoft: win.fgSoft
                line: win.hairline
                onCloseRequested: win.islandState.close()
            }

            IslandScreenshot {
                id: shot
                anchors.fill: parent
                opacity: win.view === Enums.IslandView.Screenshot ? 1 : 0
                visible: opacity > 0.01
                focus: win.view === Enums.IslandView.Screenshot
                Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                captureState: win.captureState
                ink: win.fg
                inkSoft: win.fgSoft
                line: win.hairline
                onCloseRequested: win.islandState.close()
            }

            IslandClipboard {
                id: clipboard
                anchors.fill: parent
                opacity: win.view === Enums.IslandView.Clipboard ? 1 : 0
                visible: opacity > 0.01
                focus: win.view === Enums.IslandView.Clipboard
                Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                ink: win.fg
                inkSoft: win.fgSoft
                line: win.hairline
                onCloseRequested: win.islandState.close()
            }

            IslandEmoji {
                id: emoji
                anchors.fill: parent
                opacity: win.view === Enums.IslandView.Emoji ? 1 : 0
                visible: opacity > 0.01
                focus: win.view === Enums.IslandView.Emoji
                Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                ink: win.fg
                inkSoft: win.fgSoft
                line: win.hairline
                onCloseRequested: win.islandState.close()
            }

            IslandWallpaper {
                id: wallpaper
                anchors.fill: parent
                opacity: win.view === Enums.IslandView.Wallpaper ? 1 : 0
                visible: opacity > 0.01
                focus: win.view === Enums.IslandView.Wallpaper
                active: win.isOpen && win.view === Enums.IslandView.Wallpaper
                Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
                ink: win.fg
                inkSoft: win.fgSoft
                line: win.hairline
                onCloseRequested: win.islandState.close()
            }
        }

    }

    // A view is reset when it is shown.
    onViewChanged: win.viewShown()
    onIsOpenChanged: win.viewShown()
    function viewShown(): void {
        if (!isOpen) return
        if (view === Enums.IslandView.Power) power.reset()
        else if (view === Enums.IslandView.Screenshot) shot.reset()
        else if (view === Enums.IslandView.Clipboard) clipboard.reset()
        else if (view === Enums.IslandView.Emoji) emoji.reset()
        else if (view === Enums.IslandView.Wallpaper) wallpaper.show()
    }
}
