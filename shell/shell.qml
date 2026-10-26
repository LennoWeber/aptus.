pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.models
import qs.services
import qs.bar
import qs.launcher
import qs.dropdowns
import qs.controlcenter
import qs.notifications
import qs.osd
import qs.settings
import qs.lock
import qs.touch
import qs.session
import qs.osk
import qs.wallpaper
import qs.themepicker
import qs.dock
import qs.theme

// Entry point of the aptus shell.
ShellRoot {
    id: root

    AppSettings { id: settingsObj }
    // The compositor draws the blur; the setting sets its size and passes (applied now and on every change).
    readonly property int blurSetting: settingsObj.get("appearance.blurRadius") ?? 18
    onBlurSettingChanged: applyBlur()
    function applyBlur(): void {
        Quickshell.execDetached(["hyprctl", "eval",
            "hl.config({ decoration = { blur = { size = " + Math.max(1, Math.round(blurSetting / 2)) + ", passes = " + (blurSetting <= 10 ? 2 : 3) + " } } })"])
    }

    DeviceModeState { id: deviceObj; autoRotate: settingsObj.get("touch.autoRotate") !== false }

    // In tablet mode the bar hides to leave room for reading; a swipe from the top edge shows it for a few seconds.
    property bool barRevealed
    readonly property bool barAutoHidden: deviceObj.tabletMode && settingsObj.get("touch.tabletBarAutoHide") !== false
    Timer { id: barHideTimer; interval: 5000; onTriggered: if (shellStateObj.stage === Enums.Stage.Closed) root.barRevealed = false }
    Connections {
        target: shellStateObj
        function onStageChanged() { if (shellStateObj.stage === Enums.Stage.Closed && root.barRevealed) barHideTimer.restart() }
    }
    // Windows start below the bar, or below the island (its rest height plus the gap its look keeps from the edge).
    Binding { target: Tokens; property: "topInset"; value: root.showBar ? Tokens.barHeight : IslandLook.restHeight + IslandLook.gap }
    ShellState { id: shellStateObj }
    LauncherState { id: launcherObj; shellState: shellStateObj }
    BrowserState {
        id: browserObj
        command: settingsObj.browserCommand
        windowClass: settingsObj.browserWindowClass
        searchUrlTemplate: {
            const list = settingsObj.searchEngines || []
            for (const e of list) if (e.id === settingsObj.searchEngineId) return e.urlTemplate
            return list.length > 0 ? list[0].urlTemplate : "https://duckduckgo.com/?q={query}"
        }
    }
    BatteryState { id: batteryObj }
    AudioState { id: audioObj }
    DisplayState { id: displayObj }
    NightLightState { id: nightLightObj }
    ColorModeState { id: colorModeObj; appSettings: settingsObj; nightLight: nightLightObj }

    PowerProfileState { id: powerProfileObj }
    CalendarState { id: calendarObj }
    NetworkState { id: networkObj }
    BluetoothState { id: bluetoothObj }
    MediaState { id: mediaObj }
    CaffeineState { id: caffeineObj }
    FocusState { id: focusObj }
    TimerState { id: timerObj }
    WeatherState { id: weatherObj; appSettings: settingsObj }
    SystemMonitorState { id: systemMonitorObj }
    CaptureState { id: captureObj }
    AiUsageState { id: aiUsageObj; live: settingsObj.get("ai.usageLive") === true }
    ContextState {
        id: contextObj
        battery: batteryObj
        timer: timerObj
        media: mediaObj
        enabled: settingsObj.get("bar.contextZoneEnabled") !== false
    }

    // The top of the screen: the bar, or the island (setting bar.style). The bar is also the fallback when the
    // island fails to load, so the shell never ends up without one.
    readonly property bool islandWanted: settingsObj.get("bar.style") === "island"
    readonly property bool showBar: !islandWanted || islandLoader.status === Loader.Error
    IslandState {
        id: islandObj
        enabled: root.islandWanted && islandLoader.status === Loader.Ready
        alertsEnabled: settingsObj.get("island.alerts") !== false
        alertHoldMs: (settingsObj.get("island.alertSeconds") || 4) * 1000
        mediaWingsEnabled: settingsObj.get("island.mediaWings") !== false
        hoverEnabled: settingsObj.get("island.hoverOpen") !== false
    }
    Loader {
        id: islandLoader
        active: root.islandWanted
        source: "island/IslandHost.qml"
        onLoaded: {
            item.shellState = shellStateObj
            item.appSettings = settingsObj
            item.islandState = islandObj
            item.lockState = lockObj
            item.audioState = audioObj
            item.networkState = networkObj
            item.bluetoothState = bluetoothObj
            item.batteryState = batteryObj
            item.nightLightState = nightLightObj
            item.caffeineState = caffeineObj
            item.focusState = focusObj
            item.mediaState = mediaObj
            item.timerState = timerObj
            item.captureState = captureObj
            item.displayState = displayObj
            item.weatherState = weatherObj
            item.powerProfileState = powerProfileObj
            item.dropdownRequested.connect((id, anchor, scr, offset) => dropdownHost.openAt(id, anchor, scr, offset))
            item.tileRequested.connect(id => ipcObj.openTile(id))
            item.controlCenterRequested.connect(() => ipcObj.openControlCenter())
            item.launcherRequested.connect(() => launcherObj.toggle(Enums.LauncherMode.Apps))
        }
        onStatusChanged: if (status === Loader.Error) console.warn("aptus: the island failed to load, the bar stays")
    }
    Binding { target: islandLoader.item; property: "workspaces"; value: Compositor.workspaceList; when: islandLoader.status === Loader.Ready }
    Binding { target: islandLoader.item; property: "windowTitle"; value: Compositor.activeTitle; when: islandLoader.status === Loader.Ready }
    Binding { target: islandLoader.item; property: "slidOut"; value: root.barAutoHidden && !root.barRevealed; when: islandLoader.status === Loader.Ready }

    // The island's look (setting island.look), resolved against the colours of Tokens.
    readonly property string islandLook: settingsObj.get("island.look") || "paper"
    onIslandLookChanged: IslandLook.apply(islandLook)

    // The island's design (setting island.design): capsule, pill, ticker or shade.
    readonly property string islandDesign: settingsObj.get("island.design") || "capsule"
    onIslandDesignChanged: IslandLook.design = islandDesign

    // The dock (setting dock.enabled).
    Variants {
        model: settingsObj.get("dock.enabled") === true ? Quickshell.screens : []
        Dock { appSettings: settingsObj }
    }

    Variants {
        model: root.showBar ? Quickshell.screens : []

        Bar {
            shellState: shellStateObj
            appSettings: settingsObj
            slidOut: root.barAutoHidden && !root.barRevealed
            batteryState: batteryObj
            audioState: audioObj
            nightLightState: nightLightObj
            captureState: captureObj
            networkState: networkObj
            bluetoothState: bluetoothObj
            caffeineState: caffeineObj
            focusState: focusObj
            onDropdownRequested: (id, anchor, scr) => dropdownHost.openAt(id, anchor, scr)
            workspaces: Compositor.workspaceList
            windowTitle: Compositor.activeTitle
            contextItems: contextObj.items
            onTileRequested: id => ipcObj.openTile(id)
            onWordmarkClicked: launcherObj.toggle(Enums.LauncherMode.Apps)
            onControlCenterRequested: ipcObj.openControlCenter()
        }
    }

    Variants {
        model: Quickshell.screens
        WallpaperLayer {}
    }

    WallpaperPicker { id: wallpaperObj }
    ThemePicker { id: themePickerObj; themeState: colorModeObj }
    Binding { target: Wallpaper; property: "fit"; value: settingsObj.wallpaperFit }
    Binding { target: Wallpaper; property: "loginSync"; value: settingsObj.loginWallpaper }
    Binding { target: Wallpaper; property: "directory"; value: settingsObj.get("wallpaper.directory") || "" }
    Connections { target: settingsAppObj; function onWallpaperRequested() { ipcObj.openWallpaper() } }

    // Swipe from the top or left edge (touch only).
    Variants {
        model: settingsObj.get("touch.edgeGestures.enabled") !== false ? Quickshell.screens : []

        Scope {
            id: edges
            required property var modelData

            EdgeStrip {
                screen: edges.modelData
                edge: Enums.Edge.Top
                widthPx: settingsObj.get("touch.edgeGestures.stripWidthPx") || 16
                onSwiped: root.runEdgeAction(settingsObj.get("touch.edgeGestures.actions.top") || "controlcenter.open", true)
            }
            EdgeStrip {
                screen: edges.modelData
                edge: Enums.Edge.Left
                widthPx: settingsObj.get("touch.edgeGestures.stripWidthPx") || 16
                onSwiped: root.runEdgeAction(settingsObj.get("touch.edgeGestures.actions.left") || "launcher.open:apps", false)
            }
        }
    }

    // Settings strings such as "controlcenter.open", "launcher.open:web" or "session.open".
    function runEdgeAction(actionId: string, topEdge: bool): void {
        if (topEdge && barAutoHidden && !barRevealed) {
            barRevealed = true
            barHideTimer.restart()
            return
        }
        if (actionId === "controlcenter.open") ipcObj.openControlCenter()
        else if (actionId === "session.open") ipcObj.openPower()
        else if (actionId.indexOf("launcher.open:") === 0) {
            const modes = { apps: Enums.LauncherMode.Apps, web: Enums.LauncherMode.Web, settings: Enums.LauncherMode.Settings,
                ai: Enums.LauncherMode.Ai, clipboard: Enums.LauncherMode.Clipboard }
            const mode = modes[actionId.slice("launcher.open:".length)]
            if (mode !== undefined) launcherObj.show(mode)
        }
    }

    Binding { target: Osk; property: "tabletMode"; value: deviceObj.tabletMode }
    Binding { target: Osk; property: "autoShow"; value: settingsObj.get("touch.autoOnScreenKeyboard") !== false }
    OskWindow {}

    PowerMenu { id: powerMenuObj; lockState: lockObj }
    PolkitPrompt {}

    DropdownHost {
        id: dropdownHost
        shellState: shellStateObj
        audioState: audioObj
        batteryState: batteryObj
        powerProfileState: powerProfileObj
        calendarState: calendarObj
        nightLightState: nightLightObj
        displayState: displayObj
        networkState: networkObj
        bluetoothState: bluetoothObj
        onTileRequested: tileId => ipcObj.openTile(tileId)
    }

    Launcher {
        launcherState: launcherObj
        shellState: shellStateObj
        appSettings: settingsObj
    }

    AiPanel {
        launcherState: launcherObj
        appSettings: settingsObj
    }

    Binding { target: launcherObj; property: "defaultProviderId"; value: settingsObj.aiDefaultProviderId }

    ControlCenter {
        id: ccObj
        tileOrder: settingsObj.get("controlCenter.tiles")
        tabletMode: deviceObj.tabletMode
        rotationLocked: deviceObj.rotationLocked
        onRotationLockRequested: ipcObj.toggleRotationLock()
        onTabletRequested: deviceObj.toggleManualTablet()
        onPowerRequested: { shellStateObj.closeAll(); ipcObj.openPower() }
        shellState: shellStateObj
        audioState: audioObj
        displayState: displayObj
        nightLightState: nightLightObj
        networkState: networkObj
        bluetoothState: bluetoothObj
        mediaState: mediaObj
        caffeineState: caffeineObj
        powerProfileState: powerProfileObj
        calendarState: calendarObj
        batteryState: batteryObj
        focusState: focusObj
        timerState: timerObj
        weatherState: weatherObj
        systemMonitorState: systemMonitorObj
        captureState: captureObj
        aiUsageState: aiUsageObj
    }

    NotificationPopups {
        position: settingsObj.get("notifications.position") || "top-right"
    }

    Osd { id: osdObj; islandState: islandObj }

    Connections {
        target: caffeineObj
        function onActiveChanged() { osdObj.flash(Enums.OsdKind.Caffeine, 0, false, caffeineObj.active ? "Caffeine on" : "Caffeine off") }
    }

    Binding { target: nightLightObj; property: "latitude"; value: weatherObj.latitude }
    Binding { target: nightLightObj; property: "longitude"; value: weatherObj.longitude }
    Binding {
        target: calendarObj
        property: "sources"
        // The older single address still works as one source.
        value: (settingsObj.get("calendar.sources") || []).concat(settingsObj.calendarIcsUrl ? [{ name: "Calendar", url: settingsObj.calendarIcsUrl }] : [])
    }
    Binding { target: Notifications; property: "doNotDisturb"; value: focusObj.active }
    Binding { target: Notifications; property: "popupDurationSec"; value: settingsObj.get("notifications.popupDurationSec") || 5 }

    IpcHandlers {
        id: ipcObj
        colorModeState: colorModeObj
        themePicker: themePickerObj
        launcherState: launcherObj
        settingsState: settingsAppObj
        lockState: lockObj
        powerMenu: powerMenuObj
        wallpaperPicker: wallpaperObj
        deviceMode: deviceObj
        captureState: captureObj
        controlCenter: ccObj
        audioState: audioObj
        displayState: displayObj
        osd: osdObj
        shellState: shellStateObj
        islandState: islandObj
    }

    LockState { id: lockObj; keyboardMode: settingsObj.lockKeyboardMode || "auto"; showNotificationContent: settingsObj.lockShowNotificationContent }

    LockScreen {
        lockState: lockObj
        use24h: settingsObj.get("bar.clockFormat") !== "12h"
    }

    Binding { target: Idle; property: "lockState"; value: lockObj }
    Binding { target: Idle; property: "lockAfterMin"; value: settingsObj.lockAfterMin }
    Binding { target: Idle; property: "screenOffAfterMin"; value: settingsObj.screenOffAfterMin }
    Binding { target: Idle; property: "lidCloseAction"; value: settingsObj.lidCloseAction }
    Binding { target: Idle; property: "keepAwakeWhenFullscreen"; value: settingsObj.keepAwakeWhenFullscreen }

    SettingsAppState { id: settingsAppObj; appSettings: settingsObj }

    SettingsWindow {
        appState: settingsAppObj
        appSettings: settingsObj
    }

    ConfirmDialog {
        isOpen: settingsAppObj.phase === Enums.ApplyPhase.AwaitingConfirm
        secondsLeft: settingsAppObj.confirmSecondsLeft
        onConfirmed: settingsAppObj.confirm()
        onReverted: settingsAppObj.revertNow()
    }

    Component.onCompleted: {
        Search.browser = browserObj
        Search.settingsState = settingsAppObj
        Search.controls = { network: networkObj, bluetooth: bluetoothObj, nightLight: nightLightObj, caffeine: caffeineObj, focus: focusObj, timer: timerObj, lock: lockObj }
        applyBlur()
        // AppSettings has not loaded when this handler runs; start after it, or the setting would read as empty
        Qt.callLater(colorModeObj.start)
        IslandLook.load()
        IslandLook.apply(islandLook)
        IslandLook.design = islandDesign
    }
}
