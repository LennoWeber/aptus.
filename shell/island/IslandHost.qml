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
    property var powerProfileState
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

    // Enums.AlertKind of a notification, told by its app and text: Mail, Download, or plain Notification.
    function classifyNotification(n: var): int {
        if (!n || !Number.isInteger(n.id)) throw new Error("invariant: IslandHost.classifyNotification: a notification needs an integer id")
        const app = ((n.appName || "") + " " + (n.desktopEntry || "")).toLowerCase()
        const text = ((n.summary || "") + " " + (n.body || "")).toLowerCase()
        if (/thunderbird|evolution|geary|kmail|mailspring|betterbird|\bmail\b/.test(app)) return Enums.AlertKind.Mail
        // A browser says "Download complete" / "Download abgeschlossen"; so do some download managers.
        if (/download|herunterlad|heruntergeladen/.test(text) || /download|transmission|qbittorrent|aria2/.test(app)) return Enums.AlertKind.Download
        return Enums.AlertKind.Notification
    }

    // The fields of IslandState.pushRichAlert's data for a notification (app, icon, picture, body, actions).
    function notificationData(n: var): var {
        if (!n || !Number.isInteger(n.id)) throw new Error("invariant: IslandHost.notificationData: a notification needs an integer id")
        const kind = classifyNotification(n)
        const app = n.appName || (n.desktopEntry || "")
        // The sender's icon name, a path, or the one of the desktop entry; bodies may carry simple markup.
        let icon = ""
        if (n.icon) icon = n.icon.startsWith("/") ? "file://" + n.icon : Quickshell.iconPath(n.icon, true) || ""
        // A theme icon sent as the picture is the app symbol, not a picture.
        const themeImage = n.image && n.image.startsWith("image://icon/")
        if (icon === "" && themeImage) icon = n.image
        if (icon === "") icon = mediaState.iconFor(n.desktopEntry || app.toLowerCase())
        const body = (n.body || "").replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").trim()
        const actions = (n.actions || []).filter(a => a.label && a.id !== "default").slice(0, 2)
        const long = body.length > 0
        return {
            text: n.summary || app,
            body: body,
            appName: app,
            appIcon: icon,
            image: n.image && !themeImage ? n.image : "",
            actions: actions,
            notificationId: n.id,
            // A finished download shows a full bar.
            progress: kind === Enums.AlertKind.Download ? 1 : -1,
            holdMs: Math.max(islandState.alertHoldMs, actions.length > 0 ? 8000 : long ? 5500 : 0)
        }
    }

    // The fields of IslandState.pushRichAlert's data for the track that plays (cover, artist and album, app, progress).
    function mediaData(m: var, reason: string): var {
        if (!m || !m.available) throw new Error("invariant: IslandHost.mediaData: no media player")
        if (reason !== "track" && reason !== "state" && reason !== "cover") throw new Error("invariant: IslandHost.mediaData: unknown reason " + reason)
        return {
            text: m.title,
            detail: m.artist,
            album: m.album,
            appName: m.playerName || "Music",
            appIcon: m.appIcon,
            image: m.artUrl,
            playing: m.playing,
            holdMs: Math.max(islandState.alertHoldMs, 5000)
        }
    }

    // Push an alert for the notification at the top of Notifications.popupItems when it is a new one.
    function announceNotification(): void {
        const list = Notifications.popupItems
        if (list.length === 0 || list[0].id === lastPopupId) return
        lastPopupId = list[0].id
        const n = list[0]
        islandState.pushRichAlert("n" + n.id, classifyNotification(n), n.severity === Enums.Severity.Critical ? n.severity : classifyNotification(n) === Enums.AlertKind.Download ? Enums.Severity.Ok : Enums.Severity.Neutral, Enums.TileId.Notifications, notificationData(n))
    }

    // Push an alert when playback starts or stops ("Playing" / "Paused" with the title).
    function announcePlayback(): void {
        const m = mediaState
        if (!m || !m.available || m.title === "") return
        islandState.pushRichAlert("track", Enums.AlertKind.Media, Enums.Severity.Neutral, Enums.TileId.Media, mediaData(m, "state"))
    }

    // The track alert that is shown (or waits) gets the current cover and app icon.
    function refreshTrackAlert(): void {
        if (!islandState) throw new Error("invariant: IslandHost.refreshTrackAlert: no island state")
        const a = islandState.alert
        const m = mediaState
        if (!a || a.id !== "track" || !m || !m.available) return
        islandState.pushRichAlert("track", Enums.AlertKind.Media, Enums.Severity.Neutral, Enums.TileId.Media, mediaData(m, "cover"))
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
        function onFinished(label: string) { host.islandState.pushRichAlert("timer", Enums.AlertKind.Timer, Enums.Severity.Warn, Enums.TileId.Timer, { text: label ? label : "Timer", detail: "Time is up", appName: "Timer" }) }
    }
    Connections {
        target: host.batteryState
        function onPercentChanged() {
            const b = host.batteryState
            if (b.present && b.discharging && b.percent <= b.criticalBelowPercent) {
                if (!host.batteryAnnounced) {
                    host.batteryAnnounced = true
                    host.islandState.pushRichAlert("battery", Enums.AlertKind.Battery, Enums.Severity.Critical, Enums.TileId.PowerProfile, { text: "Battery " + Math.round(b.percent) + "%", detail: "Plug in soon", appName: "Power", progress: b.percent / 100 })
                }
            } else if (!b.discharging || b.percent > b.criticalBelowPercent + 5) {
                host.batteryAnnounced = false
            }
        }
    }
    Connections {
        target: host.mediaState
        function onPlayingChanged() { host.announcePlayback() }
        function onTitleChanged() {
            const m = host.mediaState
            const key = m.title + "|" + m.artist
            if (m.title === "" || key === host.lastTrackKey) return
            host.lastTrackKey = key
            if (m.playing) host.islandState.pushRichAlert("track", Enums.AlertKind.Media, Enums.Severity.Neutral, Enums.TileId.Media, host.mediaData(m, "track"))
        }
    }

    // The cover and the app icon often arrive a moment after the title: the card that shows the track takes them over.
    Connections {
        target: host.mediaState
        function onArtUrlChanged() { host.refreshTrackAlert() }
        function onAppIconChanged() { host.refreshTrackAlert() }
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
            powerProfileState: host.powerProfileState
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
