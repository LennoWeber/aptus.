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

// Entry point of the aptus shell.
ShellRoot {
    // TODO(phase 7, later sections): create once, pre-loaded: WallpaperPicker, SettingsWindow, ConfirmDialog, LockSurface, EdgeStrips.

    AppSettings { id: settingsObj }
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

    Variants {
        model: Quickshell.screens

        Bar {
            shellState: shellStateObj
            appSettings: settingsObj
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
            onWordmarkClicked: launcherObj.toggle(Enums.LauncherMode.Apps)
            onControlCenterRequested: ipcObj.openControlCenter()
        }
    }

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
        captureState: captureObj
        controlCenter: ccObj
        audioState: audioObj
        displayState: displayObj
        osd: osdObj
        shellState: shellStateObj
    }

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
    }
}
