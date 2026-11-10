//@ pragma UseQApplication
// aptus v2 shell root (07-architecture §2–§4): `qs -p <repo>/shell`.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.services
import qs.registry
import qs.windows
import qs.surfaces.lock
import qs.surfaces.settings

ShellRoot {
    id: root

    // Probe P-23: file watching only in dev runs (`aptus dev on`).
    settings.watchFiles: Paths.dev

    // 0 → 1 during the session intro (M-01), 1 on restarts; every MonitorShell's introProgress.
    property real introProgress: 1
    // The start check (locked marker, intro flag; 07 §3 steps 4–5) has answered.
    property bool _startChecked: false
    // Config and Tokens have resolved and the start check answered: the MonitorShells appear
    // (07 §3 step 2, no unstyled first frame).
    readonly property bool _ready: _startChecked && Config.loaded && Tokens.raw.palettes !== undefined

    // Bindings into core: core never imports services (07 §2).
    Binding { target: Tokens; property: "wallpaperHue"; value: Wallpaper.hue }
    Binding { target: Tokens; property: "wallpaperLightness"; value: Wallpaper.lightness }
    Binding { target: Tokens; property: "wallpaperChroma"; value: Wallpaper.chroma }
    Binding { target: Tokens; property: "ownRenderBusy"; value: Theme.busy }
    Binding { target: SurfaceManager; property: "activeMonitor"; value: Hypr.focusedMonitor }
    Binding { target: SurfaceManager; property: "currentWindow"; value: Hypr.activeWindow ? Hypr.activeWindow.address : "" }
    Binding { target: SurfaceManager; property: "locked"; value: Session.locked }
    Binding { target: SurfaceManager; property: "fullscreenMonitors"; value: Hypr.fullscreenMonitors }

    Connections {
        target: Hypr
        function onMonitorsChanged(): void { SurfaceManager.syncMonitors(Hypr.monitors.map(m => m.name)); }
    }

    Variants {
        model: root._ready ? Quickshell.screens : []
        MonitorShell {
            notchModes: NotchModes.components
            activities: Activities.activities
            cards: Activities.cards
            introProgress: root.introProgress
        }
    }

    // qmllint disable required
    Shortcuts {}
    // qmllint enable required
    Ipc {}
    Lock {}
    LazyLoader {
        active: SurfaceManager.settingsOpen
        SettingsWindow { args: SurfaceManager.settingsArgs }
    }

    NumberAnimation on introProgress {
        id: intro
        running: false
        from: 0
        to: 1
        duration: Motion.ms("intro", false)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.enter
    }

    // Steps 4–5 of 07 §3: the locked marker means a crash while locked (lock at once, no intro);
    // a missing intro flag for this Hyprland signature means the first start of the session.
    // Each FileView answers once at the start: loaded = the file exists, loadFailed = it does not.
    FileView {
        path: Paths.lockedMarker
        blockLoading: true
        printErrors: false
        onLoaded: root._startAnswer("locked", true)
        onLoadFailed: root._startAnswer("locked", false)
    }
    FileView {
        id: introFlag
        path: Paths.introFlag
        blockLoading: true
        printErrors: false
        onLoaded: root._startAnswer("played", true)
        onLoadFailed: root._startAnswer("played", false)
    }
    // The answers so far, { locked: bool, played: bool }; acted on once both are in and the
    // services have started (Component.onCompleted).
    property var _start: ({})
    property bool _completed: false
    function _startAnswer(what: string, exists: bool): void {
        if (!(what in _start)) _start[what] = exists;
        _startDecide();
    }
    function _startDecide(): void {
        if (_startChecked || !_completed || !("locked" in _start) || !("played" in _start)) return;
        if (_start.locked) {
            Log.info("shell", "locked marker found: locking at once");
            Session.lock();
        } else if (!_start.played) {
            introProgress = 0;
            introFlag.setText("played\n");          // FileView creates the folder itself
            Qt.callLater(() => intro.start());
        }
        _startChecked = true;
    }

    Component.onCompleted: {
        // Step 3: these services start eagerly (singletons are lazy); Notifications must own the
        // bus name before apps send.
        for (const s of [Hypr, Notifications, Idle, Session, Wallpaper]) Log.debug("shell", "started " + s);
        SurfaceManager.syncMonitors(Hypr.monitors.map(m => m.name));
        _completed = true;
        _startDecide();
        Log.info("shell", "aptus shell started (" + Paths.shellDir + ")");
    }
}
