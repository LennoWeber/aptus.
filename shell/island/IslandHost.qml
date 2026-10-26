import QtQuick
import Quickshell
import qs.models
import qs.services

// The island of every screen. shell.qml loads this file through a Loader (not by type name), so that a fault in the
// island cannot stop the rest of the shell; the Loader hands the properties below over when it loads it.
Scope {
    id: host

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
    property var workspaces         // from Compositor.workspaceList
    property string windowTitle     // from Compositor.activeTitle
    property bool slidOut           // tablet mode: the island leaves like the bar does

    signal dropdownRequested(int dropdownId, var anchorItem, var targetScreen, real offsetX)
    signal tileRequested(int tileId)
    signal controlCenterRequested()
    signal launcherRequested()

    // Bookkeeping to tell what is new.
    property int lastPopupId: -1
    property string lastTrackKey: ""
    property bool batteryAnnounced

    // Push an alert for the notification at the top of Notifications.popupItems when it is a new one.
    function announceNotification(): void {
        const list = Notifications.popupItems
        if (list.length === 0 || list[0].id === lastPopupId) return
        lastPopupId = list[0].id
        const n = list[0]
        islandState.pushAlert("n" + n.id, n.summary || n.appName, n.summary ? n.appName : "", n.severity, Enums.TileId.Notifications)
    }

    // The launcher or the control center takes the stage (ShellState): tell IslandState where to morph to.
    function followShellState(): void {
        const s = shellState
        let target = Enums.MorphTarget.None
        if (s.activeOverlay === Enums.Overlay.Launcher) target = Enums.MorphTarget.Launcher
        else if (s.activeOverlay === Enums.Overlay.ControlCenter || s.stage === Enums.Stage.ControlCenter || s.stage === Enums.Stage.Detail) target = Enums.MorphTarget.ControlCenter
        islandState.setMorph(target)
        // Anything else that takes the stage (dropdown, wallpaper picker) only closes the island.
        if (target === Enums.MorphTarget.None && (s.stage !== Enums.Stage.Closed || s.activeOverlay !== Enums.Overlay.None)) islandState.close()
    }

    // The island follows the stage: it grows toward the launcher or control center, and comes back when they close.
    Connections {
        target: host.shellState
        function onStageChanged() { host.followShellState() }
        function onActiveOverlayChanged() { host.followShellState() }
    }

    // Alerts, from the places the bar's context zone reads as well.
    Connections {
        target: Notifications
        function onPopupItemsChanged() { host.announceNotification() }
    }
    Connections {
        target: host.timerState
        function onFinished(label: string) { host.islandState.pushAlert("timer", label ? label + " done" : "Timer done", "", Enums.Severity.Warn, Enums.TileId.Timer) }
    }
    Connections {
        target: host.batteryState
        function onPercentChanged() {
            const b = host.batteryState
            if (b.present && b.discharging && b.percent <= b.criticalBelowPercent) {
                if (!host.batteryAnnounced) {
                    host.batteryAnnounced = true
                    host.islandState.pushAlert("battery", "Battery " + Math.round(b.percent) + "%", "Plug in soon", Enums.Severity.Critical, Enums.TileId.PowerProfile)
                }
            } else if (!b.discharging || b.percent > b.criticalBelowPercent + 5) {
                host.batteryAnnounced = false
            }
        }
    }
    Connections {
        target: host.mediaState
        function onTitleChanged() {
            const m = host.mediaState
            const key = m.title + "|" + m.artist
            if (m.title === "" || key === host.lastTrackKey) return
            host.lastTrackKey = key
            if (m.playing) host.islandState.pushAlert("track", m.title, m.artist, Enums.Severity.Neutral, Enums.TileId.Media)
        }
    }

    Variants {
        model: Quickshell.screens

        Island {
            shellState: host.shellState
            appSettings: host.appSettings
            islandState: host.islandState
            lockState: host.lockState
            audioState: host.audioState
            networkState: host.networkState
            bluetoothState: host.bluetoothState
            batteryState: host.batteryState
            nightLightState: host.nightLightState
            caffeineState: host.caffeineState
            focusState: host.focusState
            mediaState: host.mediaState
            timerState: host.timerState
            captureState: host.captureState
            displayState: host.displayState
            weatherState: host.weatherState
            workspaces: host.workspaces
            windowTitle: host.windowTitle
            slidOut: host.slidOut
            onDropdownRequested: (id, anchor, scr, offset) => host.dropdownRequested(id, anchor, scr, offset)
            onTileRequested: id => host.tileRequested(id)
            onControlCenterRequested: host.controlCenterRequested()
            onLauncherRequested: host.launcherRequested()
        }
    }
}
