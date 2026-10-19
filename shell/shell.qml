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
    AiUsageState { id: aiUsageObj }
    ContextState {
        id: contextObj
        battery: batteryObj
        timer: timerObj
        media: mediaObj
        enabled: settingsObj.get("bar.contextZoneEnabled") !== false
    }

    Variants {
        model: Quickshell.screens

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
    Binding { target: Wallpaper; property: "directory"; value: settingsObj.get("wallpaper.directory") || "" }
    Connections { target: settingsAppObj; function onWallpaperRequested() { wallpaperObj.show() } }

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
        else if (actionId === "session.open") powerMenuObj.toggle()
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
        onPowerRequested: { shellStateObj.closeAll(); powerMenuObj.toggle() }
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

    Osd { id: osdObj }

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
    }
}
