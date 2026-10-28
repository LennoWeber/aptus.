import QtQuick
import QtQuick.Effects
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
    property string homeStyle: appSettings ? appSettings.get("island.homeStyle") || "dashboard" : "dashboard"   // island.homeStyle: classic, dashboard, bento or paper
    readonly property bool cardStyle: homeStyle !== "classic"
    property bool showWeather: appSettings ? appSettings.get("island.showWeather") !== false : true
    property string clockFormat: appSettings ? appSettings.get("bar.clockFormat") || "24h" : "24h"
    property string morphMode: appSettings ? appSettings.get("island.morph") || "spring" : "spring"   // island.morph: spring, calm or off
    onMorphModeChanged: if (["spring", "calm", "off"].indexOf(morphMode) < 0) throw new Error("invariant: Island: unknown morph mode " + morphMode)

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
    property bool homeWithQuick: isOpen && view === Enums.IslandView.Home && !cardStyle   // the classic Home shows the quick settings below the header
    readonly property int openGrowMs: 240   // ms: the body grows to an opened view in this time
    property bool homeWithCard: isOpen && view === Enums.IslandView.Home && cardStyle
    property bool isAlert: stage === Enums.IslandStage.Alert
    // The alert has a card (music, mail, download, notification, timer, battery): the body grows to it.
    readonly property bool cardAlert: isAlert && islandState !== null && islandState.alert !== null && islandState.alert.kind !== Enums.AlertKind.Plain
    readonly property color alertAccent: islandState && islandState.alert && islandState.alert.severity !== Enums.Severity.Neutral ? Tokens.colorFor(islandState.alert.severity) : fg
    property bool isOsd: stage === Enums.IslandStage.Osd   // the on-screen indicator shows
    onByHoverChanged: if (byHover && !isOpen) throw new Error("invariant: Island: byHover while not open")
    property bool byHover: isOpen && islandState && islandState.openedByHover   // opened by the pointer: no focus grab, no keyboard yet

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
    readonly property real homeContentHeight: cardStyle ? card.implicitHeight : home.implicitHeight + (homeWithQuick ? quick.implicitHeight : 0)
    property real targetWidth: sizeFor(stage, view, homeContentHeight, islandState ? islandState.morph : Enums.MorphTarget.None).w
    property real targetHeight: sizeFor(stage, view, homeContentHeight, islandState ? islandState.morph : Enums.MorphTarget.None).h
    // The size the body shows: it follows the target through the animation, so the animation can tell growing from shrinking.
    property real shownW
    property real shownH
    property bool growing: true        // the last change of the target made the body bigger
    property bool ready                // the first size is set; from then on the body animates
    property bool widthRunning
    property bool heightRunning
    readonly property bool moving: widthRunning || heightRunning   // the body is animating its size
    onTargetWidthChanged: retarget()
    function retarget(): void {
        if (ready) growing = (targetWidth - shownW) + (targetHeight - shownH) >= 0
        shownW = targetWidth
        shownH = targetHeight
    }
    Component.onCompleted: { retarget(); ready = true }
    Behavior on shownW { enabled: win.ready; NumberAnimation { onRunningChanged: win.widthRunning = running; duration: win.morphMs(false); easing.type: Easing.BezierSpline; easing.bezierCurve: win.morphCurve() } }
    Behavior on shownH {
        enabled: win.ready
        SequentialAnimation {
            onRunningChanged: win.heightRunning = running
            PauseAnimation { duration: win.growing && win.morphMode === "spring" ? win.heightDelayMs : 0 }
            NumberAnimation { duration: win.morphMs(true); easing.type: Easing.BezierSpline; easing.bezierCurve: win.morphCurve() }
        }
    }

    // How far the body has grown from the pill to the opened card (0..1), read from its real size, so the content follows
    // the shape: the pill content leaves while the body starts to grow, the card content arrives when it is nearly there.
    property real openHeight: 400
    onTargetHeightChanged: { if (isOpen) openHeight = targetHeight; retarget() }
    readonly property real progress: Math.max(0, Math.min(1, (body.height - IslandLook.restHeight) / Math.max(1, openHeight - IslandLook.restHeight)))
    readonly property real cardFade: Math.max(0, Math.min(1, (progress - 0.5) / 0.4))
    readonly property real restFade: Math.max(0, Math.min(1, 1 - progress * 3.5))
    readonly property bool homeShown: view === Enums.IslandView.Home && (isOpen || progress > 0.02)

    signal dropdownRequested(int dropdownId, var anchorItem, var targetScreen, real offsetX)
    signal tileRequested(int tileId)
    signal controlCenterRequested()
    signal launcherRequested()

    // Sizes of the body (px) for each stage and view; Home takes the height of its content.
    readonly property real alertWidth: 380
    readonly property real osdWidth: 360      // the on-screen indicator
    readonly property real osdHeight: 72
    readonly property int osdGrowMs: 160      // ms: the body grows to the indicator in this time
    readonly property int hoverGrowMs: 260    // ms: the body grows to the card when the pointer opened it
    readonly property real alertHeight: 38
    readonly property real alertCardWidth: 520     // the grown alert card (the content is laid out for this width, centred in the body)
    readonly property real alertCardMinHeight: 76
    readonly property real alertCardMaxHeight: 132
    readonly property real alertMediaHeight: 96
    readonly property int alertGrowMs: 340         // ms: the body grows to the card in this time, with a little overshoot
    readonly property real homeWidth: cardStyle ? card.widthFor(homeStyle) : design === "pill" ? 480 : 520
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
        if (morph === Enums.MorphTarget.Launcher) return { w: floorWidth(morphSizes.launcher.w, growMorph), h: morphSizes.launcher.h }
        if (morph === Enums.MorphTarget.ControlCenter) return { w: floorWidth(morphSizes.controlCenter.w, growMorph), h: morphSizes.controlCenter.h }
        if (stageId === Enums.IslandStage.Alert) {
            const a = islandState ? islandState.alert : null
            return a && a.kind !== Enums.AlertKind.Plain ? alertSizeFor(a) : { w: floorWidth(alertWidth, growAlert), h: alertHeight }
        }
        if (stageId === Enums.IslandStage.Osd) return { w: floorWidth(osdWidth, growAlert), h: osdHeight }
        if (stageId === Enums.IslandStage.Open) {
            switch (viewId) {
            case Enums.IslandView.Power: return { w: floorWidth(viewSizes.power.w, growView), h: viewSizes.power.h }
            case Enums.IslandView.Screenshot: return { w: floorWidth(viewSizes.screenshot.w, growView), h: viewSizes.screenshot.h }
            case Enums.IslandView.Clipboard: return { w: floorWidth(viewSizes.clipboard.w, growView), h: viewSizes.clipboard.h }
            case Enums.IslandView.Emoji: return { w: floorWidth(viewSizes.emoji.w, growView), h: viewSizes.emoji.h }
            case Enums.IslandView.Wallpaper: return { w: floorWidth(wallpaper.contentWidth, growView), h: wallpaper.contentHeight }
            default: return { w: floorWidth(homeWidth, growCard), h: contentHeight + 4 }
            }
        }
        return { w: restWidth, h: IslandLook.restHeight }
    }

    // Duration (ms) of the body's growth for a stage and a view (Enums.IslandStage, Enums.IslandView): openGrowMs for an opened view, Tokens.durSlow otherwise.
    function growMsFor(stageId: int, viewId: int): int {
        if (stageId < Enums.IslandStage.Rest || stageId > Enums.IslandStage.Open) throw new Error("invariant: Island.growMsFor: unknown stage")
        if (stageId === Enums.IslandStage.Osd) return osdGrowMs
        if (stageId === Enums.IslandStage.Open) return byHover ? hoverGrowMs : openGrowMs
        return stageId === Enums.IslandStage.Alert ? (cardAlert ? alertGrowMs : 220) : Tokens.durSlow
    }

    // The width ladder: every stage is at least this much wider than the island at rest (px), so the island only grows.
    readonly property real growAlert: 40      // an alert and the on-screen indicator
    readonly property real growCard: 80       // the opened Home card and the alert card
    readonly property real growView: 60       // the other opened views
    readonly property real growMorph: 80      // toward the launcher and the control center
    readonly property real maxWidth: 900      // the body never gets wider than this (the window is 940), also while it overshoots
    // Timing of the morph (ms): the width leads, the height follows a moment later.
    readonly property int springMs: 460
    readonly property int settleMs: 260
    readonly property int heightDelayMs: 30
    readonly property real contentScaleFrom: 0.92   // content arrives at this scale and settles to 1
    readonly property var springCurve: [0.34, 1.3, 0.5, 1, 1, 1]
    readonly property var calmCurve: [0.22, 1, 0.36, 1, 1, 1]

    // w widened to at least restWidth + grow and at most maxWidth.
    function floorWidth(w: real, grow: real): real {
        if (!(w > 0) || !isFinite(w)) throw new Error("invariant: Island.floorWidth: width must be a positive number")
        if (!(grow >= 0) || !isFinite(grow)) throw new Error("invariant: Island.floorWidth: growth must not be negative")
        if (!(restWidth > 0)) throw new Error("invariant: Island.floorWidth: the rest width is not known yet")
        if (restWidth + grow > maxWidth) throw new Error("invariant: Island.floorWidth: the ladder is wider than maxWidth")
        return Math.min(maxWidth, Math.max(w, restWidth + grow))
    }

    // Easing curve of the body's growth for the current morph mode and direction (a Bezier list for NumberAnimation).
    function morphCurve(): var {
        if (["spring", "calm", "off"].indexOf(morphMode) < 0) throw new Error("invariant: Island.morphCurve: unknown mode " + morphMode)
        return morphMode === "spring" && growing ? springCurve : calmCurve
    }

    // Duration in ms of the width (height false) or the height (height true) of the body, for the current mode and direction.
    function morphMs(forHeight: bool): int {
        if (["spring", "calm", "off"].indexOf(morphMode) < 0) throw new Error("invariant: Island.morphMs: unknown mode " + morphMode)
        if (typeof forHeight !== "boolean") throw new Error("invariant: Island.morphMs: forHeight must be a boolean")
        if (morphMode === "off") return growMsFor(stage, view)
        if (!growing) return settleMs
        if (isOsd) return osdGrowMs + 160
        return morphMode === "spring" ? springMs : settleMs + 100
    }

    // Scale of content whose opacity is fade (0..1): contentScaleFrom at 0, 1 at 1; always 1 when the mode is off.
    function contentScale(fade: real): real {
        if (!isFinite(fade)) throw new Error("invariant: Island.contentScale: fade must be a number")
        if (morphMode === "off") return 1
        return contentScaleFrom + (1 - contentScaleFrom) * Math.max(0, Math.min(1, fade))
    }

    // Body size (object with w and h) of the card for an alert (IslandState.alert), told by its kind and its content.
    function alertSizeFor(a: var): var {
        if (!a) throw new Error("invariant: Island.alertSizeFor: no alert")
        if (a.kind === Enums.AlertKind.Plain) throw new Error("invariant: Island.alertSizeFor: a Plain alert has no card")
        const wanted = alertView.cardHeight
        const h = Math.max(a.kind === Enums.AlertKind.Media ? alertMediaHeight : alertCardMinHeight, Math.min(alertCardMaxHeight, wanted))
        return { w: floorWidth(alertCardWidth, growAlert), h: h }
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

    // With island.glass the fill is see-through and the compositor blurs what is behind it.
    readonly property bool glass: appSettings ? appSettings.get("island.glass") === true : false
    function glassOf(c: color): color { return glass ? Qt.rgba(c.r, c.g, c.b, c.a * 0.6) : c }

    readonly property bool darkOpen: IslandLook.fillOpen.hslLightness < 0.5

    screen: modelData
    anchors.top: true
    implicitWidth: 940
    implicitHeight: 660   // the opened Home with an open quick section is the tallest body (about 560 px)
    exclusiveZone: reserveSpace && !slidOut ? Tokens.topInset : 0
    color: "transparent"
    mask: Region { item: body }
    // The Wayland blur type is not known to qmllint; same as in the launcher.
    // qmllint disable unresolved-type unqualified
    BackgroundEffect.blurRegion: Region { item: win.glass ? body : null; radius: body.cornerRadius }
    // qmllint enable unresolved-type unqualified
    WlrLayershell.namespace: "aptus-island"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: isOpen && !byHover ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Fullscreen windows and caffeine keep the screen awake (policy in Idle); the island holds the inhibitor
    // while it is the top element, as the bar does.
    IdleInhibitor {
        enabled: Idle.inhibit
        window: win
    }

    // A click outside closes the opened island.
    HyprlandFocusGrab {
        windows: [win]
        active: win.isOpen && !win.byHover
        onCleared: if (win.islandState) win.islandState.close()
    }

    readonly property bool openLike: isOpen
    onOpenLikeChanged: if (!openLike) { quick.expanded = ""; card.expanded = "" }
    readonly property color fg: openLike ? IslandLook.inkOpen : IslandLook.inkRest
    readonly property color fgSoft: Qt.rgba(fg.r, fg.g, fg.b, 0.65)
    readonly property color hairline: Qt.rgba(fg.r, fg.g, fg.b, 0.16)

    IslandBody {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        y: IslandLook.gap - (height + IslandLook.gap + 2) * win.slide
        width: win.shownW
        height: win.shownH
        floating: IslandLook.gap > 0
        cornerRadius: Math.min(win.openLike ? win.radiusOpen : win.cardAlert ? Math.min(win.radiusOpen, 24) : win.radiusRest, Math.min(width, height) / 2)
        fill: win.glassOf(win.openLike ? IslandLook.fillOpen : win.design === "shade" && !win.isAlert ? IslandLook.inkRest : IslandLook.fillRest)
        stroke: win.openLike ? IslandLook.strokeOpen : IslandLook.strokeRest
        strokeWidth: win.openLike ? IslandLook.strokeWidthOpen : IslandLook.strokeWidthRest
        accent: win.isAlert && win.islandState && win.islandState.alert && win.islandState.alert.severity !== Enums.Severity.Neutral ? Tokens.colorFor(win.islandState.alert.severity) : win.hairline
        accentOpacity: win.isAlert ? 1 : 0.5
        opacity: 1 - win.morphProgress
        Behavior on cornerRadius { NumberAnimation { duration: win.morphMs(true) } }

        // Rest: a tap opens.
        IslandRest {
            id: rest
            anchors.fill: parent
            opacity: !win.isAlert && !win.isOsd && win.design !== "shade" ? win.restFade : 0
            visible: opacity > 0.01
            scale: win.contentScale(opacity)
            layer.enabled: win.morphMode !== "off" && win.moving && visible
            // The effect is a separate scope: it reads the opacity of its item by id.
            // qmllint disable unqualified
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 24; blur: 1 - rest.opacity }
            // qmllint enable unqualified
            design: win.design
            cornerRadius: body.cornerRadius
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

        IslandOsd {
            anchors.fill: parent
            opacity: win.isOsd ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Tokens.durFast } }
            osd: win.islandState ? win.islandState.osd : null
            ink: win.fg
            inkSoft: win.fgSoft
            line: win.hairline
        }

        IslandAlert {
            id: alertView
            anchors.fill: parent
            opacity: win.isAlert ? 1 : 0
            visible: opacity > 0.01
            // A card shows up a moment after the body started to grow, and slides in a little.
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: win.isAlert && win.cardAlert ? 110 : 0 }
                    NumberAnimation { duration: win.cardAlert ? 220 : Tokens.durFast }
                }
            }
            transform: Translate { y: win.cardAlert ? (1 - alertView.opacity) * 10 : 0 }
            scale: win.contentScale(opacity)
            layer.enabled: win.morphMode !== "off" && win.moving && visible
            // The effect is a separate scope: it reads the opacity of its item by id.
            // qmllint disable unqualified
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 24; blur: 1 - alertView.opacity }
            // qmllint enable unqualified
            alert: win.islandState ? win.islandState.alert : null
            mediaState: win.mediaState
            cardWidth: win.alertCardWidth
            ink: win.fg
            inkSoft: win.fgSoft
            line: win.hairline
            accent: win.alertAccent
            onClicked: {
                const a = win.islandState.alert
                win.islandState.dismissAlert()
                if (a && a.tileId) win.tileRequested(a.tileId)
            }
            onDismissed: win.islandState.dismissAlert()
            onActionInvoked: id => {
                const a = win.islandState.alert
                win.islandState.dismissAlert()
                if (a && a.notificationId >= 0) Notifications.invoke(a.notificationId, id)
            }
            onHoverChanged: hovered => win.islandState.pauseAlert(hovered)
        }

        // The quick settings, under the opened Home.
        IslandQuick {
            id: quick
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: home.implicitHeight }
            opacity: win.homeShown && !win.cardStyle ? win.cardFade : 0
            y: (1 - win.cardFade) * -8
            visible: opacity > 0.01
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
            onSectionToggled: name => { if (name !== "" && win.islandState) win.islandState.keepOpen(win.modelData.name) }
            onViewRequested: v => win.openView(v)
            onCloseRequested: win.islandState.close()
        }

        // Opened: one view at a time, each fades in when the body has grown.
        FocusScope {
            id: views
            anchors.fill: parent
            focus: win.isOpen && !quick.focus && !card.focus
            opacity: win.view === Enums.IslandView.Home ? win.cardFade : win.isOpen ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { enabled: win.view !== Enums.IslandView.Home; NumberAnimation { duration: Tokens.durFast } }
            scale: win.contentScale(opacity)
            layer.enabled: win.morphMode !== "off" && win.moving && visible
            // The effect is a separate scope: it reads the opacity of its item by id.
            // qmllint disable unqualified
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 24; blur: 1 - views.opacity }
            // qmllint enable unqualified
            Keys.onEscapePressed: win.islandState.close()

            IslandHome {
                id: home
                anchors { left: parent.left; right: parent.right; top: parent.top }
                opacity: win.view === Enums.IslandView.Home && !win.cardStyle ? 1 : 0
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

            IslandCard {
                id: card
                anchors { left: parent.left; right: parent.right; top: parent.top }
                style: win.cardStyle ? win.homeStyle : "dashboard"
                opacity: win.view === Enums.IslandView.Home && win.cardStyle ? 1 : 0
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
                workspaces: win.workspaces
                workspaceStyle: win.workspaceStyle
                clockFormat: win.clockFormat
                inkOn: IslandLook.fillOpen
                focus: win.homeWithCard && expanded !== ""   // a list with a field (the Wi-Fi password) takes the keyboard
                ink: win.fg
                inkSoft: win.fgSoft
                line: win.hairline
                fill: win.openLike ? IslandLook.fillOpen : IslandLook.fillRest
                onControlCenterRequested: win.closeAndThen("controlCenter")
                onSectionToggled: name => { if (name !== "" && win.islandState) win.islandState.keepOpen(win.modelData.name) }
                onViewRequested: v => win.openView(v)
                onCloseRequested: win.islandState.close()
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


        // Hover: the pointer resting on the island opens Home; leaving closes it again unless the card was used.
        HoverHandler {
            onHoveredChanged: {
                if (!win.islandState) return
                if (hovered) win.islandState.hoverEnter(win.modelData.name)
                else win.islandState.hoverLeave(win.modelData.name)
            }
        }
        // Any tap in the card keeps it open.
        TapHandler {
            onTapped: { if (win.islandState) win.islandState.keepOpen(win.modelData.name) }
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
