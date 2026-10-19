pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.models
import qs.services
import qs.bar
import qs.launcher
import qs.dropdowns
import qs.controlcenter

// Entry point of the aptus shell.
ShellRoot {
    // TODO(phase 7, later sections): create once, pre-loaded: NotificationPopups, Osd, WallpaperPicker, SettingsWindow, ConfirmDialog, LockSurface, EdgeStrips.

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
    }

    Launcher {
        launcherState: launcherObj
        shellState: shellStateObj
        appSettings: settingsObj
    }

    ControlCenter {
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

    IpcHandlers {
        id: ipcObj
        launcherState: launcherObj
        captureState: captureObj
        shellState: shellStateObj
    }

    Component.onCompleted: Search.browser = browserObj
}
