import QtQuick
import Quickshell
import qs.models
import qs.services

// The notch of every screen. shell.qml loads this file through a Loader (not by type name), so that a fault in the
// notch cannot stop the rest of the shell; the Loader hands the properties below over when it loads it.
Scope {
    id: host

    property var shellState         // ShellState
    property var appSettings        // AppSettings
    property var notchState         // NotchState
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
    property var workspaces         // from Compositor.workspaceList
    property string windowTitle     // from Compositor.activeTitle
    property bool slidOut           // tablet mode: the notch leaves like the bar does

    signal dropdownRequested(int dropdownId, var anchorItem, var targetScreen, real offsetX)
    signal tileRequested(int tileId)
    signal controlCenterRequested()
    signal launcherRequested()

    // Bookkeeping to tell what is new.
    property int lastPopupId: -1
    property string lastTrackKey: ""
    property bool batteryAnnounced

    // The notch closes when anything else takes the stage (dropdown, control center, launcher).
    Connections {
        target: host.shellState
        function onStageChanged() { if (host.shellState.stage !== Enums.Stage.Closed && host.notchState) host.notchState.close() }
        function onActiveOverlayChanged() { if (host.shellState.activeOverlay !== Enums.Overlay.None && host.notchState) host.notchState.close() }
    }

    // Alerts, from the places the bar's context zone reads as well.
    Connections {
        target: Notifications
        function onPopupItemsChanged() {
            const list = Notifications.popupItems
            if (list.length === 0 || list[0].id === host.lastPopupId) return
            host.lastPopupId = list[0].id
            const n = list[0]
            host.notchState.pushAlert("n" + n.id, n.summary || n.appName, n.summary ? n.appName : "", n.severity, Enums.TileId.Notifications)
        }
    }
    Connections {
        target: host.timerState
        function onFinished(label: string) { host.notchState.pushAlert("timer", label ? label + " done" : "Timer done", "", Enums.Severity.Warn, Enums.TileId.Timer) }
    }
    Connections {
        target: host.batteryState
        function onPercentChanged() {
            const b = host.batteryState
            if (b.present && b.discharging && b.percent <= b.criticalBelowPercent) {
                if (!host.batteryAnnounced) {
                    host.batteryAnnounced = true
                    host.notchState.pushAlert("battery", "Battery " + Math.round(b.percent) + "%", "Plug in soon", Enums.Severity.Critical, Enums.TileId.PowerProfile)
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
            if (m.playing) host.notchState.pushAlert("track", m.title, m.artist, Enums.Severity.Neutral, Enums.TileId.Media)
        }
    }

    Variants {
        model: Quickshell.screens

        Notch {
            shellState: host.shellState
            appSettings: host.appSettings
            notchState: host.notchState
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
